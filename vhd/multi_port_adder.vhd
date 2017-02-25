----------------------------------------------------------------------------
-- Project : TIE-50206 Logic Synthesis
-- Author : 2 - Daniel Koslopp / Talita Tobias Carneiro
-- Date : 18-11-2016
-- File : multi_port_adder.vhd 
-- Design : Course exercise 4
----------------------------------------------------------------------------
-- Description : Sum of x operands with n width bit values 
--                               (s = a1 + a2 + ... + ax)
----------------------------------------------------------------------------

-- Include default libraries
library ieee;
use ieee.std_logic_1164.all;

entity multi_port_adder is
  generic(
    operand_width_g   : integer := 16;  -- operand width to be selected
    num_of_operands_g : integer := 4  -- number of operands to be added         
    );
  port(
    clk         : in  std_logic;
    rst_n       : in  std_logic;
    -- One bus containing all operands 
    operands_in : in  std_logic_vector((operand_width_g*num_of_operands_g)-1
                                      downto 0);
    sum_out     : out std_logic_vector(operand_width_g-1 downto 0));
end multi_port_adder;

----------------------------------------------------------------------------

architecture structural of multi_port_adder is

  -- Adder of two n width bit values (s = a + b) 
  component adder
    generic(
      operand_width_g : integer         -- operand width to be selected
      );
    port(
      clk     : in  std_logic;
      rst_n   : in  std_logic;
      a_in    : in  std_logic_vector(operand_width_g-1 downto 0);
      b_in    : in  std_logic_vector(operand_width_g-1 downto 0);
      sum_out : out std_logic_vector(operand_width_g downto 0));
  end component;

  -- Type array for result of the sub additions 
  type n_sub_additions is array (num_of_operands_g/2-1 downto 0) of std_logic_vector(operand_width_g downto 0);

  signal subtotal : n_sub_additions;    -- Array with the subadditions
  signal total    : std_logic_vector(operand_width_g+1 downto 0);  -- Result

begin

  adder1 : adder                        -- Instatiation of first adder
    generic map(operand_width_g => operand_width_g)
    port map(clk     => clk,
             rst_n   => rst_n,
             -- Take the first n bits of bus input
             a_in    => operands_in(operands_in'left downto
                                 operands_in'left - operand_width_g+1),
             -- Take the second n bits of bus input
             b_in    => operands_in(operands_in'left - operand_width_g
                                 downto operands_in'left - (operand_width_g)*2+1),
             sum_out => subtotal(0));

  adder2 : adder                        -- Instatiation of second adder
    generic map(operand_width_g => operand_width_g)
    port map(clk     => clk,
             rst_n   => rst_n,
             -- Take the thrid n bits of bus input
             a_in    => operands_in(operands_in'left - operand_width_g*2
                                 downto operands_in'left - (operand_width_g)*3+1),
             -- Take the fourth n bits of bus input
             b_in    => operands_in(operands_in'left - operand_width_g*3
                                 downto operands_in'left - (operand_width_g)*4+1),
             sum_out => subtotal(1));

  adder3 : adder                        -- Instatiation of third adder
    generic map(operand_width_g => operand_width_g+1)
    port map(clk     => clk,
             rst_n   => rst_n,
             a_in    => subtotal(0),    -- subtotal of first adder
             b_in    => subtotal(1),    -- subtotal of second adder
             sum_out => total);

  sum_out <= total(total'left-2 downto 0);  -- Final result

  -- Guarantee that the number of operands is equal to four
  assert num_of_operands_g = 4 report "Number of operands is not 4"
    severity failure;

end structural;
