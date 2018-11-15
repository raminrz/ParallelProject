library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity RAM is
 generic (RAM_DATA_SIZE: integer:=16;
          RAM_ADDR_SIZE: integer:=10);
    port (clk: in STD_LOGIC;
	       en_A, en_B, W_en_A: in STD_LOGIC;
			 input: in STD_LOGIC_VECTOR (RAM_DATA_SIZE-1 downto 0);
			 addr_A, addr_B: in STD_LOGIC_VECTOR (RAM_ADDR_SIZE-1 downto 0);
			 out_A, out_B: out STD_LOGIC_VECTOR (RAM_DATA_SIZE-1 downto 0));
end RAM;

architecture RAM_arch of RAM is

subtype RAM_WORD is STD_LOGIC_VECTOR (RAM_DATA_SIZE-1 downto 0);
type RAM_TYPE is array (0 to 2**RAM_ADDR_SIZE-1) of RAM_WORD;
signal RAM: RAM_TYPE;

begin

process (clk)
begin

  if clk'event and clk = '1' then
    if en_B = '1' then
      out_B <= RAM(conv_integer(addr_B));
    end if;
  end if;
  
end process;

process (clk)
begin

  if clk'event and clk = '1' then
    if en_A = '1' then
      if W_en_A = '1' then
        RAM(conv_integer(addr_A)) <= input;
	   end if;
	   out_A <= RAM(conv_integer(addr_A));
--      out_B <= RAM(conv_integer(addr_B));
    end if;
  end if;
  
end process;

end RAM_arch;