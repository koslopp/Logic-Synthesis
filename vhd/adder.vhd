----------------------------------------------------------------------------
-- Project : TIE-50206 Logic Synthesis
-- Author : 2 - Daniel Koslopp / Talita Tobias Carneiro
-- Date : 15-11-2016
-- File : adder.vhd 
-- Design : Course exercise 3
----------------------------------------------------------------------------
-- Description : Sum of two n width bit values (s = a + b)
----------------------------------------------------------------------------

-- Include default libraries
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity adder is
  generic(
    operand_width_g : integer           -- bus width to be selected
    );
  port(
    clk     : in  std_logic;
    rst_n   : in  std_logic;
    a_in    : in  std_logic_vector(operand_width_g-1 downto 0);
    b_in    : in  std_logic_vector(operand_width_g-1 downto 0);
    sum_out : out std_logic_vector(operand_width_g downto 0));
end adder;

----------------------------------------------------------------------------

architecture rtl of adder is

  signal result : signed(operand_width_g downto 0);

begin

  sum : process(clk, rst_n)
  begin
    if (rst_n = '0') then
      result <= (others => '0');        -- reset register

    elsif (clk = '1' and clk'event) then
      -- resize and convert to add values
      result <= resize(signed(a_in), operand_width_g+1)
                + resize(signed(b_in), operand_width_g+1);
    end if;

  end process;
  -- assign the register to the output
  sum_out <= std_logic_vector(result);

end rtl;
