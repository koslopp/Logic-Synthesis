-------------------------------------------------------------------------------
-- Title      : Test Bench for audio_ctrl
-- Project    : TIE-50206 Logic Synthesis
-------------------------------------------------------------------------------
-- File       : tb_audio_ctrl.vhd
-- Author     : Daniel Koslopp / Talita Tobias Carneiro
-- Company    : 
-- Created    : 2017-01-11
-- Last update: 2017-01-22
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Test Bench for audio controller using wave_gen and codec model
-------------------------------------------------------------------------------
-- Copyright (c) 2017 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2017-01-11  1.0      koslopp Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_audio_ctrl is
end entity tb_audio_ctrl;

architecture testbench of tb_audio_ctrl is

  -- constants declarations
  constant period_c       : time    := 54.25347222 ns;  -- clock period
  constant data_width_c   : integer := 16;              -- data width
  -- clock frequency for audio codec controller
  constant ref_clk_freq_c : integer := 18432000;
  constant sample_rate_c  : integer := 48000;           -- audio sample rate
  -- width of the wave generator data
  constant wave_width_c   : integer := 16;
  constant wave_step_c    : integer := 2;  -- step value for wave generator


  -- signal declarations
  signal clk             : std_logic := '0';  -- clock signal
  signal rst_n           : std_logic := '0';  -- reset signal
  signal wave_sync_clear : std_logic := '1';  -- clear wave generator output
  -- left and right values generate from wave gen. to audio controller
  signal l_data_wg_actrl : std_logic_vector((data_width_c-1) downto 0);
  signal r_data_wg_actrl : std_logic_vector((data_width_c-1) downto 0);
  -- clock bit from audio controller to codec
  signal aud_bit_clk     : std_logic;
  -- bit selector for right and left data from aud. controller to codec
  signal aud_lr_clk      : std_logic;
  signal aud_data        : std_logic;   -- data signal from control. to codec
  -- left and right output of codec model
  signal l_data_codec_tb : std_logic_vector((data_width_c-1) downto 0);
  signal r_data_codec_tb : std_logic_vector((data_width_c-1) downto 0);

  -- component declaration
  component audio_codec_model is        -- simulation model of the codec
    generic (
      data_width_g : integer);
    port (
      rst_n           : in  std_logic;
      aud_data_in     : in  std_logic;
      aud_bclk_in     : in  std_logic;
      aud_lrclk_in    : in  std_logic;
      value_left_out  : out std_logic_vector((data_width_g-1) downto 0);
      value_right_out : out std_logic_vector((data_width_g-1) downto 0));
  end component audio_codec_model;

  component wave_gen is                 -- wave generator
    generic (
      width_g : integer;
      step_g  : integer);
    port (
      clk           : in  std_logic;
      rst_n         : in  std_logic;
      sync_clear_in : in  std_logic;
      value_out     : out std_logic_vector((width_g-1) downto 0));
  end component wave_gen;

  component audio_ctrl is               -- audio controller
    generic (
      ref_clk_freq_g : integer;
      sample_rate_g  : integer;
      data_width_g   : integer);
    port (
      clk           : in  std_logic;
      rst_n         : in  std_logic;
      left_data_in  : in  std_logic_vector((data_width_g-1) downto 0);
      right_data_in : in  std_logic_vector((data_width_g-1) downto 0);
      aud_bclk_out  : out std_logic;
      aud_data_out  : out std_logic;
      aud_lrclk_out : out std_logic);
  end component audio_ctrl;

begin  -- architecture testbench

  clk             <= not clk after period_c/2;  -- generate clock
  rst_n           <= '1'     after 4*period_c;  -- reset during first 4 clk
  wave_sync_clear <= '0'     after 10*period_c;  -- initialize clear

  -- component instatiation for audio_codec_model
  i_acodecm_1 : audio_codec_model
    generic map (
      data_width_g => data_width_c)
    port map (
      rst_n           => rst_n,
      aud_data_in     => aud_data,
      aud_bclk_in     => aud_bit_clk,
      aud_lrclk_in    => aud_lr_clk,
      value_left_out  => l_data_codec_tb,
      value_right_out => r_data_codec_tb);

  -- component instatiation for wave_gen
  i_wg_1 : wave_gen
    generic map (
      width_g => wave_width_c,
      step_g  => wave_step_c)
    port map (
      clk           => clk,
      rst_n         => rst_n,
      sync_clear_in => wave_sync_clear,
      value_out     => l_data_wg_actrl);

  -- component instatiation for wave_gen
  i_wg_2 : wave_gen
    generic map (
      width_g => wave_width_c,
      step_g  => wave_step_c*5)
    port map (
      clk           => clk,
      rst_n         => rst_n,
      sync_clear_in => wave_sync_clear,
      value_out     => r_data_wg_actrl);

  -- component instatiation for audio controller (DUV)
  DUV : audio_ctrl
    generic map (
      ref_clk_freq_g => ref_clk_freq_c,
      sample_rate_g  => sample_rate_c,
      data_width_g   => data_width_c)
    port map (
      clk           => clk,
      rst_n         => rst_n,
      left_data_in  => l_data_wg_actrl,
      right_data_in => r_data_wg_actrl,
      aud_bclk_out  => aud_bit_clk,
      aud_data_out  => aud_data,
      aud_lrclk_out => aud_lr_clk);

end architecture testbench;
