library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity RHFSM_SORT is
 generic (RHFSM_STACK_ADDR_SIZE: integer:=10;
          LOCAL_STACK_ADDR_SIZE: integer:=10;
          RHFSM_MAIN_X_WIDTH: integer:=8;
			 RHFSM_MAIN_Y_WIDTH: integer:=17;
			 RHFSM_SEC_X_WIDTH: integer:=3;
			 RHFSM_SEC_Y_WIDTH: integer:=9;
			 DATA_SIZE: integer:=14;
          RAM_ADDR_SIZE: integer:=11);
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

signal XM: STD_LOGIC_VECTOR (RHFSM_MAIN_X_WIDTH downto 1);
signal YM: STD_LOGIC_VECTOR (RHFSM_MAIN_Y_WIDTH downto 1);

component RHFSM_SEC is
 generic (STACK_ADDR_SIZE: integer;
          X_WIDTH: integer;
			 Y_WIDTH: integer);
    port (clk, rst: in STD_LOGIC;
			 X: in STD_LOGIC_VECTOR (X_WIDTH downto 1);
			 Y: out STD_LOGIC_VECTOR (Y_WIDTH downto 1);
			 stack_upper_bound, stack_lower_bound: out STD_LOGIC);
end component;

signal XS: STD_LOGIC_VECTOR (RHFSM_SEC_X_WIDTH downto 1);
signal YS: STD_LOGIC_VECTOR (RHFSM_SEC_Y_WIDTH downto 1);

component DATAPATH is
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
end component;

begin

MAIN_CONTROL_UNIT:RHFSM
generic map (RHFSM_STACK_ADDR_SIZE, RHFSM_MAIN_X_WIDTH, RHFSM_MAIN_Y_WIDTH)
port map (clk, rst, XM, YM, open, open);

SECONDARY_CONTROL_UNIT:RHFSM_SEC
generic map (RHFSM_STACK_ADDR_SIZE, RHFSM_SEC_X_WIDTH, RHFSM_SEC_Y_WIDTH)
port map (clk, rst, XS, YS, open, open);

DATAPATH_UNIT:DATAPATH
generic map (DATA_SIZE, RAM_ADDR_SIZE, LOCAL_STACK_ADDR_SIZE, RHFSM_MAIN_X_WIDTH, RHFSM_MAIN_Y_WIDTH, RHFSM_SEC_X_WIDTH, RHFSM_SEC_Y_WIDTH)
port map (clk, rst, XM, YM, XS, YS, data_in, data_out, dataflow, ready, new_data, next_data);

end RHFSM_SORT_arch;