library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity RHFSM_SORT is
 generic (RHFSM_STACK_ADDR_SIZE: integer := 12;
          LOCAL_STACK_ADDR_SIZE: integer := 12;
          RHFSM_X_WIDTH: integer := 10;
			 RHFSM_Y_WIDTH: integer := 18;
			 DATA_SIZE: integer := 14;
          RAM_ADDR_SIZE: integer := 12);
    port (clk, rst: in STD_LOGIC;
	       dataflow: in STD_LOGIC;
	       data_in: in STD_LOGIC_VECTOR (DATA_SIZE-1 downto 0);
			 data_out: out STD_LOGIC_VECTOR (DATA_SIZE-1 downto 0);
			 ready, new_data, next_data: out STD_LOGIC);
end RHFSM_SORT;

architecture RHFSM_SORT_arch of RHFSM_SORT is

component RHFSM is
 generic (STACK_ADDR_SIZE: integer;
          X_WIDTH: integer;
			 Y_WIDTH: integer);
    port (clk, rst: in STD_LOGIC;
			 X: in STD_LOGIC_VECTOR (X_WIDTH downto 1);
			 Y: out STD_LOGIC_VECTOR (Y_WIDTH downto 1);
			 stack_upper_bound, stack_lower_bound: out STD_LOGIC);
end component;

component DATAPATH is
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
end component;

signal X: STD_LOGIC_VECTOR (RHFSM_X_WIDTH downto 1);
signal Y: STD_LOGIC_VECTOR (RHFSM_Y_WIDTH downto 1);

begin

CONTROL_UNIT:RHFSM
generic map (RHFSM_STACK_ADDR_SIZE, RHFSM_X_WIDTH, RHFSM_Y_WIDTH)
port map (clk, rst, X, Y, open, open);

DATAPATH_UNIT:DATAPATH
generic map (DATA_SIZE, RAM_ADDR_SIZE, LOCAL_STACK_ADDR_SIZE, RHFSM_X_WIDTH, RHFSM_Y_WIDTH)
port map (clk, rst, X, Y, data_in, data_out, dataflow, ready, new_data, next_data, open, open, open);

end RHFSM_SORT_arch;