library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.wishbone_pkg.all;
use work.eb_hdr_pkg.all;

-- entity declaration for your testbench.Dont declare any ports here
ENTITY test_tb IS
END test_tb;

ARCHITECTURE behavior OF test_tb IS

 
  
  
  

component eb_framer is
  generic(g_mtu         : natural := 16);
  port(
    clk_i           : in  std_logic;            -- WB Clock
    rst_n_i         : in  std_logic;            -- async reset

    slave_i         : in  t_wishbone_slave_in;  -- WB op. -> not WB compliant, but the record format is practical
    slave_stall_o   : out std_logic;            -- flow control    
    
    tx_data_o       : out std_logic_vector(c_wishbone_data_width-1 downto 0);
    tx_en_o         : out std_logic;
    tx_rdy_i        : in std_logic;
    tx_send_now_i   : in std_logic;
    
    cfg_rec_hdr_i   : t_rec_hdr -- EB cfg information, eg read from cfg space etc
);   
   end component;


   constant c_dummy_slave_in : t_wishbone_slave_in :=
    ('0', '0', x"00000000", x"F", '0', x"00000000");
   constant c_dummy_master_out : t_wishbone_master_out := c_dummy_slave_in;

   --declare inputs and initialize them
  signal clk 						: std_logic := '0';
	signal rst_n 					: std_logic := '0';
	signal master_o				: t_wishbone_master_out;
	signal slave_stall 		: std_logic;
	signal cfg_rec_hdr  	: t_rec_hdr;
	signal cfg_mtu			  :  natural;
  signal count : natural;

  signal data           : std_logic_vector(c_wishbone_data_width-1 downto 0);
	signal en	            : std_logic;
	signal eop	            : std_logic;
	
   -- Clock period definitions
   constant clk_period : time := 8 ns;
BEGIN
    -- Instantiate the Unit Under Test (UUT)
   uut: eb_framer 
   GENERIC MAP(g_mtu => 32)
   PORT MAP (
         
		  clk_i           => clk,
		  rst_n_i         => rst_n,

		  slave_i  			  => master_o,
			slave_stall_o	  => slave_stall,

      tx_data_o       => data,
      tx_en_o         => en,
		  tx_rdy_i        => '1',
      tx_send_now_i   => eop,
    
			cfg_rec_hdr_i		=> cfg_rec_hdr);      

   -- Clock process definitions( clock with 50% duty cycle is generated here.
   clk_process :process
   begin
        clk <= '0';
        wait for clk_period/2;  --for 0.5 ns signal is '0'.
        clk <= '1';
        wait for clk_period/2;  --for next 0.5 ns signal is '1'.
   end process;
   
   
   -- Stimulus process
  stim_proc: process
  
   procedure wb_send_test( hold : in std_logic;
                          ops : in natural;
                          offs : in unsigned(31 downto 0);
                          adr_inc : in natural;
                          we : in std_logic; 
                          send : in std_logic
                    ) is
  
  variable I : natural := 0;
  
  begin
    
    wait until rising_edge(clk);
    master_o.cyc <= '1';
    wait for clk_period;    
    for I in 0 to ops-1 loop
      master_o.stb  <= '1';
      master_o.we   <= we; 
      master_o.adr  <= std_logic_vector(offs + to_unsigned(I*adr_inc, 32));
      master_o.dat  <= x"DEAD" & std_logic_vector(to_unsigned(I*adr_inc, 16));
      wait for clk_period; 
      if(I = ops -1) then
        eop <= send;
      else
        eop <= '0';
      end if;
      while slave_stall = '1'loop
        wait for clk_period; 
      end loop;
        
    end loop;
    master_o.stb <= '0';
    master_o.cyc <= '0' or hold;  
    wait for clk_period;    
  end procedure wb_send_test;
  
   begin        
        rst_n <= '0';
         
        master_o			<= c_dummy_master_out;
	      master_o.sel <= x"f";
	      
	      cfg_rec_hdr  	<= c_rec_init;
	      
        wait for clk_period*2;
        rst_n <= '1';
        wait until rising_edge(clk);  

        wb_send_test('1', 3, x"A0000000", 4, '1', '0');  -- 3 wr                    
        
        wb_send_test('0', 1, x"A0000000", 4, '1', '1');  -- 1 wr 
        
        wb_send_test('1', 5, x"A0000000", 4, '1', '0');  -- 1 wr 
        wb_send_test('0', 1, x"F0000000", 4, '0', '0');  -- 1 rd
        
         wb_send_test('1', 1, x"A0000000", 4, '1', '0');  -- 1 wr 
        wb_send_test('0', 1, x"F0000000", 4, '0', '1');  -- 1 rd
        
         wb_send_test('1', 1, x"A0000000", 4, '1', '0');  -- 1 wr 
        wb_send_test('0', 1, x"F0000000", 4, '0', '1');  -- 1 rd
        
        wb_send_test('1', 10, x"F0000000", 0, '0', '0');  -- 10 rd
        wb_send_test('0', 10, x"F0000000", 4, '0', '1');  -- 10 rd
        wb_send_test('1', 1, x"F0000010", 0, '0', '0');  -- 1 rd
        wb_send_test('1', 1, x"F0000020", 0, '0', '0');  -- 1 rd
        wb_send_test('1', 1, x"F0000030", 0, '0', '0');  -- 1 rd
        wb_send_test('0', 1, x"F0000040", 0, '0', '1');  -- 1 rd
         
        wait;
  end process;

END;
