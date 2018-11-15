library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity FF is
  port (clk, rst: in STD_LOGIC;
	     FF_en: in STD_LOGIC;
	     FF_in: in STD_LOGIC;
		  FF_out: out STD_LOGIC);
end FF;

architecture FF_arch of FF is

signal FF: STD_LOGIC;

begin

process (rst, clk)
begin

if rst = '1' then
  FF <= '0';
elsif clk'event and clk = '1' then
  if FF_en = '1' then
    FF <= FF_in;
  end if;
end if;

end process;

FF_out <= FF;

end FF_arch;