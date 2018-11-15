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
			 dataflow, start_sort: in STD_LOGIC;
			 idle, new_data, next_data: out STD_LOGIC;
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
			 addr_A: in STD_LOGIC_VECTOR (RAM_ADDR_SIZE-1 downto 0);
			 out_A: out STD_LOGIC_VECTOR (RAM_DATA_SIZE-1 downto 0));
end component;

subtype RAM_WORD is STD_LOGIC_VECTOR (DATA_SIZE+2*RAM_ADDR_SIZE-1 downto 0);
signal RAM_in, RAM_out_A: RAM_WORD;
signal RAM_W_en: STD_LOGIC;
signal RAM_addr_A: STD_LOGIC_VECTOR (RAM_ADDR_SIZE-1 downto 0);
signal RAM_in_data: STD_LOGIC_VECTOR (DATA_SIZE-1 downto 0);
signal RAM_in_la, RAM_in_ra: STD_LOGIC_VECTOR (RAM_ADDR_SIZE-1 downto 0);
SIGNAL RAM_out_A_data: STD_LOGIC_VECTOR (DATA_SIZE-1 downto 0);
signal RAM_out_A_la, RAM_out_A_ra: STD_LOGIC_VECTOR (RAM_ADDR_SIZE-1 downto 0);

component BR_STACK_NEG is
 generic (STACK_ADDR_SIZE: integer;
          DATA_SIZE: integer);
	 port (clk, rst: in STD_LOGIC;
	       inc, dec: in STD_LOGIC;
	       data_in: in STD_LOGIC_VECTOR (DATA_SIZE-1 downto 0);
			 data_out: out STD_LOGIC_VECTOR (DATA_SIZE-1 downto 0);
			 upper_bound, lower_bound: out STD_LOGIC);
end component;

signal local_out: STD_LOGIC_VECTOR (RAM_ADDR_SIZE-1 downto 0);

component RG is
 generic (RG_WIDTH: integer);
    port (clk, rst: in STD_LOGIC;
	       RG_en: in STD_LOGIC;
	       RG_in: in STD_LOGIC_VECTOR (RG_WIDTH-1 downto 0);
			 RG_out: out STD_LOGIC_VECTOR (RG_WIDTH-1 downto 0));
end component;

signal BUF_L_rst: STD_LOGIC;
signal BUF_L_out: STD_LOGIC_VECTOR (RAM_ADDR_SIZE-1 downto 0);
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
signal left_zero, right_zero: STD_LOGIC;
signal enable_RAM_A, enable_out: STD_LOGIC;
signal write_new_node, write_left_address, write_right_address: STD_LOGIC;
signal write_BUF_L, write_BUF_D: STD_LOGIC;
signal sel_address, sel_root, sel_BUF: STD_LOGIC;
signal push, pop: STD_LOGIC;

signal addr_MUX: STD_LOGIC_VECTOR (RAM_ADDR_SIZE-1 downto 0);

begin

-- Mapping of Primary Inputs
X(1) <= dataflow;
X(2) <= root;
X(3) <= same;
X(4) <= smaller;
x(5) <= left_zero;
X(6) <= right_zero;
X(7) <= start_sort;

-- Mapping of Primary Outputs
idle <= Y(1);
enable_RAM_A <= Y(2);
write_BUF_L <= Y(3);
write_BUF_D <= Y(4);
enable_out <= Y(5);
write_new_node <= Y(6);
write_left_address <= Y(7);
write_right_address <= Y(8);
next_data <= Y(9);
sel_address <= Y(10);
sel_root <= Y(11);
sel_BUF <= Y(12);
push <= Y(13);
pop <= Y(14);

-- Mapping of RAM Inputs
RAM_in(DATA_SIZE+2*RAM_ADDR_SIZE-1 downto 2*RAM_ADDR_SIZE) <= RAM_in_data;
RAM_in(2*RAM_ADDR_SIZE-1 downto RAM_ADDR_SIZE) <= RAM_in_la;
RAM_in(RAM_ADDR_SIZE-1 downto 0) <= RAM_in_ra;
-- Mapping of RAM Outputs
RAM_out_A_data <= RAM_out_A(DATA_SIZE+2*RAM_ADDR_SIZE-1 downto 2*RAM_ADDR_SIZE);
RAM_out_A_la <= RAM_out_A(2*RAM_ADDR_SIZE-1 downto RAM_ADDR_SIZE);
RAM_out_A_ra <= RAM_out_A(RAM_ADDR_SIZE-1 downto 0);

-- Address MUX
addr_MUX <= RAM_out_A_ra when sel_address = '1' else RAM_out_A_la;

-- Data Output
data_out <= RAM_out_A_data when enable_out = '1' else (others => '0');
new_data <= enable_out;

-- Conditional Signals
left_zero <= '1' when RAM_out_A_la = ZERO else '0';
right_zero <= '1' when RAM_out_A_ra = ZERO else '0';
root <= RAM_counter_zero;
same <= '1' when BUF_D_out = RAM_out_A_data else '0';
smaller <= '1' when BUF_D_out < RAM_out_A_data else '0';

-- Local Stack
LOCAL:BR_STACK_NEG
generic map (LOCAL_ADDR_SIZE, RAM_ADDR_SIZE)
port map (clk, rst, push, pop, BUF_L_out, local_out, open, open);         

-- Data RAM
DATA_RAM:RAM
generic map (DATA_SIZE+2*RAM_ADDR_SIZE, RAM_ADDR_SIZE)
port map (clk, enable_RAM_A, RAM_W_en, RAM_in, RAM_addr_A, RAM_out_A);
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
else BUF_L_out when sel_BUF = '1'
else local_out when pop = '1'
else addr_MUX;

-- Left Buffer Register
BUF_L:RG
generic map (RAM_ADDR_SIZE)
port map (clk, BUF_L_rst, write_BUF_L, addr_MUX, BUF_L_out);
BUF_L_rst <= sel_root or rst;

-- Data Buffer Register
BUF_D:RG
generic map (DATA_SIZE)
port map (clk, rst, write_BUF_D, data_in, BUF_D_out);

-- RAM Counter
RAM_COUNTER:COUNTER
generic map (RAM_ADDR_SIZE)
port map (clk, rst, write_new_node, open, RAM_counter_zero, RAM_counter_out);

end DATAPATH_arch;