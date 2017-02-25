-------------------------------------------------------------------------------
-- Title      : Structural Description of the SYsntesizer
-- Project    : TIE-50206
-------------------------------------------------------------------------------
-- File       : synthesizer.vhd
-- Author     : 2 - Daniel Koslopp / Talita Tobias Carneiro
-- Company    : 
-- Created    : 2017-01-22
-- Last update: 2017-01-22
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Top level structural description of the syntehsizer.
-------------------------------------------------------------------------------
-- Copyright (c) 2017 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2017-01-22  1.0      tobiasca        Created
-------------------------------------------------------------------------------

-- Include default libraries
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity synthesizer is

  generic (
    clk_freq_g    : integer := 18432000;  -- reference clk frequency
    sample_rate_g : integer := 48000;     -- sample frequency
    data_width_g  : integer := 16;        -- data width
    n_keys_g      : integer := 4);        -- number of keys

  port (
    clk           : in  std_logic;      -- clk signal
    rst_n         : in  std_logic;      -- reset signal
    -- buttons input
    keys_in       :     std_logic_vector((n_keys_g - 1) downto 0);
    aud_bclk_out  : out std_logic;      -- Bit clock signal
    aud_data_out  : out std_logic;      -- data output
    aud_lrclk_out : out std_logic);     -- left right clock signal

end entity synthesizer;


architecture structural of synthesizer is


  -- constants declaration
  constant wg_step_c : integer := 1; -- base step for wavegen 

  -- signal declaration
  -- audio input from wave generators
  signal wave_wg_mpadder :
    std_logic_vector((data_width_g*n_keys_g-1) downto 0);
  -- data input to audio controller from multi_port_adder
  signal data_mpadder_actrl : std_logic_vector((data_width_g-1) downto 0);

  -- component declaration
  component wave_gen is                 -- wave gen component declaration
    generic (
      width_g : integer;
      step_g  : integer);
    port (
      clk           : in  std_logic;
      rst_n         : in  std_logic;
      sync_clear_in : in  std_logic;
      value_out     : out std_logic_vector((width_g-1) downto 0));
  end component wave_gen;

  component multi_port_adder is  -- multiport adder component declaration
    generic (
      operand_width_g   : integer;
      num_of_operands_g : integer);
    port (
      clk         : in  std_logic;
      rst_n       : in  std_logic;
      operands_in : in  std_logic_vector((operand_width_g*num_of_operands_g)-1
                                        downto 0);
      sum_out     : out std_logic_vector(operand_width_g-1 downto 0));
  end component multi_port_adder;

  component audio_ctrl is  -- audio controller component declaration
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


begin  -- architecture structural


  -- Component instatiation
  i_wave_gen_1 : wave_gen
    generic map (
      width_g => data_width_g,
      step_g  => wg_step_c)
    port map (
      clk           => clk,
      rst_n         => rst_n,
      sync_clear_in => keys_in(0),
      value_out     => wave_wg_mpadder((data_width_g-1) downto 0));

  i_wave_gen_2 : wave_gen
    generic map (
      width_g => data_width_g,
      step_g  => wg_step_c*2)
    port map (
      clk           => clk,
      rst_n         => rst_n,
      sync_clear_in => keys_in(1),
      value_out     => wave_wg_mpadder((data_width_g*2-1) downto data_width_g));

  i_wave_gen_3 : wave_gen
    generic map (
      width_g => data_width_g,
      step_g  => wg_step_c*4)
    port map (
      clk           => clk,
      rst_n         => rst_n,
      sync_clear_in => keys_in(2),
      value_out     => wave_wg_mpadder((data_width_g*3-1)
                                   downto data_width_g*2));

  i_wave_gen_4 : wave_gen
    generic map (
      width_g => data_width_g,
      step_g  => wg_step_c*8)
    port map (
      clk           => clk,
      rst_n         => rst_n,
      sync_clear_in => keys_in(3),
      value_out     => wave_wg_mpadder((data_width_g*4-1)
                                   downto data_width_g*3));

  i_mpadder_1 : multi_port_adder
    generic map (
      operand_width_g   => data_width_g,
      num_of_operands_g => n_keys_g)
    port map (
      clk         => clk,
      rst_n       => rst_n,
      operands_in => wave_wg_mpadder((data_width_g*n_keys_g-1) downto 0),
      sum_out     => data_mpadder_actrl((data_width_g-1) downto 0));

  i_actrl_1 : audio_ctrl
    generic map (
      ref_clk_freq_g => clk_freq_g,
      sample_rate_g  => sample_rate_g,
      data_width_g   => data_width_g)
    port map (
      clk           => clk,
      rst_n         => rst_n,
      left_data_in  => data_mpadder_actrl((data_width_g-1) downto 0),
      right_data_in => data_mpadder_actrl((data_width_g-1) downto 0),
      aud_bclk_out  => aud_bclk_out,
      aud_data_out  => aud_data_out,
      aud_lrclk_out => aud_lrclk_out);


end architecture structural;
