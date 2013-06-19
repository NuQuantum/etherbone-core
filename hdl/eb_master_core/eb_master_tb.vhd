library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.wishbone_pkg.all;
use work.eb_hdr_pkg.all;
use work.eb_internals_pkg.all;
use work.wr_fabric_pkg.all;

-- entity declaration for your testbench.Dont declare any ports here
ENTITY test_tb IS
END test_tb;

ARCHITECTURE behavior OF test_tb IS




   constant c_dummy_slave_in : t_wishbone_slave_in :=
    ('0', '0', x"00000000", x"F", '0', x"00000000");
   constant c_dummy_slave_out : t_wishbone_slave_out :=
    ('0', '0', '0', '0', '0', x"00000000"); 
   constant c_dummy_master_out : t_wishbone_master_out := c_dummy_slave_in;

   --declare inputs and initialize them
  signal clk 						: std_logic := '0';
	signal rst_n 					: std_logic := '0';
	signal master_o				: t_wishbone_master_out;
	signal master_i				: t_wishbone_master_in;
	
	signal src_i          : t_wrf_source_in;
  signal src_o          : t_wrf_source_out;
	
	signal slave_stall 		: std_logic;
	signal cfg_rec_hdr  	: t_rec_hdr;
	signal cfg_mtu			  :  natural;
  signal count : natural;

  signal data           : std_logic_vector(c_wishbone_data_width-1 downto 0);
	signal en	            : std_logic;
	signal eop	            : std_logic;
	
	
constant c_RESET        : unsigned(31 downto 0) := x"00000000";
constant c_FLUSH        : unsigned(31 downto 0) := c_RESET        +4; --wo    04
constant c_STATUS       : unsigned(31 downto 0) := c_FLUSH        +4; --rw    08
constant c_SRC_MAC_HI   : unsigned(31 downto 0) := c_STATUS       +4; --rw    0C
constant c_SRC_MAC_LO   : unsigned(31 downto 0) := c_SRC_MAC_HI   +4; --rw    10 
constant c_SRC_IPV4     : unsigned(31 downto 0) := c_SRC_MAC_LO   +4; --rw    14 
constant c_SRC_UDP_PORT : unsigned(31 downto 0) := c_SRC_IPV4     +4; --rw    18
constant c_DST_MAC_HI   : unsigned(31 downto 0) := c_SRC_UDP_PORT +4; --rw    1C
constant c_DST_MAC_LO   : unsigned(31 downto 0) := c_DST_MAC_HI   +4; --rw    20
constant c_DST_IPV4     : unsigned(31 downto 0) := c_DST_MAC_LO   +4; --rw    24
constant c_DST_UDP_PORT : unsigned(31 downto 0) := c_DST_IPV4     +4; --rw    28
constant c_PAC_LEN      : unsigned(31 downto 0) := c_DST_UDP_PORT +4; --rw    2C
constant c_OPA_HI       : unsigned(31 downto 0) := c_PAC_LEN      +4; --rw    30
constant c_OPS_MAX      : unsigned(31 downto 0) := c_OPA_HI       +4; --rw    34
constant c_WOA_BASE     : unsigned(31 downto 0) := c_OPS_MAX      +4; --ro    38
constant c_ROA_BASE     : unsigned(31 downto 0) := c_WOA_BASE     +4; --ro    3C
constant c_EB_OPT       : unsigned(31 downto 0) := c_ROA_BASE     +4; --rw    40

constant c_adr_hi_bits : natural := 13;


	
   -- Clock period definitions
   constant clk_period : time := 8 ns;
BEGIN


uut: eb_master_top 
   GENERIC MAP(g_adr_bits_hi => c_adr_hi_bits,
               g_mtu => 32)
   PORT MAP (
         
		  clk_i           => clk,
		  rst_n_i         => rst_n,

		  slave_i  			  => master_o,
			slave_o         =>  master_i,
     
      src_o           => src_o,
      src_i           => src_i
			);    

slave_stall <= master_i.stall;


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
  
  
   procedure wb_wr( adr : in unsigned(31 downto 0);
                    dat : in std_logic_vector(31 downto 0)
                  ) is
  begin
    
    wait until rising_edge(clk);
    master_o.cyc <= '1';
    master_o.stb  <= '1';
    master_o.we   <= '1';
    master_o.adr  <= std_logic_vector(adr);
    master_o.dat  <= dat;
    wait for clk_period; 
    while slave_stall = '1'loop
      wait for clk_period; 
    end loop;
    master_o.stb <= '0';
    master_o.cyc <= '0';  
    wait for clk_period;    
  end procedure wb_wr;
  
  
   procedure wb_send_test( hold : in std_logic;
                          ops : in natural;
                          offs : in unsigned(31 downto 0);
                          adr_inc : in natural;
                          we : in std_logic; 
                          send : in std_logic
                    ) is
  
  variable I : natural := 0;
  variable tadr : unsigned(31 downto 0) := (others => '0');
  
  begin
    
    wait until rising_edge(clk);
    master_o.cyc <= '1';
    wait for clk_period;    
    for I in 0 to ops-1 loop
      master_o.stb  <= '1';
      master_o.we   <= '1'; 
      tadr(32-c_adr_hi_bits+1) := '1';
      tadr(32-c_adr_hi_bits) := we;
      master_o.adr  <= std_logic_vector(offs + tadr + to_unsigned(I*adr_inc, 32));
      master_o.dat  <= x"DEAD" & std_logic_vector(to_unsigned(I*adr_inc, 16));
      
      wait for clk_period; 
      
      while slave_stall = '1'loop
        wait for clk_period; 
      end loop;
        
    end loop;
    
    if(hold = '1') then
      master_o.cyc <= '1';
      master_o.stb <= '0';  
    else
      master_o.stb  <= '1';
      master_o.we   <= '1';
      tadr(32-c_adr_hi_bits+1) := '0'; 
      master_o.adr  <= std_logic_vector(tadr + c_FLUSH);
      master_o.dat  <= x"00000001";
      wait for clk_period; 
      while slave_stall = '1'loop
        wait for clk_period; 
      end loop;
      master_o.cyc <= '0';
      master_o.stb <= '0'; 
    end if;
    wait for clk_period;    
  end procedure wb_send_test;
  
   begin        
        rst_n <= '0';
        eop <= '0';
        src_i <= c_dummy_src_in;
        master_o			<= c_dummy_master_out;
	      master_o.sel <= x"f";
	      
	      cfg_rec_hdr  	<= c_rec_init;
	      
        wait for clk_period*2;
        rst_n <= '1';
        wait until rising_edge(clk);  

        wb_wr(c_SRC_MAC_HI,   x"D15EA5ED");
        wb_wr(c_SRC_MAC_LO,   x"BEEF0000");
        wb_wr(c_SRC_IPV4,     x"CAFEBABE");
        wb_wr(c_SRC_UDP_PORT, x"0000EBD0");
        wb_wr(c_DST_MAC_HI,   x"11223344");
        wb_wr(c_DST_MAC_LO,   x"55660000");
        wb_wr(c_DST_IPV4,     x"C0A80064");
        wb_wr(c_DST_UDP_PORT, x"0000EBD1");
        wb_wr(c_OPS_MAX,      x"00000010");
        wb_wr(c_PAC_LEN,      x"00000050");
        wb_wr(c_OPA_HI,       x"00000000");
        wb_wr(c_EB_OPT,       x"00000000");

        --          hold  ops   offs  adr_inc we  send
        wb_send_test('0', 1, x"00200000", 4, '0', '1');  -- 3 wr                    

        wb_send_test('0', 1, x"00200000", 4, '1', '1');  -- 3 wr   

        --wb_send_test('0', 1, x"00000000", 4, '0', '1');  -- 1 rd 
        
        --wb_send_test('1', 5, x"00000000", 4, '1', '0');  -- 1 wr 
        --wb_send_test('0', 1, x"00001100", 4, '0', '0');  -- 1 rd
        
        --wb_send_test('1', 1, x"00000000", 4, '1', '0');  -- 1 wr 
        --wb_send_test('0', 1, x"00001000", 4, '0', '1');  -- 1 rd
        
        --wb_send_test('1', 1, x"00001000", 4, '1', '0');  -- 1 wr 
        ---wb_send_test('0', 2, x"00001000", 4, '0', '0');  -- 1 rd
        
        --wb_send_test('1', 10, x"00000000", 0, '0', '0');  -- 10 rd
        --wb_send_test('0', 10, x"00000000", 4, '0', '0');  -- 10 rd
        --wb_send_test('1', 1, x"00000010", 0, '0', '0');  -- 1 rd
        ---wb_send_test('1', 1, x"00000020", 0, '0', '0');  -- 1 rd
        --wb_send_test('1', 1, x"00000030", 0, '0', '0');  -- 1 rd
        --wb_send_test('0', 1, x"00000040", 0, '0', '1');  -- 1 rd
         
        wait;
  end process;

END;
