-------------------------------------------------------------------------------
-- Title      : I2C-Bus controller and configuration of audio codec
-- Project    : TIE-50206 Logic and Syhnthesis
-------------------------------------------------------------------------------
-- File       : i2c_config.vhd
-- Author     : 02 - Daniel Koslopp/Talita Tobias Carneiro
-- Company    : 
-- Created    : 2017-01-31
-- Last update: 2017-02-09
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: implementation of an I2C-bus controller to configure Wolfson
-- audio codec before the synthesizer begins to feed data to it.
-------------------------------------------------------------------------------
-- Copyright (c) 2017 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2017-01-31  1.0      Talita  Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity i2c_config is

  generic (
    ref_clk_freq_g : integer := 50000000;  -- frequency of clk signal
    i2c_freq_g     : integer := 20000;  -- i2c bus frequency (sclk_out)
    n_params_g     : integer := 10;     -- number of configuration parameters
    dbg_width_g    : integer := 24);    -- debugger width
  port (
    clk              : in    std_logic;    -- clk
    rst_n            : in    std_logic;    -- reset
    sdat_inout       : inout std_logic;    -- data to be transmitted
    sclk_out         : out   std_logic;    -- i2c clock signal
    -- status parameters
    param_status_out : out   std_logic_vector((n_params_g-1) downto 0);
    finished_out     : out   std_logic;    -- finished flag
    -- data to be checked by tb
    dbg_rom_data_out : out   std_logic_vector((dbg_width_g-1) downto 0);
    dbg_rom_we_out   : out   std_logic);   -- enable flag to check data sent

end entity i2c_config;

architecture fsm of i2c_config is

  -- constant definitions
  -- sclk on high, 625
  constant sclk_high_c      : integer := ref_clk_freq_g/(i2c_freq_g*4);
  -- sclk on low, 1875
  constant sclk_low_c       : integer := (ref_clk_freq_g*3)/(i2c_freq_g*4);
  -- sclk on falling edge, 1250
  constant sclk_falling_c   : integer := ref_clk_freq_g/(i2c_freq_g*2);
  -- sclk on rising edge, 2500 -> 0
  constant sclk_rising_c    : integer := ref_clk_freq_g/i2c_freq_g;
  -- number of bytes to be transmitted for each parameter
  constant n_bytes_c        : integer := 3;
  -- number of bits in each byte to be transmitted
  constant n_bits_c         : integer := 8;
  -- codec address value and write-bit (LSB)
  constant codec_addr_write : std_logic_vector(n_bits_c-1 downto 0) :=
    "00110100";

  -- type declarations
  -- configuration parameter type
  type data_array is array (0 to n_params_g-1, 0 to n_bytes_c-1) of
    std_logic_vector(n_bits_c-1 downto 0);
  -- state machine states declaration
  type state_type is (start_fsm, wait_tSU_start, start_I2C, wait_low_sclk,
                      update_sdat, check_ack, restart_param_transm,
                      config_param, stop_i2c, finished);

  -- configuration parameters for Wolfson codec
  constant config_param_c : data_array :=
    ((codec_addr_write, "00000000", "00011010"),  -- left line in
     (codec_addr_write, "00000010", "00011010"),  -- right line in
     (codec_addr_write, "00000100", "01111011"),  -- left headphone out
     (codec_addr_write, "00000110", "01111011"),  -- right headphone out
     (codec_addr_write, "00001000", "11111000"),  -- analogue audio path control
     (codec_addr_write, "00001010", "00000110"),  -- digital audio path control
     (codec_addr_write, "00001100", "00000000"),  -- power down control
     (codec_addr_write, "00001110", "00000001"),  -- dig. audio interface format
     (codec_addr_write, "00010000", "00000010"),  -- sampling control
     (codec_addr_write, "00010010", "00000001"));  -- active control

  -- signal declarations
  -- counter used to generate sclk and to sync to sdat.
  signal cnt_clk_r          : integer range 0 to ref_clk_freq_g/i2c_freq_g+1;
  signal sclk_rst_n_r       : std_logic;   -- enable generation of sclk_out
  -- counts the number of bits being transmitted
  signal cnt_bit_i2c_r      : integer range 0 to n_bits_c;
  -- sdat_inout value assigned from fsm
  signal sdat_fsm_r         : std_logic;
  -- register to read value of sdat_inout from codec (slave)
  signal sdat_read_r        : std_logic;
  -- byte being transmitted
  signal cnt_byte_i2c_r     : integer range 0 to n_bytes_c;
  -- config param being transmitted
  signal cnt_config_param_r : integer range 0 to n_params_g;
  signal present_state_r    : state_type;  -- present state of fsm


begin  -- architecture fsm

  -- purpose: generates the sclk_out when fsm enables it.
  -- The signal is synched with the cnt_clk_r, thus sdat_inout is assigned
  -- in the correct moment accordingly with I2C specs.
  -- type   : sequential
  -- inputs : clk, rst_n, sclk_rst_n_r, 
  -- outputs: sclk_out, cnt_clk_r
  gen_sclk : process (clk, rst_n) is
  begin  -- process gen_sclk
    if rst_n = '0' then                 -- asynchronous reset (active low)
      cnt_clk_r <= 0;
      sclk_out  <= '1';

    elsif clk'event and clk = '1' then  -- rising clock edge
      -- synchronous reset from fsm
      if sclk_rst_n_r = '0' then
        cnt_clk_r <= 0;
        sclk_out  <= '1';
      else
        -- increase cnt_clk_r and check the number to toggle
        cnt_clk_r <= cnt_clk_r + 1;
        if cnt_clk_r = sclk_falling_c then
          sclk_out <= '0';
        elsif cnt_clk_r = sclk_rising_c then
          sclk_out  <= '1';
          cnt_clk_r <= 0;
        end if;
      end if;

    end if;
  end process gen_sclk;


  -- purpose: controls the sdat_inout tri-state buffer. 
  -- type   : sequential
  -- inputs : clk, rst_n, cnt_bit_i2c_r, sdat_inout
  -- outputs: sdat_inout
  sdat_ctrl : process (clk, rst_n) is
  begin  -- process sdat_ctrl
    if rst_n = '0' then                 -- asynchronous reset (active low)
      sdat_inout <= '1';
    elsif clk'event and clk = '1' then  -- rising clock edge
      -- when each byte is transmitted assign Z to sdat_inout to check answer
      -- on fsm from codec
      if present_state_r = check_ack then
        sdat_inout <= 'Z';
      else
        sdat_inout <= sdat_fsm_r;       -- sdat_inout is assigned by fsm
      end if;
    end if;
  end process sdat_ctrl;


  -- purpose: finite state machine implemented according with supplementar documentation
  -- type   : sequential
  -- inputs : clk, rst_n, cnt_clk_r, cnt_bit_i2c_r, sdat_inout
  -- outputs: sdat_fsm_r, sclk_rst_n_r, param_status_out, finished_out
  -- cnt_bit_i2c_r
  fsm : process (clk, rst_n) is


  begin  -- process fsm
    if rst_n = '0' then                 -- asynchronous reset (active low)
      sdat_fsm_r         <= '1';
      sclk_rst_n_r       <= '0';
      param_status_out   <= (others => '0');
      finished_out       <= '0';
      cnt_byte_i2c_r     <= 0;
      cnt_bit_i2c_r      <= 0;
      cnt_config_param_r <= 0;
      present_state_r    <= start_fsm;
      dbg_rom_we_out     <= '0';
      dbg_rom_data_out   <= (others => '0');

    elsif clk'event and clk = '1' then  -- rising clock edge

      case present_state_r is

        when start_fsm =>

          -- output assignments
          sdat_fsm_r         <= '1';
          sclk_rst_n_r       <= '0';
          cnt_bit_i2c_r      <= 0;
          cnt_byte_i2c_r     <= 0;
          cnt_config_param_r <= 0;

          -- next state assignments
          present_state_r <= wait_tSU_start;

        when wait_tSU_start =>
          -- output assignments
          sclk_rst_n_r  <= '1';
          sdat_fsm_r    <= '1';
          cnt_bit_i2c_r <= 0;

          -- next state assignemnts
          if cnt_clk_r /= sclk_high_c then
            present_state_r <= wait_tSU_start;
          else
            present_state_r <= start_I2C;
          end if;

        when start_I2C =>
          --output assignments
          sdat_fsm_r <= '0';

          -- next state assignments
          if cnt_clk_r /= sclk_falling_c then
            present_state_r <= start_I2C;
          else
            present_state_r <= wait_low_sclk;
          end if;

        when wait_low_sclk =>
          -- output assignments

          -- next state assignemnts
          if cnt_bit_i2c_r = n_bits_c and cnt_clk_r = sclk_low_c then
            present_state_r <= check_ack;
          elsif cnt_clk_r /= sclk_low_c then
            present_state_r <= wait_low_sclk;
          else
            present_state_r <= update_sdat;
          end if;

        when update_sdat =>
          -- output assignments
          sdat_fsm_r <= config_param_c(cnt_config_param_r, cnt_byte_i2c_r)
                        ((n_bits_c-1) - cnt_bit_i2c_r);
          cnt_bit_i2c_r <= cnt_bit_i2c_r + 1;

          -- next state assignments
          present_state_r <= wait_low_sclk;

        when check_ack =>
          -- output assignments
          if cnt_clk_r = sclk_high_c then
            sdat_read_r <= sdat_inout;
          end if;

          -- next state assignments
          if cnt_clk_r = sclk_low_c then
            cnt_byte_i2c_r <= cnt_byte_i2c_r + 1;
            if sdat_read_r = '1' then
              present_state_r <= restart_param_transm;
            elsif cnt_byte_i2c_r /= n_bytes_c-1 then
              present_state_r <= update_sdat;
              cnt_bit_i2c_r   <= 0;
            else
              present_state_r <= config_param;
            end if;
          else
            present_state_r <= check_ack;
          end if;

        when restart_param_transm =>
          -- output assignments
          cnt_byte_i2c_r <= 0;
          sdat_fsm_r     <= '0';
          sdat_read_r    <= '0';
          -- next state assignments
          if cnt_clk_r = sclk_rising_c then
            present_state_r <= stop_i2c;
          end if;

        when config_param =>
          -- output assignments
          cnt_byte_i2c_r                       <= 0;
          param_status_out(cnt_config_param_r) <= '1';
          sdat_fsm_r                           <= '0';
          -- signal tb to check data received
          dbg_rom_we_out                       <= '1';
          dbg_rom_data_out                     <= config_param_c(cnt_config_param_r, 0)
                              & config_param_c(cnt_config_param_r, 1)
                              & config_param_c(cnt_config_param_r, 2);
          -- next state assignments
          if cnt_clk_r = sclk_rising_c then
            present_state_r    <= stop_i2c;
            cnt_config_param_r <= cnt_config_param_r + 1;
          end if;

        when stop_i2c =>
          -- output assignments
          dbg_rom_we_out <= '0';
          -- next state assignments
          if cnt_clk_r = sclk_high_c then
            sdat_fsm_r <= '1';
            if cnt_config_param_r /= 10 then
              present_state_r <= wait_tSU_start;
            else
              present_state_r <= finished;
            end if;
          end if;

        when finished =>
          -- output assignments
          sdat_fsm_r   <= '1';
          sclk_rst_n_r <= '0';
          finished_out <= '1';

        when others =>
          present_state_r <= start_fsm;

      end case;
    end if;
  end process fsm;

end architecture fsm;
