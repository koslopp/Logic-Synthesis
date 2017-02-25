-------------------------------------------------------------------------------
-- Title      : Test bench for I2C-Controller
-- Project    : TIE-50206 Logic and Synthesis
-------------------------------------------------------------------------------
-- File       : tb_i2c_config.vhd
-- Author     : 02 - Daniel Koslopp/Talita Tobias Carneiro
-- Company    : 
-- Created    : 2017-02-05
-- Last update: 2017-02-09
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Teste bench for I2C-nController
-------------------------------------------------------------------------------
-- Copyright (c) 2017 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2017-02-05  1.0      Talita  Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

-------------------------------------------------------------------------------
-- Empty entity
-------------------------------------------------------------------------------

entity tb_i2c_config is
end tb_i2c_config;

-------------------------------------------------------------------------------
-- Architecture
-------------------------------------------------------------------------------
architecture testbench of tb_i2c_config is

  -- Number of parameters to expect
  constant n_params_c     : integer := 10;
  constant i2c_freq_c     : integer := 20000;
  constant ref_freq_c     : integer := 50000000;
  constant clock_period_c : time    := 20 ns;

  -- Every transmission consists several bytes and every byte contains given
  -- amount of bits. 
  constant n_bytes_c       : integer                      := 3;
  constant bit_count_max_c : integer                      := 8;
  constant dbg_width_c     : integer                      := 24;
  constant n_bytes_nack_c  : integer                      := 10;
  constant codec_address   : std_logic_vector(7 downto 0) := "00110100";

  -- Signals fed to the DUV
  signal clk   : std_logic := '0';  -- Remember that default values supported
  signal rst_n : std_logic := '0';      -- only in synthesis

  -- The DUV prototype
  component i2c_config is
    generic (
      ref_clk_freq_g : integer;
      i2c_freq_g     : integer;
      n_params_g     : integer;
      dbg_width_g    : integer);
    port (
      clk              : in    std_logic;
      rst_n            : in    std_logic;
      sdat_inout       : inout std_logic;
      sclk_out         : out   std_logic;
      param_status_out : out   std_logic_vector((n_params_g-1) downto 0);
      finished_out     : out   std_logic;
      dbg_rom_data_out : out   std_logic_vector((dbg_width_g-1) downto 0);
      dbg_rom_we_out   : out   std_logic);
  end component i2c_config;

  -- Signals coming from the DUV
  signal sdat         : std_logic := 'Z';
  signal sclk         : std_logic;
  signal param_status : std_logic_vector(n_params_c-1 downto 0);
  signal finished     : std_logic;
  signal dbg_rom_data : std_logic_vector((dbg_width_c-1) downto 0);
  signal dbg_rom_we   : std_logic;

  -- To hold the value that will be driven to sdat when sclk is high.
  signal sdat_r : std_logic;

  -- Counters for receiving bits and bytes
  signal bit_counter_r       : integer range 0 to bit_count_max_c-1;
  signal byte_counter_r      : integer range 0 to n_bytes_c-1;
  signal byte_counter_nack_r : integer range 0 to n_bytes_nack_c-1;

  -- States for the FSM
  type states is (wait_start, read_byte, send_ack, wait_stop);
  signal curr_state_r : states;

  -- Previous values of the I2C signals for edge detection
  signal sdat_old_r : std_logic;
  signal sclk_old_r : std_logic;

  -- Config. data for comparison with dbg_rom_data
  signal cfg_data_received_r : std_logic_vector((dbg_width_c-1) downto 0);

begin  -- testbench

  clk   <= not clk after clock_period_c/2;
  rst_n <= '1'     after clock_period_c*4;

  -- Assign sdat_r when sclk is active, otherwise 'Z'.
  -- Note that sdat_r is usually 'Z'
  with sclk select
    sdat <=
    sdat_r when '1',
    'Z'    when others;


  -- Component instantiation
  i2c_config_1 : i2c_config
    generic map (
      ref_clk_freq_g => ref_freq_c,
      i2c_freq_g     => i2c_freq_c,
      n_params_g     => n_params_c,
      dbg_width_g    => dbg_width_c)
    port map (
      clk              => clk,
      rst_n            => rst_n,
      sdat_inout       => sdat,
      sclk_out         => sclk,
      param_status_out => param_status,
      finished_out     => finished,
      dbg_rom_data_out => dbg_rom_data,
      dbg_rom_we_out   => dbg_rom_we);

  -----------------------------------------------------------------------------
  -- The main process that controls the behavior of the test bench
  fsm_proc : process (clk, rst_n)
  begin  -- process fsm_proc
    if rst_n = '0' then                 -- asynchronous reset (active low)

      curr_state_r <= wait_start;

      sdat_old_r <= '0';
      sclk_old_r <= '0';

      byte_counter_r <= 0;
      bit_counter_r  <= 0;

      sdat_r <= 'Z';

      cfg_data_received_r <= (others => '0');
      byte_counter_nack_r <= 0;

    elsif clk'event and clk = '1' then  -- rising clock edge

      -- The previous values are required for the edge detection
      sclk_old_r <= sclk;
      sdat_old_r <= sdat;


      -- Falling edge detection for acknowledge control
      -- Must be done on the falling edge in order to be stable during
      -- the high period of sclk
      if sclk = '0' and sclk_old_r = '1' then

        -- If we are supposed to send ack
        if curr_state_r = send_ack then
          -- Send ack (low = ACK, high = NACK)
          if byte_counter_nack_r = n_bytes_nack_c-1 then
            sdat_r              <= '1';
            byte_counter_nack_r <= 0;
          else

            sdat_r <= '0';

          end if;

        else

          -- Otherwise, sdat is in high impedance state.
          sdat_r <= 'Z';

        end if;

      end if;


      -------------------------------------------------------------------------
      -- FSM
      case curr_state_r is

        -----------------------------------------------------------------------
        -- Wait for the start condition
        when wait_start =>

          -- Stop condition detection: sdat rises while sclk stays high
          if sclk = '1' and sclk_old_r = '1' and
            sdat_old_r = '0' and sdat = '1' then

            curr_state_r <= wait_start;

          end if;

          -- While clk stays high, the sdat falls
          if sclk = '1' and sclk_old_r = '1' and
            sdat_old_r = '1' and sdat = '0' then

            -- reset signals in the case a unexpected stop condition
            bit_counter_r  <= 0;
            byte_counter_r <= 0;

            curr_state_r <= read_byte;

          end if;

        --------------------------------------------------------------------
        -- Wait for a byte to be read
        when read_byte =>

          -- Stop condition detection: sdat rises while sclk stays high
          if sclk = '1' and sclk_old_r = '1' and
            sdat_old_r = '0' and sdat = '1' then

            curr_state_r <= wait_start;

          end if;

          -- Detect a rising edge
          if sclk = '1' and sclk_old_r = '0' then

            cfg_data_received_r((dbg_width_c-1) -
                                (bit_counter_r + byte_counter_r*8)) <= sdat;

            if bit_counter_r /= bit_count_max_c-1 then

              -- Normally just receive a bit
              bit_counter_r <= bit_counter_r + 1;

            else

              -- When terminal count is reached, let's send the ack
              curr_state_r  <= send_ack;
              bit_counter_r <= 0;

            end if;  -- Bit counter terminal count

          end if;  -- sclk rising clock edge

        --------------------------------------------------------------------
        -- Send acknowledge
        when send_ack =>

          -- Stop condition detection: sdat rises while sclk stays high
          if sclk = '1' and sclk_old_r = '1' and
            sdat_old_r = '0' and sdat = '1' then

            curr_state_r <= wait_start;

          end if;

          -- Detect a rising edge
          if sclk = '1' and sclk_old_r = '0' then

            if byte_counter_r /= n_bytes_c-1 then

              -- Transmission continues
              byte_counter_r      <= byte_counter_r + 1;
              byte_counter_nack_r <= byte_counter_nack_r + 1;
              curr_state_r        <= read_byte;

            else

              -- Transmission is about to stop
              byte_counter_r <= 0;
              curr_state_r   <= wait_stop;

            end if;

          end if;

        ---------------------------------------------------------------------
        -- Wait for the stop condition
        when wait_stop =>
          -- Stop condition detection: sdat rises while sclk stays high
          if sclk = '1' and sclk_old_r = '1' and
            sdat_old_r = '0' and sdat = '1' then

            curr_state_r <= wait_start;

          end if;

      end case;

    end if;
  end process fsm_proc;

  -----------------------------------------------------------------------------
  -- Asserts for verification
  -----------------------------------------------------------------------------

  -- SDAT should never contain X:s.
  assert sdat /= 'X' report "Three state bus in state X" severity failure;

  -- Check address
  assert (codec_address =
          cfg_data_received_r((dbg_width_c-1) downto (dbg_width_c-8))
          and dbg_rom_we = '1') or dbg_rom_we /= '1'
    report "Codec Address is incorrect" severity failure;

  -- Check data received
  assert (dbg_rom_data(dbg_width_c-9 downto 0) =
          cfg_data_received_r((dbg_width_c-9) downto 0)
          and dbg_rom_we = '1') or dbg_rom_we /= '1'
    report "Data received is corrupted" severity failure;

  -- Check param_status
  assert (finished = '1' and param_status = "1111111111") or (finished /= '1')
    report "Parameter configuration not completed" severity failure;

  -- End of simulation, but not during the reset
  assert finished = '0' or rst_n = '0' report
    "Simulation done" severity failure;

end testbench;
