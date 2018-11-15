library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity RHFSM_SEC is
 generic (STACK_ADDR_SIZE: integer;
          X_WIDTH: integer;
			 Y_WIDTH: integer);
    port (clk, rst: in STD_LOGIC;
			 X: in STD_LOGIC_VECTOR (X_WIDTH downto 1);
			 Y: out STD_LOGIC_VECTOR (Y_WIDTH downto 1);
			 stack_upper_bound, stack_lower_bound: out STD_LOGIC);
end RHFSM_SEC;

architecture RHFSM_SEC_arch of RHFSM_SEC is
type MODULE_TYPE is (z0, z1);
signal current_module, next_module, M_stack_out: MODULE_TYPE;
type MODULE_STACK is array (0 to 2**STACK_ADDR_SIZE-1) of MODULE_TYPE;
signal M_stack: MODULE_STACK;
type STATE_TYPE is (a0, a1, a2, a3, a4);
signal current_state, next_state, FSM_stack_out: STATE_TYPE;
type STATE_STACK is array (0 to 2**STACK_ADDR_SIZE-1) of STATE_TYPE;
signal FSM_stack: STATE_STACK;
signal stack_counter: STD_LOGIC_VECTOR (STACK_ADDR_SIZE downto 0);
signal stack_counter_full: STD_LOGIC;
signal stack_pointer: STD_LOGIC_VECTOR (STACK_ADDR_SIZE downto 0);
signal stack_pointer_negative: STD_LOGIC;
signal inc, dec: STD_LOGIC;

begin

-- Stack Overflow Output
stack_upper_bound <= stack_counter_full;

-- Stack Underflow Output
stack_lower_bound <= stack_pointer_negative;

-- Stack Counter is Full
stack_counter_full <= stack_counter(STACK_ADDR_SIZE);

-- Stack Pointer is Negative
stack_pointer_negative <= stack_pointer(STACK_ADDR_SIZE);
  
-- Stack Memory (BlockRaM)
--process(clk)
--begin
--
--  if clk'event and clk = '0' then 
--    if stack_counter_full = '0' and inc = '1' then
--		FSM_stack(conv_integer(stack_counter(STACK_ADDR_SIZE-1 downto 0))) <= next_state;
--		M_stack(conv_integer(stack_counter(STACK_ADDR_SIZE-1 downto 0))) <= current_module;
--	 end if;
--	 FSM_stack_out <= FSM_stack(conv_integer(stack_pointer(STACK_ADDR_SIZE-1 downto 0)));
--    M_stack_out <= M_stack(conv_integer(stack_pointer(STACK_ADDR_SIZE-1 downto 0)));
--  end if;
--  
--end process;

-- Stack Memory (DistributedRAM)
process(clk)
begin

  if clk'event and clk = '1' then 
    if stack_counter_full = '0' and inc = '1' then
		FSM_stack(conv_integer(stack_counter(STACK_ADDR_SIZE-1 downto 0))) <= next_state;
		M_stack(conv_integer(stack_counter(STACK_ADDR_SIZE-1 downto 0))) <= current_module;
	 end if;
  end if;
  
end process;

FSM_stack_out <= FSM_stack(conv_integer(stack_pointer(STACK_ADDR_SIZE-1 downto 0)));
M_stack_out <= M_stack(conv_integer(stack_pointer(STACK_ADDR_SIZE-1 downto 0)));

-- Stack Pointer, Stack Counter
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

-- RHFSM State Register
process(clk, rst)
begin

  if rst = '1' then
    current_state <= a0;
  elsif clk'event and clk = '1' then 
	 if stack_counter_full = '0' and inc = '1' then
      current_state <= a0;
	 elsif stack_pointer_negative = '0' and dec = '1' then
	   current_state <= FSM_stack_out;
	 else
	   current_state <= next_state;
	 end if;
  end if;

end process;

-- RHFSM Module Register
process(clk, rst)
begin

  if rst = '1' then
	 current_module <= z0;
  elsif clk'event and clk = '1' then
    if stack_pointer_negative = '0' and dec = '1' then
	   current_module <= M_stack_out;
	 else
	   current_module <= next_module;
	 end if;
  end if;

end process;

--Combinational Part of RHFSM
process (current_state, current_module, X, stack_pointer_negative)
begin

next_state <= current_state;
next_module <= current_module;
Y <= (others => '0');
inc <= '0';
dec <= '0';

case current_module is

  when z0 => case current_state is												-- Top-Level Module
  
               when a0 => if X(1) = '1' then                         -- Begin
					             next_state <= a1;
                          else
                            next_state <= a0;
                          end if;									 
					when a1 => next_state <= a2;									-- Select Root
                          Y(2) <= '1'; Y(5) <= '1'; Y(6) <= '1';					
					when a2 => if X(3) = '1' then									-- Sort Data
					             next_state <= a3;
								  else	 
					             next_state <= a3;									
								    next_module <= z1;
								    inc <= '1';
								    Y(2) <= '1'; Y(3) <= '1'; Y(4) <= '1';
                          end if;									 
					when a3 => if stack_pointer_negative = '0' then			-- End
								    dec <= '1';
								  end if;
								  Y(1) <= '1';			  
					when others => null;
								  
				 end case;
				 
  when z1 => case current_state is												-- Sort Data Module
             
--               when a0 => if X(2) = '1' then									-- Begin
--					             next_state <= a2;
--								  else
--									 next_state <= a1;
--								  end if;							  
--				   when a1 => next_state <= a2;									-- Goto Left Node
--								  next_module <= z1;
--								  inc <= '1';
--								  Y(2) <= '1'; Y(3) <= '1'; Y(7) <= '1';
--					when a2 => if X(3) = '1' then									-- Output Node
--					             next_state <= a4;
--								  else
--					             next_state <= a3;
--								  end if;
--								  Y(9) <= '1';
--					when a3 => next_state <= a4;									-- Goto Right Node
--								  next_module <= z1;
--								  inc <= '1';
--								  Y(2) <= '1'; Y(3) <= '1'; Y(4) <= '1'; Y(7) <= '1';
--					when a4 => if stack_pointer_negative = '0' then			-- End
--								    dec <= '1';
--								  end if;
--								  Y(2) <= '1'; Y(3) <= '1'; Y(8) <= '1';
--					when others => NULL;
--					
--				 end case;

               when a0 => if X(3) = '1' then									-- Begin
					             next_state <= a2;
								  else
									 next_state <= a1;
								  end if;
               when a1 => next_state <= a2;									-- Goto Right Node
								  next_module <= z1;
								  inc <= '1';
								  Y(2) <= '1'; Y(3) <= '1'; Y(4) <= '1'; Y(7) <= '1';								  				   
					when a2 => if X(2) = '1' then									-- Output Node
					             next_state <= a4;
								  else
					             next_state <= a3;
								  end if;
								  Y(9) <= '1';
					when a3 => next_state <= a4;									-- Goto Left Node
								  next_module <= z1;
								  inc <= '1';
								  Y(2) <= '1'; Y(3) <= '1'; Y(7) <= '1';
					when a4 => if stack_pointer_negative = '0' then			-- End
								    dec <= '1';
								  end if;
								  Y(2) <= '1'; Y(3) <= '1'; Y(8) <= '1';
					when others => NULL;
					
				 end case;

end case;

end process;

end RHFSM_SEC_arch;