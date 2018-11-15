library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity RG is
 generic (RG_WIDTH: integer);
    port (clk, rst: in STD_LOGIC;
	       RG_en: in STD_LOGIC;
	       RG_in: in STD_LOGIC_VECTOR (RG_WIDTH-1 downto 0);
			 RG_out: out STD_LOGIC_VECTOR (RG_WIDTH-1 downto 0));
end RG;

architecture RG_arch of RG is

signal RG: STD_LOGIC_VECTOR (RG_WIDTH-1 downto 0);

begin

process (rst, clk)
begin

if rst = '1' then
  RG <= (others => '0');
elsif clk'event and clk = '1' then
  if RG_en = '1' then
    RG <= RG_in;
  end if;
end if;

end process;

RG_out <= RG;

end RG_arch;