library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity RHFSM is
 generic (STACK_ADDR_SIZE: integer;
          X_WIDTH: integer;
			 Y_WIDTH: integer);
    port (clk, rst: in STD_LOGIC;
			 X: in STD_LOGIC_VECTOR (X_WIDTH downto 1);
			 Y: out STD_LOGIC_VECTOR (Y_WIDTH downto 1);
			 stack_upper_bound, stack_lower_bound: out STD_LOGIC);
end RHFSM;

architecture RHFSM_arch of RHFSM is
type STATE_TYPE is (a00, a01, a02, a03, a04, a10, a11, a12, a13, a14, a15, a16, a17, a20, a21, a22, a23, a24, a25, a26, a27, a28);

--type STATE_TYPE is (a00, a01, a02, a03, a04, a10, a11, a12, a13, a14, a15, a16, a17, a20, a21, a22, a23, a24, a25, a26, a27, a28);
--attribute enum_encoding: string;
--attribute enum_encoding of STATE_TYPE: type is "00011 00010 01010 01001 00111 11010 11001 11111 11110 01111 11100 11101 11011 00000 00001 00100 01100 00110 00101 01110 01101 01011";

--type STATE_TYPE is (a20, a25, a16, a26, a00, a17, a27, a01, a14, a28, a02, a15, a21, a03, a12, a22, a04, a13, a23, a10, a24, a11);
--attribute enum_encoding: string;
--attribute enum_encoding of STATE_TYPE: type is "01111 01010 10010 00001 01100 10100 00010 01101 00000 00100 00101 10011 01110 00110 10000 01011 01000 10001 00011 10101 01001 10110";

signal current_state, next_state, return_state: STATE_TYPE;
--type STATE_STACK is array (0 to 2**STACK_ADDR_SIZE-1) of STATE_TYPE;
--signal FSM_stack_out: STATE_TYPE;
type STATE_STACK is array (0 to 2**STACK_ADDR_SIZE-1) of STD_LOGIC_VECTOR (1 downto 0);
signal FSM_stack_out: STD_LOGIC_VECTOR (1 downto 0);
signal FSM_stack: STATE_STACK;
signal stack_counter: STD_LOGIC_VECTOR (STACK_ADDR_SIZE downto 0);
signal stack_counter_full: STD_LOGIC;
signal stack_pointer: STD_LOGIC_VECTOR (STACK_ADDR_SIZE downto 0);
signal stack_pointer_negative: STD_LOGIC;
signal inc, dec: STD_LOGIC;

signal FSM_encode: STD_LOGIC_VECTOR (1 downto 0);
signal FSM_decode: STATE_TYPE;

begin

-- Stack Overflow Output
stack_upper_bound <= stack_counter_full;

-- Stack Underflow Output
stack_lower_bound <= stack_pointer_negative;

-- Stack Counter is Full
stack_counter_full <= stack_counter(STACK_ADDR_SIZE);

-- Stack Pointer is Negative
stack_pointer_negative <= stack_pointer(STACK_ADDR_SIZE);

-- Stack Memory (BlockRAM)
--process(clk)
--begin
--
--  if clk'event and clk = '0' then 
--    if stack_counter_full = '0' and inc = '1' then
--		FSM_stack(conv_integer(stack_counter(STACK_ADDR_SIZE-1 downto 0))) <= return_state;
----		FSM_stack(conv_integer(stack_counter(STACK_ADDR_SIZE-1 downto 0))) <= FSM_encode;
--	 end if;
--	 FSM_stack_out <= FSM_stack(conv_integer(stack_pointer(STACK_ADDR_SIZE-1 downto 0)));
--  end if;
--  
--end process;

-- Stack Memory (DistributedRAM)
process(clk)
begin

  if clk'event and clk = '1' then 
    if stack_counter_full = '0' and inc = '1' then
--		FSM_stack(conv_integer(stack_counter(STACK_ADDR_SIZE-1 downto 0))) <= return_state;
		FSM_stack(conv_integer(stack_counter(STACK_ADDR_SIZE-1 downto 0))) <= FSM_encode;
	 end if;
  end if;
  
end process;

FSM_stack_out <= FSM_stack(conv_integer(stack_pointer(STACK_ADDR_SIZE-1 downto 0)));

FSM_encode <= "00" when return_state = a02 else
              "01" when return_state = a04 else
				  "10" when return_state = a24 else
				  "11";

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
    current_state <= a00;
  elsif clk'event and clk = '1' then 
	 if stack_pointer_negative = '0' and dec = '1' then
--	   current_state <= FSM_stack_out;	 
	   current_state <= FSM_decode;
	 else
	   current_state <= next_state;
	 end if;
  end if;

end process;

FSM_decode <= a02 when FSM_stack_out = "00" else
              a04 when FSM_stack_out = "01" else
				  a24 when FSM_stack_out = "10" else
				  a28;

--Combinational Part of RHFSM
process (current_state, X, stack_pointer_negative)
begin

next_state <= current_state;
return_state <= current_state;
Y <= (others => '0');
inc <= '0';
dec <= '0';

case current_state is

               when a00 => next_state <= a01;								-- Begin
					when a01 => if X(1) = '1' then								-- Check and Store New Data
                             next_state <= a10;								
								     return_state <= a02;
								     inc <= '1';
									  Y(2) <= '1'; Y(3) <= '1'; Y(4) <= '1'; Y(5) <= '1'; Y(18) <= '1';
								   else
								     next_state <= a04;                        
								   end if;
					when a02 => next_state <= a03;								-- Select Root
								   Y(2) <= '1'; Y(3) <= '1'; Y(5) <= '1'; 					           
					when a03 => next_state <= a20;								-- Sort Data
								   return_state <= a04;
								   inc <= '1';
								   Y(2) <= '1'; Y(16) <= '1'; Y(17) <= '1'; Y(18) <= '1'; 
					when a04 => if stack_pointer_negative = '0' then		-- End		    
                             dec <= '1';									 
								   end if;
								   Y(1) <= '1';  
					when a10 => if X(2) = '1' then								-- Begin
					              next_state <= a15;
								   elsif X(3) = '1' then
								     next_state <= a16;
								   elsif X(4) = '1' then
								     if X(5) = '1' then
								       next_state <= a14;
									  else
									    next_state <= a12;
								     end if;
								   else
								     if X(6) = '1' then
								       next_state <= a13;
									  else
									    next_state <= a11;
								     end if;
								   end if;
					when a11 => next_state <= a10;								-- Goto Right Node
								   Y(2) <= '1'; Y(10) <= '1'; Y(17) <= '1';
					when a12 => next_state <= a10;								-- Goto Left Node
								   Y(2) <= '1';  Y(17) <= '1';
					when a13 => next_state <= a15;								-- Write Right Address
					            Y(2) <= '1'; Y(3) <= '1'; Y(8) <= '1';
					when a14 => next_state <= a15;								-- Write Left Address
					            Y(2) <= '1'; Y(3) <= '1'; Y(7) <= '1';
					when a15 => next_state <= a17;								-- Write New Node
					            Y(2) <= '1'; Y(6) <= '1'; Y(9) <= '1';
					when a16 => next_state <= a17;								-- Next Data
					            Y(9) <= '1';
					when a17 => if X(1) = '1' then								-- Check and Store New Data
                             next_state <= a10;								
                             Y(2) <= '1'; Y(3) <= '1'; Y(4) <= '1'; Y(5) <= '1'; Y(18) <= '1'; 
								   elsif stack_pointer_negative = '0' then	-- End
                             dec <= '1';						
								   end if;        
               when a20 => if X(7) = '1' then								-- Begin
					              next_state <= a24;
								   elsif X(5) = '1' then
									  next_state <= a22;
								   else
									  next_state <= a21;
								   end if;									
				   when a21 => next_state <= a20;								-- Goto Left Node
								   return_state <= a24;
								   inc <= '1';
								   Y(2) <= '1'; Y(14) <= '1'; 
								   Y(16) <= '1'; Y(17) <= '1'; Y(18) <= '1';
					when a22 => if X(6) = '1' then								-- Output Left Node
					              next_state <= a24;
                           else
                             next_state <= a23;
									  Y(2) <= '1'; Y(10) <= '1'; Y(14) <= '1';  
								   end if;
								   Y(13) <= '1';    
					when a23 => next_state <= a20;								-- Goto Left Right Node
								   return_state <= a24;
					            inc <= '1';
								   Y(2) <= '1'; 
								   Y(16) <= '1'; Y(17) <= '1'; Y(18) <= '1';
					when a24 => if X(8) = '1' then 								-- Output Current Node
					              next_state <= a28;
								   elsif X(9) = '1' then
									  next_state <= a26;
								   else
									  next_state <= a25;
								   end if;
								   Y(12) <= '1'; Y(13) <= '1';
					when a25 => next_state <= a20;								-- Goto Right Node
								   return_state <= a28;
								   inc <= '1';
								   Y(2) <= '1'; Y(11) <= '1'; Y(14) <= '1'; 
								   Y(16) <= '1'; Y(17) <= '1'; Y(18) <= '1';
					when a26 => if X(10) = '1' then								-- Output Right Node
					              next_state <= a28;
                           else
                             next_state <= a27;
									  Y(2) <= '1'; Y(10) <= '1'; Y(14) <= '1';
								   end if;
								   Y(11) <= '1'; Y(13) <= '1';
   				when a27 => next_state <= a20;								-- Goto Right Right Node
								   return_state <= a28;
					            inc <= '1';
								   Y(2) <= '1'; 
								   Y(16) <= '1'; Y(17) <= '1'; Y(18) <= '1';
					when a28 => if stack_pointer_negative = '0' then			-- End
								     dec <= '1';
								   end if;
								   Y(2) <= '1'; Y(15) <= '1'; 
								   Y(16) <= '1'; Y(17) <= '1'; Y(18) <= '1';
	
end case;

end process;

end RHFSM_arch;