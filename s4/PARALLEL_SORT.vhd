library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity PARALLEL_SORT is
 generic (NUMBER_OF_SORT_UNITS: integer := 2; -- Minimum 2
          RHFSM_STACK_ADDR_SIZE: integer := 10;
          LOCAL_STACK_ADDR_SIZE: integer := 10;
          RHFSM_X_WIDTH: integer := 7;
			 RHFSM_Y_WIDTH: integer := 14;
			 DATA_SIZE: integer := 14;
          RAM_ADDR_SIZE: integer := 10);
    port (clk, rst: in STD_LOGIC;
	       dataflow: in STD_LOGIC;
	       data_in: in STD_LOGIC_VECTOR (DATA_SIZE-1 downto 0);
			 data_out: out STD_LOGIC_VECTOR (DATA_SIZE-1 downto 0);
			 ready, new_data, next_data: out STD_LOGIC);
end PARALLEL_SORT;

architecture PARALLEL_SORT_arch of PARALLEL_SORT is

component RHFSM_SORT is
 generic (RHFSM_STACK_ADDR_SIZE: integer;
          LOCAL_STACK_ADDR_SIZE: integer;
          RHFSM_X_WIDTH: integer;
			 RHFSM_Y_WIDTH: integer;
			 DATA_SIZE: integer;
          RAM_ADDR_SIZE: integer);
    port (clk, rst: in STD_LOGIC;
	       dataflow, start_sort: in STD_LOGIC;
	       data_in: in STD_LOGIC_VECTOR (DATA_SIZE-1 downto 0);
			 data_out: out STD_LOGIC_VECTOR (DATA_SIZE-1 downto 0);
			 idle, new_data, next_data: out STD_LOGIC);
end component;

signal sorter_idle, sorter_new_data, sorter_next_data: STD_LOGIC_VECTOR (NUMBER_OF_SORT_UNITS-1 downto 0);
type PARALLEL_SORT_OUT is array (0 to NUMBER_OF_SORT_UNITS-1) of STD_LOGIC_VECTOR (DATA_SIZE-1 downto 0);
signal sorter_out: PARALLEL_SORT_OUT;

component RG is
 generic (RG_WIDTH: integer);
    port (clk, rst: in STD_LOGIC;
	       RG_en: in STD_LOGIC;
	       RG_in: in STD_LOGIC_VECTOR (RG_WIDTH-1 downto 0);
			 RG_out: out STD_LOGIC_VECTOR (RG_WIDTH-1 downto 0));
end component;

signal sorter_data_rst: STD_LOGIC;
signal sorter_data_en: STD_LOGIC_VECTOR (NUMBER_OF_SORT_UNITS-1 downto 0);
signal enable_buf: STD_LOGIC_VECTOR (NUMBER_OF_SORT_UNITS-1 downto 0);
type PARALLEL_DATA_RG_OUT is array (0 to NUMBER_OF_SORT_UNITS-1) of STD_LOGIC_VECTOR (DATA_SIZE-1 downto 0); 
signal sorter_data_rg_out: PARALLEL_DATA_RG_OUT;
signal ram_data_buf_out: PARALLEL_DATA_RG_OUT;
signal output_data_buf_out: STD_LOGIC_VECTOR (DATA_SIZE-1 downto 0);

component FF is
  port (clk, rst: in STD_LOGIC;
	     FF_en: in STD_LOGIC;
	     FF_in: in STD_LOGIC;
		  FF_out: out STD_LOGIC);
end component;

signal sorter_busy_in: STD_LOGIC; 
signal sorter_busy_rst, sorter_busy, sorter_ready: STD_LOGIC_VECTOR (NUMBER_OF_SORT_UNITS-1 downto 0);
signal sorter_ram_empty_buf: STD_LOGIC_VECTOR (NUMBER_OF_SORT_UNITS-1 downto 0);
--signal sorter_ram_comparable_buf: STD_LOGIC_VECTOR (NUMBER_OF_SORT_UNITS-1 downto 0);
signal enable_out_buf: STD_LOGIC;

component RAM_DUAL is
 generic (RAM_DATA_SIZE: integer;
          RAM_ADDR_SIZE: integer);
    port (clk: in STD_LOGIC;
	       en_A, W_en_A: in STD_LOGIC;
			 input: in STD_LOGIC_VECTOR (RAM_DATA_SIZE-1 downto 0);
			 addr_A, addr_B: in STD_LOGIC_VECTOR (RAM_ADDR_SIZE-1 downto 0);
--			 out_A, out_B: out STD_LOGIC_VECTOR (RAM_DATA_SIZE-1 downto 0));
			 out_B: out STD_LOGIC_VECTOR (RAM_DATA_SIZE-1 downto 0));
end component;

signal sorter_ram_comparable: STD_LOGIC_VECTOR (NUMBER_OF_SORT_UNITS-1 downto 0) := (others => '0');
signal sorter_ram_empty: STD_LOGIC_VECTOR (NUMBER_OF_SORT_UNITS-1 downto 0) := (others => '0');
type PARALLEL_RAM_OUT is array (0 to NUMBER_OF_SORT_UNITS-1) of STD_LOGIC_VECTOR (DATA_SIZE-1 downto 0);
signal sorter_ram_out, sorter_ram_out_mux: PARALLEL_RAM_OUT;
type PARALLEL_RAM_ADDR is array (0 to NUMBER_OF_SORT_UNITS-1) of STD_LOGIC_VECTOR (RAM_ADDR_SIZE-1 downto 0);
signal sorter_ram_addr_A, sorter_ram_addr_B: PARALLEL_RAM_ADDR;

component COUNTER is
 generic (COUNTER_WIDTH: integer);
    port (clk, rst: in STD_LOGIC;
	       counter_en: in STD_LOGIC;
			 full, zero: out STD_LOGIC;
			 counter_out: out STD_LOGIC_VECTOR (COUNTER_WIDTH-1 downto 0));
end component;

signal counter_rst: STD_LOGIC;
signal write_counter_greater, read_counter_en: STD_LOGIC_VECTOR (NUMBER_OF_SORT_UNITS-1 downto 0) := (others => '0');
signal write_counter_zero, read_counter_zero: STD_LOGIC_VECTOR (NUMBER_OF_SORT_UNITS-1 downto 0) := (others => '0');

type STATE_TYPE is (a0, a1, a2, a3, a4, a5, a6, a7);
signal current_state, next_state: STATE_TYPE;
signal sorter_addr: integer range 0 to NUMBER_OF_SORT_UNITS-1;
signal sorter_addr_en: STD_LOGIC;

signal X: STD_LOGIC_VECTOR (4 downto 1);
signal Y: STD_LOGIC_VECTOR (5 downto 1);

signal none_busy, all_empty, all_comparable: STD_LOGIC;
signal sorter_rst: STD_LOGIC;
signal start_sort: STD_LOGIC;
signal enable_sort, enable_out: STD_LOGIC;

signal ram_mux: STD_LOGIC_VECTOR (DATA_SIZE-1 downto 0);

-- NUMBER_OF_SORT_UNITS := 2
signal ram_out_greater, ram_out_equal: STD_LOGIC;

-- NUMBER_OF_SORT_UNITS > 2
--signal ram_out_greater, ram_out_equal: STD_LOGIC_VECTOR (NUMBER_OF_SORT_UNITS-2 downto 0);

-- NUMBER_OF_SORT_UNITS := 3
--signal temp_mux_0: STD_LOGIC_VECTOR (DATA_SIZE-1 downto 0);

-- NUMBER_OF_SORT_UNITS := 4
--signal temp_mux_0, temp_mux_1: STD_LOGIC_VECTOR (DATA_SIZE-1 downto 0);

signal enable_shift_rg_en, enable_shift_rg_sel: STD_LOGIC;
signal enable_shift_rg: STD_LOGIC_VECTOR (NUMBER_OF_SORT_UNITS-1 downto 0);

begin

-- Outputs
new_data <= enable_out_buf;
next_data <= sorter_addr_en;
data_out <= output_data_buf_out when enable_out_buf = '1' else (others => '0');

-- Output Data Buffer
OUTPUT_DATA_BUF:RG
generic map (DATA_SIZE)
port map (clk, rst, enable_out, ram_mux, output_data_buf_out);

-- New Data Buffer
NEW_DATA_BUF:FF
port map (clk, rst, enable_sort, enable_out, enable_out_buf);

-- Mapping of Primary Inputs
X(1) <= dataflow;
X(2) <= sorter_busy(sorter_addr);
X(3) <= none_busy;
X(4) <= all_empty;

-- Mapping of Primary Outputs
ready <= Y(1);
sorter_rst <= Y(2);
sorter_addr_en <= Y(3);
enable_shift_rg_en <= Y(3);
enable_shift_rg_sel <= Y(3);
sorter_busy_in <= Y(3);
start_sort <= Y(4);
enable_sort <= Y(5);

-- Conditional Signals (NUMBER_OF_SORT_UNITS := 2)
none_busy <= sorter_ready(1) and sorter_ready(0);
all_empty <= sorter_ram_empty_buf(1) and sorter_ram_empty_buf(0);
all_comparable <= sorter_ram_comparable(1) and sorter_ram_comparable(0);
enable_out <= (not all_empty) and all_comparable;

-- Conditional Signals (NUMBER_OF_SORT_UNITS := 3)
--none_busy <= sorter_ready(2) and sorter_ready(1) and sorter_ready(0);
--all_empty <= sorter_ram_empty_buf(2) and sorter_ram_empty_buf(1) and sorter_ram_empty_buf(0);
--all_comparable <= sorter_ram_comparable(2) and sorter_ram_comparable(1) and sorter_ram_comparable(0);
--enable_out <= (not all_empty) and all_comparable;

-- Conditional Signals (NUMBER_OF_SORT_UNITS := 4)
--none_busy <= sorter_ready(3) and sorter_ready(2) and sorter_ready(1) and sorter_ready(0);
--all_empty <= sorter_ram_empty_buf(3) and sorter_ram_empty_buf(2) and sorter_ram_empty_buf(1) and sorter_ram_empty_buf(0);
--all_comparable <= sorter_ram_comparable(3) and sorter_ram_comparable(2) and sorter_ram_comparable(1) and sorter_ram_comparable(0);
--enable_out <= (not all_empty) and all_comparable;

-- Sorter Address Counter
process (rst, clk)
begin

if rst = '1' then
  sorter_addr <= 0;
elsif clk'event and clk = '1' then
  if sorter_addr_en = '1' then
    if sorter_addr = NUMBER_OF_SORT_UNITS-1 then
      sorter_addr <= 0;
	 else
	   sorter_addr <= sorter_addr + 1;
	 end if;
  end if;
end if;

end process;

-- Enable Shift Register
process (rst, sorter_rst, clk)
variable temp: bit_vector (NUMBER_OF_SORT_UNITS-1 downto 0);
begin

if rst = '1' or sorter_rst = '1' then
  enable_shift_rg <= conv_std_logic_vector(1,NUMBER_OF_SORT_UNITS);
elsif clk'event and clk = '1' then
  if enable_shift_rg_en = '1' then
    temp := to_bitvector(enable_shift_rg);
	 temp := temp rol 1;
    enable_shift_rg <= to_stdlogicvector(temp);
  end if;
end if;

end process;

process (current_state, X)
begin

Y <= (others => '0');
next_state <= current_state;

case current_state is

  when a0  => next_state <= a1;				-- Begin (Initialization)
  				  Y(2) <= '1';
  when a1  => if X(1) = '1' then				-- Idle
                if X(2) = '1' then
					   next_state <= a2;
					 else
					   next_state <= a3;
					 end if;
				  elsif X(3) = '1' then
				    next_state <= a5;
				  else
				    next_state <= a4;
				  end if;
  when a2  => if X(2) = '1' then				-- Wait for N-th Sorter
					 next_state <= a2;
				  else
					 next_state <= a3;
				  end if;
  when a3  => next_state <= a1;				-- Write to N-th Data Register
				  Y(3) <= '1';
  when a4  => if X(3) = '1' then				-- Wait for All Sorters to Become Idle
				    next_state <= a5;
				  else
				    next_state <= a4;
				  end if;
  when a5  => next_state <= a6;				-- Start Sorting
              Y(4) <= '1';
  when a6  => if X(4) = '1' then				-- Wait for All RAMs to Become Empty
                next_state <= a7;
				  else
				    next_state <= a6;
				  end if;
				  Y(5) <= '1';
  when a7  => Y(1) <= '1';						-- End
						  
end case;

end process;

process (rst, clk)
begin

if rst = '1' then
  current_state <= a0;
elsif clk'event and clk = '1' then
  current_state <= next_state;
end if;

end process;

-- NUMBER_OF_SORT_UNITS := 2
-- Multiplexed Data Output
ram_mux <= ram_data_buf_out(1) when ram_out_greater = '1' else ram_data_buf_out(0);
-- Comparator Output
ram_out_greater <= '1' when ram_data_buf_out(0) > ram_data_buf_out(1) else '0';
ram_out_equal <= '1' when ram_data_buf_out(1) = ram_data_buf_out(0) else '0';	
-- Stack Pop Control
read_counter_en(1) <= enable_out and (not sorter_ram_empty_buf(1)) and (ram_out_greater or ram_out_equal);
read_counter_en(0) <= enable_out and (not sorter_ram_empty_buf(0)) and (not ram_out_greater);

-- NUMBER_OF_SORT_UNITS := 3
---- Multiplexed Data Output
--ram_mux <= ram_data_buf_out(2) when ram_out_greater(1) = '1' else temp_mux_0;
--temp_mux_0 <= ram_data_buf_out(1) when ram_out_greater(0) = '1' else ram_data_buf_out(0);
---- Comparator Output
--ram_out_greater(1) <= '1' when temp_mux_0 > ram_data_buf_out(2) else '0';
--ram_out_greater(0) <= '1' when ram_data_buf_out(0) > ram_data_buf_out(1) else '0';
--ram_out_equal(1) <= '1' when ram_data_buf_out(2) = temp_mux_0 else '0';
--ram_out_equal(0) <= '1' when ram_data_buf_out(1) = ram_data_buf_out(0) else '0';	
---- Stack Pop Control
--read_counter_en(2) <= enable_out and (not sorter_ram_empty_buf(2)) and (ram_out_greater(1) or ram_out_equal(1));
--read_counter_en(1) <= enable_out and (not sorter_ram_empty_buf(1)) and (((not ram_out_greater(1)) and ram_out_greater(0)) or ram_out_equal(0));
--read_counter_en(0) <= enable_out and (not sorter_ram_empty_buf(0)) and (ram_out_greater(1) nor ram_out_greater(0));

-- NUMBER_OF_SORT_UNITS := 4, parallel
---- Multiplexed Data Output
--ram_mux <= temp_mux_1 when ram_out_greater(2) = '1' else temp_mux_0;
--temp_mux_0 <= ram_data_buf_out(1) when ram_out_greater(0) = '1' else ram_data_buf_out(0);
--temp_mux_1 <= ram_data_buf_out(3) when ram_out_greater(1) = '1' else ram_data_buf_out(2);
---- Comarator Output
--ram_out_greater(2) <= '1' when temp_mux_0 > temp_mux_1 else '0';
--ram_out_greater(1) <= '1' when ram_data_buf_out(2) > ram_data_buf_out(3) else '0';
--ram_out_greater(0) <= '1' when ram_data_buf_out(0) > ram_data_buf_out(1) else '0';
--ram_out_equal(2) <= '1' when temp_mux_1 = temp_mux_0 else '0';
--ram_out_equal(1) <= '1' when ram_data_buf_out(3) = ram_data_buf_out(2) else '0';
--ram_out_equal(0) <= '1' when ram_data_buf_out(1) = ram_data_buf_out(0) else '0';	
---- Stack Pop Control
--read_counter_en(3) <= enable_out and (not sorter_ram_empty_buf(3)) and (ram_out_equal(1) or (ram_out_greater(1) and (ram_out_equal(2) or ram_out_greater(2))));
--read_counter_en(2) <= enable_out and (not sorter_ram_empty_buf(2)) and ((not ram_out_greater(1)) and (ram_out_equal(2) or ram_out_greater(2)));
--read_counter_en(1) <= enable_out and (not sorter_ram_empty_buf(1)) and (((not ram_out_greater(2)) and ram_out_greater(0)) or ram_out_equal(0));
--read_counter_en(0) <= enable_out and (not sorter_ram_empty_buf(0)) and (ram_out_greater(2) nor ram_out_greater(0));

-- NUMBER_OF_SORT_UNITS := 4, cascade
---- Multiplexed Data Output
--ram_mux <= ram_data_buf_out(3) when ram_out_greater(2) = '1' else temp_mux_1;
--temp_mux_1 <= ram_data_buf_out(2) when ram_out_greater(1) = '1' else temp_mux_0;
--temp_mux_0 <= ram_data_buf_out(1) when ram_out_greater(0) = '1' else ram_data_buf_out(0);
---- Comarator Output
--ram_out_greater(2) <= '1' when temp_mux_1 > ram_data_buf_out(3) else '0';
--ram_out_greater(1) <= '1' when temp_mux_0 > ram_data_buf_out(2) else '0';
--ram_out_greater(0) <= '1' when ram_data_buf_out(0) > ram_data_buf_out(1) else '0';
--ram_out_equal(2) <= '1' when ram_data_buf_out(3) = temp_mux_1 else '0';
--ram_out_equal(1) <= '1' when ram_data_buf_out(2) = temp_mux_0 else '0';
--ram_out_equal(0) <= '1' when ram_data_buf_out(1) = ram_data_buf_out(0) else '0';
---- Stack Pop Control
--read_counter_en(3) <= enable_out and (not sorter_ram_empty_buf(3)) and (ram_out_greater(2) or ram_out_equal(2));
--read_counter_en(2) <= enable_out and (not sorter_ram_empty_buf(2)) and (((not ram_out_greater(2)) and ram_out_greater(1)) or ram_out_equal(1));
--read_counter_en(1) <= enable_out and (not sorter_ram_empty_buf(1)) and (((not ram_out_greater(2)) and (not ram_out_greater(1)) and ram_out_greater(0)) or ram_out_equal(0));
--read_counter_en(0) <= enable_out and (not sorter_ram_empty_buf(0)) and (not (ram_out_greater(2) or ram_out_greater(1) or ram_out_greater(0)));

-- Data Register Enable Control
sorter_data_en <= enable_shift_rg when enable_shift_rg_sel = '1' else (others => '0');

SORT_UNITS:
for i in 0 to NUMBER_OF_SORT_UNITS-1 generate
begin

SORTERS:RHFSM_SORT
generic map (RHFSM_STACK_ADDR_SIZE, LOCAL_STACK_ADDR_SIZE, RHFSM_X_WIDTH, RHFSM_Y_WIDTH, DATA_SIZE, RAM_ADDR_SIZE)
port map (clk, rst, sorter_busy(i), start_sort, sorter_data_rg_out(i), sorter_out(i), sorter_idle(i), sorter_new_data(i), sorter_next_data(i));

SORTER_RAM:RAM_DUAL
generic map (DATA_SIZE, RAM_ADDR_SIZE)
port map (clk, enable_sort, sorter_new_data(i), sorter_out(i), sorter_ram_addr_A(i), sorter_ram_addr_B(i), sorter_ram_out(i));
sorter_ram_out_mux(i) <= sorter_ram_out(i) when sorter_ram_empty(i) = '0' else (others => '1');
sorter_ram_empty(i) <= sorter_idle(i) and (not write_counter_greater(i));
sorter_ram_comparable(i) <= (not read_counter_zero(i)) and enable_sort and (sorter_idle(i) or write_counter_greater(i));

RAM_DATA_BUF:RG
generic map (DATA_SIZE)
port map (clk, rst, enable_buf(i), sorter_ram_out_mux(i), ram_data_buf_out(i));
enable_buf(i) <= (read_counter_zero(i) and (not write_counter_zero(i))) or read_counter_en(i);

RAM_EMPTY_BUF:FF
port map (clk, rst, enable_buf(i), sorter_ram_empty(i), sorter_ram_empty_buf(i));

--RAM_COMPARABLE_BUF:FF
--port map (clk, rst, enable_sort, sorter_ram_comparable(i), sorter_ram_comparable_buf(i));

WRITE_COUNTER:COUNTER
generic map (RAM_ADDR_SIZE)
port map (clk, counter_rst, sorter_new_data(i), open, write_counter_zero(i), sorter_ram_addr_A(i));
write_counter_greater(i) <= '1' when sorter_ram_addr_A(i) > sorter_ram_addr_B(i) else '0';

READ_COUNTER:COUNTER
generic map (RAM_ADDR_SIZE)
port map (clk, counter_rst, enable_buf(i), open, read_counter_zero(i), sorter_ram_addr_B(i));
counter_rst <= rst or sorter_rst;

SORTER_DATA_RGS:RG
generic map (DATA_SIZE)
port map (clk, sorter_data_rst, sorter_data_en(i), data_in, sorter_data_rg_out(i));
sorter_data_rst <= rst or sorter_rst;

SORTER_BUSY_FFS:FF
port map (clk, sorter_busy_rst(i), sorter_data_en(i), sorter_busy_in, sorter_busy(i));
sorter_busy_rst(i) <= rst or sorter_rst or sorter_next_data(i);
sorter_ready(i) <= (not sorter_busy(i)) and sorter_idle(i);

end generate;

end PARALLEL_SORT_arch;