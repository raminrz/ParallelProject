library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity BR_STACK is
 generic (STACK_ADDR_SIZE: integer;
          DATA_SIZE: integer);
	 port (clk, rst: in STD_LOGIC;
	       inc, dec: in STD_LOGIC;
	       data_in: in STD_LOGIC_VECTOR (DATA_SIZE-1 downto 0);
			 data_out: out STD_LOGIC_VECTOR (DATA_SIZE-1 downto 0);
			 upper_bound, lower_bound: out STD_LOGIC);
end BR_STACK;

architecture BR_STACK_arch of BR_STACK is

subtype DATA_WORD is STD_LOGIC_VECTOR (DATA_SIZE-1 downto 0);
type STACK_TYPE is array (0 to 2**STACK_ADDR_SIZE-1) of DATA_WORD;
signal stack: STACK_TYPE;
signal stack_counter: STD_LOGIC_VECTOR (STACK_ADDR_SIZE downto 0);
signal stack_counter_full: STD_LOGIC;
signal stack_pointer: STD_LOGIC_VECTOR (STACK_ADDR_SIZE downto 0);
signal stack_pointer_negative: STD_LOGIC;

begin

-- Stack Overflow Output
upper_bound <= stack_counter_full;

-- Stack Underflow Output
lower_bound <= stack_pointer_negative;

-- Stack Counter is Full
stack_counter_full <= stack_counter(STACK_ADDR_SIZE);

-- Stack Pointer is Negative
stack_pointer_negative <= stack_pointer(STACK_ADDR_SIZE);

-- Stack BlockRAM Memory
process(clk)
begin
  
  if clk'event and clk = '0' then 
    if stack_counter_full = '0' and inc = '1' then
		stack(conv_integer(stack_counter(STACK_ADDR_SIZE-1 downto 0))) <= data_in;
    end if;
	 data_out <= stack(conv_integer(stack_pointer(STACK_ADDR_SIZE-1 downto 0)));
  end if;
  
end process;

-- Stack Counter and Stack Pointer
process(clk, rst)
begin
  if rst = '1' then
    stack_counter <= (others => '0');
	 stack_pointer <= (others => '0');
  elsif clk'event and clk = '1' then 
    if stack_counter_full = '0' and inc = '1' then
		stack_counter <= stack_counter + 1;
		stack_pointer <= stack_counter;
	 elsif stack_pointer_negative = '0' and dec = '1' then
		stack_pointer <= stack_pointer - 1;
		stack_counter <= stack_pointer;
	 end if;
  end if;
end process;

end BR_STACK_arch;