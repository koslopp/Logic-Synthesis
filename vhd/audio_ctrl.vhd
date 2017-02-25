-------------------------------------------------------------------------------
-- Title      : Audio Codec Controller
-- Project    : TIE-50206
-------------------------------------------------------------------------------
-- File       : audio_ctrl.vhd
-- Author     : 2 - Daniel Koslopp / Talita Tobias Carneiro
-- Company    : 
-- Created    : 2017-01-07
-- Last update: 2017-01-22
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Controller of Audio Codec Wolfson WM8731 located in DE2 board
-------------------------------------------------------------------------------
-- Copyright (c) 2017 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2017-01-07  1.0      koslopp Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity audio_ctrl is

  generic (
    ref_clk_freq_g : integer := 18432000;  -- reference freq. for clk (Hz)
    sample_rate_g  : integer := 48000;     -- sample freq. (Hz)
    data_width_g   : integer := 16);       -- data width
  port (
    clk           : in  std_logic;         -- Clock
    rst_n         : in  std_logic;         -- Reset active in low
    -- Left side audio signal
    left_data_in  : in  std_logic_vector((data_width_g-1) downto 0);
    -- Right side audio signal  
    right_data_in : in  std_logic_vector((data_width_g-1) downto 0);
    aud_bclk_out  : out std_logic;         -- Audio bit clock
    aud_data_out  : out std_logic;         -- Data output
    aud_lrclk_out : out std_logic);        -- Left-right clock

end entity audio_ctrl;


architecture rtl of audio_ctrl is

  -- constant declaration
  -- number of cycles for one period of aud_bclk_out (bit clock frequency)
  constant bclk_n_cycle_c : integer := ref_clk_freq_g
                                       /(sample_rate_g*data_width_g*2);
  -- signal declaration
  -- counter to toogle aud_lrclk_out
  signal cnt_lr_clk_r    : integer range 0 to (data_width_g-1)       := 0;
  -- counter to toogle aud_bclk_out
  signal cnt_bclk_clk_r  : integer range 0 to (bclk_n_cycle_c/2 + 1) := 0;
  -- left audio data input  
  signal l_data_r        : std_logic_vector((data_width_g-1) downto 0);
  -- right audio data input register
  signal r_data_r        : std_logic_vector((data_width_g-1) downto 0);
  signal prv_aud_lrclk_r : std_logic;   -- previous aud_lrclk_out value
  signal cur_aud_lrclk_r : std_logic;   -- current value of aud_lrclk_out
  signal prv_aud_bclk_r  : std_logic;   -- previous aud_bclk_out value 
  signal cur_aud_bclk_r  : std_logic;   -- current value of aud_bclk_out

  
begin  -- architecture rtl

  
-- purpose: generates aud_lrclk_out and aud_bclk_out signals
-- type   : sequential
-- inputs : clk, rst_n
-- outputs: aud_bclk_out, aud_lrclk_out
  gen_aud_clk : process (clk, rst_n) is
  begin  -- process gen_aud_clk
    if rst_n = '0' then                 -- asynchronous reset (active low)
      cnt_bclk_clk_r  <= 0;             -- reset cnt_bclk_clk_r
      cnt_lr_clk_r    <= 0;             -- reset cnt_lr_clk_r
      aud_bclk_out    <= '0';           -- reset aud_bclk_out
      aud_lrclk_out   <= '0';           -- reset aud_lrclk_out
      prv_aud_bclk_r  <= '0';           -- reset prv_aud_bclk_r
      prv_aud_lrclk_r <= '0';           -- reset prv_aud_lrclk_r
      cur_aud_bclk_r  <= '0';           -- reset cur_aud_bclk_r
      cur_aud_lrclk_r <= '0';           -- reset cur_aud_lrclk_r

    elsif clk'event and clk = '1' then  -- rising clock edge

      -- assign previous value of aud_lrclk_out
      prv_aud_lrclk_r <= cur_aud_lrclk_r;
      -- assign previous value of aud_bclk_out
      prv_aud_bclk_r  <= cur_aud_bclk_r;
      cnt_bclk_clk_r  <= cnt_bclk_clk_r + 1;  -- increase cnt_bclk_clk_r

      -- Toogle aud_bclk_out when cnt reaches half period and reset cnt.
      -- The signal cur_aud_bclk_r is used to replicate the aud_bclk_out
      -- since it does not allow to read from output.
      if cnt_bclk_clk_r = bclk_n_cycle_c/2 then
        aud_bclk_out   <= not cur_aud_bclk_r;
        cur_aud_bclk_r <= not cur_aud_bclk_r;
        cnt_bclk_clk_r <= 0;
      else
        aud_bclk_out <= cur_aud_bclk_r;
      end if;

      -- check if falling edge of aud_bclk_out and increase cnt_lr_clk_r
      -- if cnt_lr_clk_r did not reach end of data_width_g
      if prv_aud_bclk_r /= cur_aud_bclk_r and cur_aud_bclk_r = '0'
        and cnt_lr_clk_r /= (data_width_g-1) then
        cnt_lr_clk_r <= cnt_lr_clk_r + 1;
      else
        -- if end of data_width_g wait to reset counter when aud_lrclk_out
        -- changes
        if prv_aud_lrclk_r /= cur_aud_lrclk_r then
          cnt_lr_clk_r <= 0;
        else
          cnt_lr_clk_r <= cnt_lr_clk_r;
        end if;
      end if;

      -- toogle aud_lrclk_out when cnt_lr_clk_r reaches data_width_g and
      -- falling edge of aud_bclk_out
      if cnt_lr_clk_r = (data_width_g-1)
        and prv_aud_bclk_r /= cur_aud_bclk_r and cur_aud_bclk_r = '0' then
        aud_lrclk_out   <= not cur_aud_lrclk_r;
        cur_aud_lrclk_r <= not cur_aud_lrclk_r;
      else
        aud_lrclk_out   <= cur_aud_lrclk_r;
        cur_aud_lrclk_r <= cur_aud_lrclk_r;
      end if;
    end if;
  end process gen_aud_clk;

  
  -- purpose: read audio input data bus and store in register when rising
  -- edge on aud_lrclk_out
  -- type   : sequential
  -- inputs : clk, rst_n, left_data_in, right_data_in
  -- outputs: l_data_r, r_data_r
  read_input_data : process (clk, rst_n) is
  begin  -- process read_input_data

    if rst_n = '0' then                 -- asynchronous reset (active low)
      l_data_r <= (others => '0');
      r_data_r <= (others => '0');
    elsif clk'event and clk = '1' then  -- rising clock edge
      -- when rising edge of aud_lrclk_out update l_data_r and r_data_r
      if prv_aud_lrclk_r /= cur_aud_lrclk_r and cur_aud_lrclk_r = '1' then
        l_data_r <= left_data_in;
        r_data_r <= right_data_in;
      else
        l_data_r <= l_data_r;
        r_data_r <= r_data_r;
      end if;
    end if;
  end process read_input_data;

  
  -- purpose: write left and right data from register to aud_data_out
  -- type   : sequential
  -- inputs : clk, rst_n
  -- outputs: aud_data_out
  write_seq_data : process (clk, rst_n) is
  begin  -- process write_seq_data
    if rst_n = '0' then                 -- asynchronous reset (active low)
      aud_data_out <= '0';
    elsif clk'event and clk = '1' then  -- rising clock edge
      if cur_aud_lrclk_r = '1' then
        aud_data_out <= l_data_r((data_width_g - 1) - cnt_lr_clk_r);
      else
        aud_data_out <= r_data_r((data_width_g - 1) - cnt_lr_clk_r);
      end if;
    end if;
  end process write_seq_data;

  
end architecture rtl;
