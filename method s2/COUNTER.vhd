library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity COUNTER is
 generic (COUNTER_WIDTH: integer);
    port (clk, rst: in STD_LOGIC;
	       counter_en: in STD_LOGIC;
			 full, zero: out STD_LOGIC;
			 counter_out: out STD_LOGIC_VECTOR (COUNTER_WIDTH-1 downto 0));
end COUNTER;

architecture COUNTER_arch of COUNTER is

signal counter: STD_LOGIC_VECTOR (COUNTER_WIDTH downto 0):=(others => '0');
signal counter_full: STD_LOGIC;

begin

counter_out <= counter(COUNTER_WIDTH-1 downto 0);
counter_full <= counter(COUNTER_WIDTH);
full <= counter_full;
zero <= '1' when counter = conv_std_logic_vector(0,COUNTER_WIDTH+1) else '0'; 

process (rst, clk)
begin

if rst = '1' then
  counter <= (others => '0');
elsif clk'event and clk = '1' then
  if counter_en = '1' and counter_full = '0' then
    counter <= counter + 1;
  end if;
end if;

end process;

end COUNTER_arch;