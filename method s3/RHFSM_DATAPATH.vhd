library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity DATAPATH is
 generic (DATA_SIZE: integer;
          RAM_ADDR_SIZE: integer;
			 LOCAL_ADDR_SIZE: integer;
			 RHFSM_MAIN_X_WIDTH: integer;
			 RHFSM_MAIN_Y_WIDTH: integer;
			 RHFSM_SEC_X_WIDTH: integer;
			 RHFSM_SEC_Y_WIDTH: integer);
	 port (clk, rst: in STD_LOGIC;
	       XM: out STD_LOGIC_VECTOR (RHFSM_MAIN_X_WIDTH downto 1);
	       YM: in STD_LOGIC_VECTOR (RHFSM_MAIN_Y_WIDTH downto 1);
	       XS: out STD_LOGIC_VECTOR (RHFSM_SEC_X_WIDTH downto 1);
	       YS: in STD_LOGIC_VECTOR (RHFSM_SEC_Y_WIDTH downto 1);
			 data_in: in STD_LOGIC_VECTOR (DATA_SIZE-1 downto 0);
			 data_out: out STD_LOGIC_VECTOR (DATA_SIZE-1 downto 0);
			 dataflow: in STD_LOGIC;
			 ready: out STD_LOGIC;
			 new_data, next_data: out STD_LOGIC);
end DATAPATH;

architecture DATAPATH_arch of DATAPATH is

constant ZERO: STD_LOGIC_VECTOR (RAM_ADDR_SIZE-1 downto 0) := (others => '0');

component RAM is
 generic (RAM_DATA_SIZE: integer;
          RAM_ADDR_SIZE: integer);
    port (clk: in STD_LOGIC;
	       en_A, en_B, W_en_A: in STD_LOGIC;
			 input: in STD_LOGIC_VECTOR (RAM_DATA_SIZE-1 downto 0);
			 addr_A, addr_B: in STD_LOGIC_VECTOR (RAM_ADDR_SIZE-1 downto 0);
			 out_A, out_B: out STD_LOGIC_VECTOR (RAM_DATA_SIZE-1 downto 0));
end component;

subtype RAM_WORD is STD_LOGIC_VECTOR (DATA_SIZE+2*RAM_ADDR_SIZE-1 downto 0);
signal RAM_in, RAM_out_A, RAM_out_B: RAM_WORD;
signal RAM_W_en: STD_LOGIC;
signal RAM_addr_A, RAM_addr_B: STD_LOGIC_VECTOR (RAM_ADDR_SIZE-1 downto 0);
signal RAM_in_data: STD_LOGIC_VECTOR (DATA_SIZE-1 downto 0);
signal RAM_in_la, RAM_in_ra: STD_LOGIC_VECTOR (RAM_ADDR_SIZE-1 downto 0);
signal RAM_out_A_data: STD_LOGIC_VECTOR (DATA_SIZE-1 downto 0);
signal RAM_out_A_la, RAM_out_A_ra: STD_LOGIC_VECTOR (RAM_ADDR_SIZE-1 downto 0);
signal RAM_out_B_data: STD_LOGIC_VECTOR (DATA_SIZE-1 downto 0);
signal RAM_out_B_la, RAM_out_B_ra: STD_LOGIC_VECTOR (RAM_ADDR_SIZE-1 downto 0);

component BR_STACK is
--component STACK is
 generic (STACK_ADDR_SIZE: integer;
          DATA_SIZE: integer);
	 port (clk, rst: in STD_LOGIC;
	       inc, dec: in STD_LOGIC;
	       data_in: in STD_LOGIC_VECTOR (DATA_SIZE-1 downto 0);
			 data_out: out STD_LOGIC_VECTOR (DATA_SIZE-1 downto 0);
			 upper_bound, lower_bound: out STD_LOGIC);
end component;

component BR_STACK_NEG is
 generic (STACK_ADDR_SIZE: integer;
          DATA_SIZE: integer);
	 port (clk, rst: in STD_LOGIC;
	       inc, dec: in STD_LOGIC;
	       data_in: in STD_LOGIC_VECTOR (DATA_SIZE-1 downto 0);
			 data_out: out STD_LOGIC_VECTOR (DATA_SIZE-1 downto 0);
			 upper_bound, lower_bound: out STD_LOGIC);
end component;

signal local_main_out, local_sec_out: STD_LOGIC_VECTOR (RAM_ADDR_SIZE-1 downto 0);
signal temp_data_out: STD_LOGIC_VECTOR (DATA_SIZE-1 downto 0);
signal temp_data_empty: STD_LOGIC;

component RG is
 generic (RG_WIDTH: integer);
    port (clk, rst: in STD_LOGIC;
	       RG_en: in STD_LOGIC;
	       RG_in: in STD_LOGIC_VECTOR (RG_WIDTH-1 downto 0);
			 RG_out: out STD_LOGIC_VECTOR (RG_WIDTH-1 downto 0));
end component;

signal BUF_L_MAIN_rst, BUF_L_SEC_rst: STD_LOGIC;
signal BUF_L_MAIN_out, BUF_L_SEC_out: STD_LOGIC_VECTOR (RAM_ADDR_SIZE-1 downto 0);
signal BUF_D_out: STD_LOGIC_VECTOR (DATA_SIZE-1 downto 0);

component COUNTER is
 generic (COUNTER_WIDTH: integer);
    port (clk, rst: in STD_LOGIC;
	       counter_en: in STD_LOGIC;
			 full, zero: out STD_LOGIC;
			 counter_out: out STD_LOGIC_VECTOR (COUNTER_WIDTH-1 downto 0));
end component;

signal RAM_counter_out: STD_LOGIC_VECTOR (RAM_ADDR_SIZE-1 downto 0);
signal RAM_counter_zero: STD_LOGIC;

signal root, same, smaller: STD_LOGIC;
signal left_zero_main, right_zero_main: STD_LOGIC;
signal enable_RAM_A, enable_out, enable_temp_out: STD_LOGIC;
signal write_new_node, write_left_address, write_right_address: STD_LOGIC;
signal write_BUF_L_MAIN, write_BUF_D: STD_LOGIC;
signal sel_address_main, sel_root_main, sel_BUF_main: STD_LOGIC;
signal push_main, pop_main: STD_LOGIC;
signal start_sec, pop_temp: STD_LOGIC;

signal ready_sec: STD_LOGIC;
signal left_zero_sec, right_zero_sec: STD_LOGIC;
signal enable_RAM_B: STD_LOGIC;
signal write_BUF_L_SEC: STD_LOGIC;
signal sel_address_sec, sel_root_sec, sel_BUF_sec: STD_LOGIC;
signal push_sec, pop_sec: STD_LOGIC;
signal push_temp: STD_LOGIC;

signal addr_A_MUX, addr_B_MUX: STD_LOGIC_VECTOR (RAM_ADDR_SIZE-1 downto 0);

begin

-- Mapping of Main Primary Inputs
XM(1) <= dataflow;
XM(2) <= root;
XM(3) <= same;
XM(4) <= smaller;
XM(5) <= left_zero_main;
XM(6) <= right_zero_main;
XM(7) <= ready_sec;
XM(8) <= temp_data_empty;

-- Mapping of Main Primary Outputs
ready <= YM(1);
enable_RAM_A <= YM(2);
write_BUF_L_MAIN <= YM(3);
write_BUF_D <= YM(4);
enable_temp_out <= YM(5);
write_new_node <= YM(6);
write_left_address <= YM(7);
write_right_address <= YM(8);
next_data <= YM(9);
sel_address_main <= YM(10);
sel_root_main <= YM(11);
sel_BUF_main <= YM(12);
enable_out <= YM(13);
push_main <= YM(14);
pop_main <= YM(15);
pop_temp <= YM(16);
start_sec <= YM(17);

-- Mapping of Secondary Primary Inputs
XS(1) <= start_sec;
XS(2) <= left_zero_sec;
XS(3) <= right_zero_sec;

-- Mapping of Secondary Primary Outputs
ready_sec <= YS(1);
enable_RAM_B <= YS(2);
write_BUF_L_sec <= YS(3);
sel_address_sec <= YS(4);
sel_root_sec <= YS(5);
sel_BUF_sec <= YS(6);
push_sec <= YS(7);
pop_sec <= YS(8);
push_temp <= YS(9);

-- Mapping of RAM Inputs
RAM_in(DATA_SIZE+2*RAM_ADDR_SIZE-1 downto 2*RAM_ADDR_SIZE) <= RAM_in_data;
RAM_in(2*RAM_ADDR_SIZE-1 downto RAM_ADDR_SIZE) <= RAM_in_la;
RAM_in(RAM_ADDR_SIZE-1 downto 0) <= RAM_in_ra;
-- Mapping of RAM Outputs
RAM_out_A_data <= RAM_out_A(DATA_SIZE+2*RAM_ADDR_SIZE-1 downto 2*RAM_ADDR_SIZE);
RAM_out_A_la <= RAM_out_A(2*RAM_ADDR_SIZE-1 downto RAM_ADDR_SIZE);
RAM_out_A_ra <= RAM_out_A(RAM_ADDR_SIZE-1 downto 0);
RAM_out_B_data <= RAM_out_B(DATA_SIZE+2*RAM_ADDR_SIZE-1 downto 2*RAM_ADDR_SIZE);
RAM_out_B_la <= RAM_out_B(2*RAM_ADDR_SIZE-1 downto RAM_ADDR_SIZE);
RAM_out_B_ra <= RAM_out_B(RAM_ADDR_SIZE-1 downto 0);

-- Address MUX
addr_A_MUX <= RAM_out_A_ra when sel_address_main = '1' else RAM_out_A_la;
addr_B_MUX <= RAM_out_B_ra when sel_address_sec = '1' else RAM_out_B_la;

-- Data Output
data_out <= RAM_out_A_data when enable_out = '1' else 
            temp_data_out when enable_temp_out = '1' else
				(others => '0');
new_data <= enable_out or enable_temp_out;

-- Conditional Signals
left_zero_main <= '1' when RAM_out_A_la = ZERO else '0';
right_zero_main <= '1' when RAM_out_A_ra = ZERO else '0';
left_zero_sec <= '1' when RAM_out_B_la = ZERO else '0';
right_zero_sec <= '1' when RAM_out_B_ra = ZERO else '0';
root <= RAM_counter_zero;
same <= '1' when BUF_D_out = RAM_out_A_data else '0';
smaller <= '1' when BUF_D_out < RAM_out_A_data else '0';

-- Main Local Stack
LOCAL_MAIN:BR_STACK_NEG
--LOCAL_MAIN:STACK
generic map (LOCAL_ADDR_SIZE, RAM_ADDR_SIZE)
port map (clk, rst, push_main, pop_main, BUF_L_MAIN_out, local_main_out, open, open);         

-- Secondary Local Stack
LOCAL_SEC:BR_STACK_NEG
--LOCAL_SEC:STACK
generic map (LOCAL_ADDR_SIZE, RAM_ADDR_SIZE)
port map (clk, rst, push_sec, pop_sec, BUF_L_SEC_out, local_sec_out, open, open);         

-- Temp Data Stack
TEMP_DATA:BR_STACK
--TEMP_DATA:STACK
generic map (RAM_ADDR_SIZE, DATA_SIZE)
port map (clk, rst, push_temp, pop_temp, RAM_out_B_data, temp_data_out, open, temp_data_empty);         

-- Data RAM
DATA_RAM:RAM
generic map (DATA_SIZE+2*RAM_ADDR_SIZE, RAM_ADDR_SIZE)
port map (clk, enable_RAM_A, enable_RAM_B, RAM_W_en, RAM_in, RAM_addr_A, RAM_addr_B, RAM_out_A, RAM_out_B);
-- RAM Enable/Write Enable
RAM_W_en <= write_new_node or write_left_address or write_right_address;
-- RAM Input
RAM_in_data <= RAM_out_A_data when (write_left_address or write_right_address) = '1'
else BUF_D_out;
RAM_in_la <= ZERO when write_new_node = '1'
else RAM_counter_out when write_left_address = '1' 
else RAM_out_A_la;
RAM_in_ra <= ZERO when write_new_node = '1'
else RAM_counter_out when write_right_address = '1'
else RAM_out_A_ra;
-- RAM Address A
RAM_addr_A <= RAM_counter_out when write_new_node = '1'
else BUF_L_MAIN_out when sel_BUF_main = '1'
else local_main_out when pop_main = '1'
else addr_A_MUX;
-- RAM Address B
RAM_addr_B <= BUF_L_SEC_out when sel_BUF_sec = '1'
else local_sec_out when pop_sec = '1'
else addr_B_MUX;

-- Left Buffer Register
BUF_L_MAIN:RG
generic map (RAM_ADDR_SIZE)
port map (clk, BUF_L_MAIN_rst, write_BUF_L_MAIN, addr_A_MUX, BUF_L_MAIN_out);
BUF_L_MAIN_rst <= sel_root_main or rst;

BUF_L_SEC:RG
generic map (RAM_ADDR_SIZE)
port map (clk, BUF_L_SEC_rst, write_BUF_L_SEC, addr_B_MUX, BUF_L_SEC_out);
BUF_L_SEC_rst <= sel_root_sec or rst;

-- Data Buffer Register
BUF_D:RG
generic map (DATA_SIZE)
port map (clk, rst, write_BUF_D, data_in, BUF_D_out);

-- RAM Counter
RAM_COUNTER:COUNTER
generic map (RAM_ADDR_SIZE)
port map (clk, rst, write_new_node, open, RAM_counter_zero, RAM_counter_out);

end DATAPATH_arch;