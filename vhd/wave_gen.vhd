----------------------------------------------------------------------------
-- Project : TIE-50206 Logic Synthesis
-- Author : 2 - Daniel Koslopp / Talita Tobias Carneiro
-- Date : 23-11-2016
-- File : wave_gen.vhd 
-- Design : Course exercise 6
----------------------------------------------------------------------------
-- Description : Triangular wave generator  
----------------------------------------------------------------------------

-- Include default libraries
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity wave_gen is
  generic(
    width_g : integer := 4;             -- Width of the wave
    step_g  : integer := 2);  -- Step to increase/decrease rate of the wave
  port(
    clk           : in  std_logic;      -- Clock
    rst_n         : in  std_logic;      -- Reset active in low
    sync_clear_in : in  std_logic;      -- Sync clear (wave output becomes 0)
    value_out     : out std_logic_vector((width_g-1) downto 0));  -- wave
end wave_gen;

----------------------------------------------------------------------------

architecture behavioral of wave_gen is

  type direction is (upward, downward);  -- Direction of the wave
  -- Signal to be increase/decrease
  signal wave_out : std_logic_vector((width_g-1) downto 0);
  signal dir      : direction;           -- Direction signal
  -- Maximum and minimum constants values for the wave
  constant max    : integer := ((2**(width_g-1)-1)/step_g)*step_g;
  constant min    : integer := -max;

begin

----------------------------------------------------------------------------
  -- Wave generator
----------------------------------------------------------------------------
  wave_generator : process(rst_n, clk)
  begin
    if (rst_n = '0') then                 -- Asynchronous reset
      wave_out <= (others => '0');
      dir      <= upward;
    elsif (clk'event and clk = '1') then  -- Rising clock edge
      -- Synchronous reset for the wave
      if (sync_clear_in = '1') then
        dir      <= upward;
        wave_out <= (others => '0');
      -- On the peak, changes direction to downward and decrease
      elsif (wave_out = std_logic_vector(to_signed(max, width_g))) then
        dir      <= downward;
        wave_out <= std_logic_vector(signed(wave_out) - step_g);
      -- On the valley, changes direction to upward and increase
      elsif (wave_out = std_logic_vector(to_signed(min, width_g))) then
        dir      <= upward;
        wave_out <= std_logic_vector(signed(wave_out) + step_g);
      -- Transition from peak to valley and vice-versa
      else
        if (dir = downward) then          -- If downward, decrease wave
          wave_out <= std_logic_vector(signed(wave_out) - step_g);
        else                              -- If upward, increase wave
          wave_out <= std_logic_vector(signed(wave_out) + step_g);
        end if;
      end if;
    end if;
  end process;

  value_out <= wave_out;                -- Assign the signal do output

end behavioral;
