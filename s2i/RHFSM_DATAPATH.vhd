library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity DATAPATH is
 generic (DATA_SIZE: integer;
          RAM_ADDR_SIZE: integer;
			 LOCAL_ADDR_SIZE: integer;
			 RHFSM_X_WIDTH: integer;
			 RHFSM_Y_WIDTH: integer);
	 port (clk, rst: in STD_LOGIC;
	       X: out STD_LOGIC_VECTOR (RHFSM_X_WIDTH downto 1);
	       Y: in STD_LOGIC_VECTOR (RHFSM_Y_WIDTH downto 1);
			 data_in: in STD_LOGIC_VECTOR (DATA_SIZE-1 downto 0);
			 data_out: out STD_LOGIC_VECTOR (DATA_SIZE-1 downto 0);
			 dataflow: in STD_LOGIC;
			 ready, new_data, next_data: out STD_LOGIC;
			 local_full, local_empty: out STD_LOGIC;
			 RAM_full: out STD_LOGIC);
end DATAPATH;

architecture DATAPATH_arch of DATAPATH is

constant ZERO: STD_LOGIC_VECTOR (RAM_ADDR_SIZE-1 downto 0) := (others => '0');

component RAM is
 generic (RAM_DATA_SIZE: integer;
          RAM_ADDR_SIZE: integer);
    port (clk: in STD_LOGIC;
	       en_A, W_en_A: in STD_LOGIC;
			 input: in STD_LOGIC_VECTOR (RAM_DATA_SIZE-1 downto 0);
			 addr_A, addr_B: in STD_LOGIC_VECTOR (RAM_ADDR_SIZE-1 downto 0);
			 out_A, out_B: out STD_LOGIC_VECTOR (RAM_DATA_SIZE-1 downto 0));
end component;

subtype RAM_WORD is STD_LOGIC_VECTOR (DATA_SIZE+2*RAM_ADDR_SIZE-1 downto 0);
signal RAM_in, RAM_out_A, RAM_out_B: RAM_WORD;
signal RAM_W_en: STD_LOGIC;
signal RAM_addr_A, RAM_addr_B: STD_LOGIC_VECTOR (RAM_ADDR_SIZE-1 downto 0);
signal RAM_in_data, RAM_out_A_data: STD_LOGIC_VECTOR (DATA_SIZE-1 downto 0);
signal RAM_in_la, RAM_out_A_la, RAM_out_B_la: STD_LOGIC_VECTOR (RAM_ADDR_SIZE-1 downto 0);
signal RAM_in_ra, RAM_out_A_ra, RAM_out_B_ra: STD_LOGIC_VECTOR (RAM_ADDR_SIZE-1 downto 0);

component BR_STACK is
 generic (STACK_ADDR_SIZE: integer;
          DATA_SIZE: integer);
	 port (clk, rst: in STD_LOGIC;
	       inc, dec: in STD_LOGIC;
	       data_in: in STD_LOGIC_VECTOR (DATA_SIZE-1 downto 0);
			 data_out: out STD_LOGIC_VECTOR (DATA_SIZE-1 downto 0);
			 upper_bound, lower_bound: out STD_LOGIC);
end component;

signal local_in, local_out: RAM_WORD;
signal local_in_data: STD_LOGIC_VECTOR (DATA_SIZE-1 downto 0);
signal local_in_la, local_in_ra: STD_LOGIC_VECTOR (RAM_ADDR_SIZE-1 downto 0);
signal local_out_data: STD_LOGIC_VECTOR (DATA_SIZE-1 downto 0);
signal local_out_la, local_out_ra: STD_LOGIC_VECTOR (RAM_ADDR_SIZE-1 downto 0);

component RG is
 generic (RG_WIDTH: integer);
    port (clk, rst: in STD_LOGIC;
	       RG_en: in STD_LOGIC;
	       RG_in: in STD_LOGIC_VECTOR (RG_WIDTH-1 downto 0);
			 RG_out: out STD_LOGIC_VECTOR (RG_WIDTH-1 downto 0));
end component;

signal BUF_L_rst: STD_LOGIC;
signal BUF_L_out, BUF_R_out: STD_LOGIC_VECTOR (RAM_ADDR_SIZE-1 downto 0);
signal BUF_L_MUX, BUF_R_MUX: STD_LOGIC_VECTOR (RAM_ADDR_SIZE-1 downto 0);
signal BUF_D_out: STD_LOGIC_VECTOR (DATA_SIZE-1 downto 0);
signal BUF_D_MUX: STD_LOGIC_VECTOR (DATA_SIZE-1 downto 0);

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
signal left_zero, right_zero: STD_LOGIC;
signal left_left_zero, left_right_zero: STD_LOGIC;
signal right_left_zero, right_right_zero: STD_LOGIC;
signal enable_RAM, enable_out: STD_LOGIC;
signal write_new_node, write_data_in: STD_LOGIC;
signal write_left_address, write_right_address: STD_LOGIC;
signal write_BUF_L, write_BUF_R, write_BUF_D: STD_LOGIC;
signal sel_address, sel_port, sel_output, sel_root, sel_BUF: STD_LOGIC;
signal push, pop: STD_LOGIC;

signal port_MUX: RAM_WORD;
signal port_MUX_data: STD_LOGIC_VECTOR (DATA_SIZE-1 downto 0);
signal port_MUX_la, port_MUX_ra: STD_LOGIC_VECTOR (RAM_ADDR_SIZE-1 downto 0);
signal addr_MUX: STD_LOGIC_VECTOR (RAM_ADDR_SIZE-1 downto 0);
signal output_MUX: STD_LOGIC_VECTOR (DATA_SIZE-1 downto 0);

begin

-- Mapping of Primary Inputs
X(1) <= dataflow;
X(2) <= root;
X(3) <= same;
X(4) <= smaller;
X(5) <= left_left_zero;
X(6) <= left_right_zero;
x(7) <= left_zero;
X(8) <= right_zero;
X(9) <= right_left_zero;
X(10) <= right_right_zero;

-- Mapping of Primary Outputs
ready <= Y(1);
enable_RAM <= Y(2);
sel_BUF <= Y(3);
write_data_in <= Y(4);
sel_root <= Y(5);
write_new_node <= Y(6);
write_left_address <= Y(7);
write_right_address <= Y(8);
next_data <= Y(9);
sel_address <= Y(10);
sel_port <= Y(11);
sel_output <= Y(12);
enable_out <= Y(13);
push <= Y(14);
pop <= Y(15);
write_BUF_R <= Y(16);
write_BUF_L <= Y(17);
write_BUF_D <= Y(18);

-- Mapping of RAM Inputs
RAM_in(DATA_SIZE+2*RAM_ADDR_SIZE-1 downto 2*RAM_ADDR_SIZE) <= RAM_in_data;
RAM_in(2*RAM_ADDR_SIZE-1 downto RAM_ADDR_SIZE) <= RAM_in_la;
RAM_in(RAM_ADDR_SIZE-1 downto 0) <= RAM_in_ra;
-- Mapping of RAM Outputs
RAM_out_A_data <= RAM_out_A(DATA_SIZE+2*RAM_ADDR_SIZE-1 downto 2*RAM_ADDR_SIZE);
RAM_out_A_la <= RAM_out_A(2*RAM_ADDR_SIZE-1 downto RAM_ADDR_SIZE);
RAM_out_A_ra <= RAM_out_A(RAM_ADDR_SIZE-1 downto 0);
RAM_out_B_la <= RAM_out_B(2*RAM_ADDR_SIZE-1 downto RAM_ADDR_SIZE);
RAM_out_B_ra <= RAM_out_B(RAM_ADDR_SIZE-1 downto 0);
-- Mapping of Port MUX Outputs
port_MUX_data <= port_MUX(DATA_SIZE+2*RAM_ADDR_SIZE-1 downto 2*RAM_ADDR_SIZE);
port_MUX_la <= port_MUX(2*RAM_ADDR_SIZE-1 downto RAM_ADDR_SIZE);
port_MUX_ra <= port_MUX(RAM_ADDR_SIZE-1 downto 0);
-- Mapping of Local Stack Inputs
local_in(DATA_SIZE+2*RAM_ADDR_SIZE-1 downto 2*RAM_ADDR_SIZE) <= local_in_data;
local_in(2*RAM_ADDR_SIZE-1 downto RAM_ADDR_SIZE) <= local_in_la;
local_in(RAM_ADDR_SIZE-1 downto 0) <= local_in_ra;
-- Mapping of Local Stack Outputs
local_out_data <= local_out(DATA_SIZE+2*RAM_ADDR_SIZE-1 downto 2*RAM_ADDR_SIZE);
local_out_la <= local_out(2*RAM_ADDR_SIZE-1 downto RAM_ADDR_SIZE);
local_out_ra <= local_out(RAM_ADDR_SIZE-1 downto 0);

-- Port MUX
port_MUX <= RAM_out_B when sel_port = '1' else RAM_out_A;
-- Address MUX
addr_MUX <= port_MUX_ra when sel_address = '1' else port_MUX_la;
-- Output MUX
output_MUX <= BUF_D_out when sel_output = '1' else port_MUX_data;

-- Data Output
data_out <= output_MUX when enable_out = '1' else (others => '0');
new_data <= enable_out;

-- Conditional Signals
left_zero <= '1' when BUF_L_out = ZERO else '0';
right_zero <= '1' when BUF_R_out = ZERO else '0';
left_left_zero <= '1' when RAM_out_A_la = ZERO else '0';
left_right_zero <= '1' when RAM_out_A_ra = ZERO else '0';
right_left_zero <= '1' when RAM_out_B_la = ZERO else '0';
right_right_zero <= '1' when RAM_out_B_ra = ZERO else '0';
root <= RAM_counter_zero;
same <= '1' when BUF_D_out = RAM_out_A_data else '0';
smaller <= '1' when BUF_D_out < RAM_out_A_data else '0';

-- Local Stack
LOCAL:BR_STACK
generic map (LOCAL_ADDR_SIZE, DATA_SIZE+2*RAM_ADDR_SIZE)
port map (clk, rst, push, pop, local_in, local_out, open, open);         
local_in_data <= BUF_D_out;
local_in_la <= BUF_L_out;
local_in_ra <= BUF_R_out;

-- Data RAM
DATA_RAM:RAM
generic map (DATA_SIZE+2*RAM_ADDR_SIZE, RAM_ADDR_SIZE)
port map (clk, enable_RAM, RAM_W_en, RAM_in, RAM_addr_A, RAM_addr_B, RAM_out_A, RAM_out_B);
-- RAM Enable/Write Enable
RAM_W_en <= write_new_node or write_left_address or write_right_address;
-- RAM Input
RAM_in_data <= RAM_out_A_data when (write_left_address or write_right_address) = '1'
else BUF_D_out;--else local_out_data;
RAM_in_la <= ZERO when write_new_node = '1'
else RAM_counter_out when write_left_address = '1' 
else RAM_out_A_la;
RAM_in_ra <= ZERO when write_new_node = '1'
else RAM_counter_out when write_right_address = '1'
else RAM_out_A_ra;
-- RAM Address A
RAM_addr_A <= RAM_counter_out when write_new_node = '1'
else BUF_L_out when sel_BUF = '1'
else local_out_la when pop = '1'
else addr_MUX;
RAM_addr_B <= local_out_ra when pop = '1'
else port_MUX_ra;

-- Left Buffer Register
BUF_L:RG
generic map (RAM_ADDR_SIZE)
port map (clk, BUF_L_rst, write_BUF_L, BUF_L_MUX, BUF_L_out);
BUF_L_rst <= sel_root or rst;
BUF_L_MUX <= local_out_la when pop = '1' else addr_MUX;

-- Right Buffer Register
BUF_R:RG
generic map (RAM_ADDR_SIZE)
port map (clk, rst, write_BUF_R, BUF_R_MUX, BUF_R_out);
BUF_R_MUX <= local_out_ra when pop = '1' else port_MUX_ra;

-- Right Buffer Register
BUF_D:RG
generic map (DATA_SIZE)
port map (clk, rst, write_BUF_D, BUF_D_MUX, BUF_D_out);
BUF_D_MUX <= data_in when write_data_in = '1'
else local_out_data when pop = '1'
else port_MUX_data;

-- RAM Counter
RAM_COUNTER:COUNTER
generic map (RAM_ADDR_SIZE)
port map (clk, rst, write_new_node, open, RAM_counter_zero, RAM_counter_out);

end DATAPATH_arch;