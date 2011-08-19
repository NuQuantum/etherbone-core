--! Standard library
library IEEE;
--! Standard packages    
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.EB_HDR_PKG.all;
use work.wb32_package.all;
use work.wb16_package.all;

use work.vhdl_2008_workaround_pkg.all;


entity TB_EB5 is 
end TB_EB5;

architecture behavioral of TB_EB5 is



component wb_test 
generic(g_cnt_width : natural := 32);	-- MAX WIDTH 32
 port(
		clk_i    		: in    std_logic;                                        --clock
        nRST_i   		: in   	std_logic;
		
		wb_slave_o     : out   wb32_slave_out;	--! Wishbone master output lines
		wb_slave_i     : in    wb32_slave_in
    );

end component;

component packet_capture is
generic(filename : string := "123.pcap";  wordsize : natural := 32);
port(
	clk_i    		: in    std_logic;                                        --clock
    nRST_i   		: in   	std_logic;

	TOL_i		: in 	std_logic_vector(15 downto 0);
	rdy_o		: out std_logic;
	start_i		: in   	std_logic;
	packet_start_i		: in   	std_logic;
	valid_i			: in   	std_logic;
	data_i			: in	std_logic_vector(wordsize-1 downto 0)
);	
end component;

component EB_CORE is
generic(g_master_slave : natural := 1);
port
(
	clk_i           	: in    std_logic;   --! clock input
	nRst_i				: in 	std_logic;
	
	-- slave RX streaming IF -------------------------------------
	slave_RX_CYC_i		: in 	std_logic;						--
	slave_RX_STB_i		: in 	std_logic;						--
	slave_RX_DAT_i		: in 	std_logic_vector(15 downto 0);	--	
	slave_RX_WE_i		: in 	std_logic;	
	slave_RX_STALL_o	: out 	std_logic;						--						
	slave_RX_ERR_o		: out 	std_logic;						--
	slave_RX_ACK_o		: out 	std_logic;						--
	--------------------------------------------------------------
	
	-- master TX streaming IF ------------------------------------
	master_TX_CYC_o		: out 	std_logic;						--
	master_TX_STB_o		: out 	std_logic;						--
	master_TX_WE_o		: out 	std_logic;	
	master_TX_DAT_o		: out 	std_logic_vector(15 downto 0);	--	
	master_TX_STALL_i	: in 	std_logic;						--						
	master_TX_ERR_i		: in 	std_logic;						--
	master_TX_ACK_i		: in 	std_logic;						--
	--------------------------------------------------------------
	debug_TX_TOL_o			: out std_logic_vector(15 downto 0);
	
	-- master IC IF ----------------------------------------------
	master_IC_i			: in	wb32_master_in;
	master_IC_o			: out	wb32_master_out
	--------------------------------------------------------------
	
);

end component;




























signal s_clk_i : std_logic := '0';
signal s_nRST_i : std_logic := '0';
signal nRST_i : std_logic := '0';

signal stop_the_clock : std_logic := '0';
signal firstrun : boolean := true;
constant clock_period: time := 8 ns;

	--Eth MAC WB Streaming signals
signal s_byte_count_i			: unsigned(15 downto 0);
signal s_byte_count_o			: unsigned(15 downto 0);
	



 --x4 because it's bytes
signal TOL		: std_logic_vector(15 downto 0);

signal RX_EB_HDR : EB_HDR;
signal RX_EB_CYC : EB_CYC;

signal s_oc_a : std_logic;
signal s_oc_an : std_logic;
signal s_oc_b : std_logic;
signal s_oc_bn : std_logic;

type FSM is (INIT, INIT_DONE, PACKET_HDR, CYCLE_HDR, RD_BASE_ADR, RD, WR_BASE_ADR, WR, CYC_DONE, PACKET_DONE, DONE);
signal state : FSM := INIT;	

signal stall : std_logic := '0';
signal end_sim : std_logic := '1';
signal capture : std_logic := '1';

signal pcap_in_wren : std_logic := '0';
signal pcap_out_wren : std_logic := '0';

signal s_signal_out : std_logic_vector(31 downto 0);

signal rdy : std_logic;
signal request : std_logic;
signal stalled: std_logic;
signal strobe: std_logic;
signal strobed: std_logic;
signal start : std_logic;
signal packet_start : std_logic;
signal start_test : std_logic := '0';


signal gen_strobe: std_logic;
signal gen_start : std_logic;
signal gen_packet_start : std_logic;
signal gen_rdy : std_logic;

signal pack_tmp : std_logic_vector(15 downto 0);











	--Eth MAC WB Streaming signals
signal s_slave_RX_stream_i		: wb32_slave_in;
signal s_slave_RX_stream_o		: wb32_slave_out;
signal s_master_TX_stream_i		: wb16_master_in;
signal s_master_TX_stream_o		: wb16_master_out;

constant WBM_Zero_o		: wb16_master_out := 	(CYC => '0',
												STB => '0',
												ADR => (others => '0'),
												SEL => (others => '0'),
												WE  => '0',
												DAT => (others => '0'));
												
constant WBS_Zero_o		: wb16_slave_out := 	(ACK   => '0',
												ERR   => '0',
												RTY   => '0',
												STALL => '0',
												DAT   => (others => '0'));

signal s_ebm_tx_i		: wb16_master_in;
signal s_ebm_tx_o		: wb16_master_out;
signal s_ebm_rx_i		: wb16_slave_in;
signal s_ebm_rx_o		: wb16_slave_out;

signal s_ebs_tx_i		: wb16_master_in;
signal s_ebs_tx_o		: wb16_master_out;
signal s_ebs_rx_i		: wb16_slave_in;
signal s_ebs_rx_o		: wb16_slave_out;

	
	--WB IC signals
signal s_master_IC_i			: wb32_master_in;
signal s_master_IC_o			: wb32_master_out;

signal s_wb_slave_o				: wb32_slave_out;
signal s_wb_slave_i				: wb32_slave_in;


signal RST  : std_logic;
signal bytecount : natural := 0;

signal max_buffersize : natural := 0;

signal divider : std_logic := '0';

constant WBS32_Zero_o		: wb32_slave_out := 	(ACK   => '0',
												ERR   => '0',
												RTY   => '0',
												STALL => '0',
												DAT   => (others => '0'));


begin




master: EB_CORE 	generic map(1)
port map ( clk_i             => s_clk_i,
	  nRst_i            => s_nRst_i,
	  slave_RX_CYC_i    => s_ebm_rx_i.CYC,
	  slave_RX_STB_i    => s_ebm_rx_i.STB,
	  slave_RX_DAT_i    => s_ebm_rx_i.DAT,
	  slave_RX_WE_i    => s_ebm_rx_i.WE,
	  slave_RX_STALL_o  => s_ebm_rx_o.STALL,
	  slave_RX_ERR_o    => s_ebm_rx_o.ERR,
	  slave_RX_ACK_o    => s_ebm_rx_o.ACK,
	  master_TX_CYC_o   => s_ebm_tx_o.CYC,
	  master_TX_STB_o   => s_ebm_tx_o.STB,
	  master_TX_DAT_o   => s_ebm_tx_o.DAT,
	  master_TX_WE_o   =>  s_ebm_tx_o.WE,
	  master_TX_STALL_i => s_ebm_tx_i.STALL,
	  master_TX_ERR_i   => s_ebm_tx_i.ERR,
	  master_TX_ACK_i   => s_ebm_tx_i.ACK,
	  debug_TX_TOL_o	=> TOL,
	  master_IC_i       => WBS32_Zero_o,
	  master_IC_o       => open );

slave: EB_CORE 	generic map(0)
port map ( clk_i             => s_clk_i,
	  nRst_i            => s_nRst_i,
	  slave_RX_CYC_i    => s_ebs_rx_i.CYC,
	  slave_RX_STB_i    => s_ebs_rx_i.STB,
	  slave_RX_DAT_i    => s_ebs_rx_i.DAT,
	  slave_RX_WE_i    	=> s_ebs_rx_i.WE,
	  slave_RX_STALL_o  => s_ebs_rx_o.STALL,
	  slave_RX_ERR_o    => s_ebs_rx_o.ERR,
	  slave_RX_ACK_o    => s_ebs_rx_o.ACK,
	  master_TX_CYC_o   => s_ebs_tx_o.CYC,
	  master_TX_STB_o   => s_ebs_tx_o.STB,
	  master_TX_DAT_o   => s_ebs_tx_o.DAT,
	  master_TX_WE_o   	=> s_ebs_tx_o.WE,
	  master_TX_STALL_i => s_ebs_tx_i.STALL,
	  master_TX_ERR_i   => s_ebs_tx_i.ERR,
	  master_TX_ACK_i   => s_ebs_tx_i.ACK,
	  debug_TX_TOL_o	=> TOL,
	  master_IC_i       => s_master_IC_i,
	  master_IC_o       => s_master_IC_o );

 
s_ebm_tx_i	<=	s_ebs_rx_o;
s_ebm_rx_i	<=	s_ebs_tx_o;
s_ebs_tx_i	<=	s_ebm_rx_o;
s_ebs_rx_i	<=	s_ebm_tx_o;
 

WB_DEV : wb_test
generic map(g_cnt_width => 32) 
port map(
		clk_i	=> s_clk_i,
		nRst_i	=> s_nRst_i,
		
		wb_slave_o     	=> s_wb_slave_o,	
		wb_slave_i     	=> s_wb_slave_i

    );


	s_master_IC_i <= wb32_master_in(s_wb_slave_o);
	s_wb_slave_i <= wb32_slave_in(s_master_IC_o);



	
-- pcapin : packet_capture
-- generic map(filename => "eb_input.pcap", wordsize => 16) 
-- port map(
	-- clk_i				=> s_clk_i,
	-- nRst_i				=> s_nRst_i,
-- rdy_o => rdy1,
	-- TOL_i				=> TOL,
	-- start_i 			=> RST,
	-- packet_start_i		=> s_ebcore_i.CYC,
	-- valid_i				=> pcap_in_wren,
	-- data_i				=> s_ebcore_i.DAT
-- );

	-- pcap_in_wren <= (s_ebcore_i.STB AND (NOT s_ebcore_o.STALL));

-- pcapout : packet_capture
-- generic map(filename => "eb_output.pcap",  wordsize => 16) 
-- port map(
	-- clk_i	=> s_clk_i,
	-- nRst_i	=> s_nRst_i,
	-- rdy_o => rdy2,
	-- TOL_i	=> TOL,
	-- start_i => RST,
	-- packet_start_i		=> s_master_TX_stream_o.CYC,
	-- valid_i			=> pcap_out_wren,
	-- data_i			=> s_master_TX_stream_o.DAT
-- );		

-- pcap_out_wren <= (s_master_TX_stream_o.STB AND (NOT s_master_TX_stream_i.STALL));

-- clocked : process(s_clk_i)
-- begin
-- if (s_clk_i'event and s_clk_i = '1') then
		-- if(nRSt_i = '0') then
		-- else
			-- divider <= NOT divider;
			-- if(s_master_TX_stream_o.STB = '1') then
				-- bytecount <= bytecount + 2;
			-- end if;	
			-- stalled <=  s_ebcore_o.STALL;
			-- if(strobed = '0') then  
				-- strobed <= strobe AND NOT s_ebcore_o.STALL;
			-- else
				-- strobed <= NOT request	;
			-- end if;	
		-- end if;	
	-- end if;
-- end process;

--s_master_TX_stream_i.STALL <= '0';--divider;



-- Jam : process
 
	-- begin 
		-- if(start_test = '1') then
			-- s_master_TX_stream_i.STALL <= '1';
			-- wait for clock_period;
			-- s_master_TX_stream_i.STALL <= '0';
			-- wait for clock_period;
		 
		-- end if;
	  
-- end process Jam;




    clkGen : process
    variable dead : integer := 50;
	
	begin 
      while 1=1 loop
         s_clk_i <= '0', '1' after clock_period / 2;
         wait for clock_period;
		 --divider
		 if(stop_the_clock = '1') then
			
			dead := dead -1;
		 end if;
		 if dead = 0 then
			end_sim <= '0';
	
			report "simulation end" severity failure;
		 end if;
      end loop;
	  
	  end_sim <= '0';
	  wait for clock_period * 5;
	  report "simulation end" severity failure;
    end process clkGen;

	
		
	   simu : process
    

    
    begin

		wait until rising_edge(s_clk_i);

		s_nRst_i <= '0';
		wait for clock_period;
		s_nRst_i <= '1';

		wait for 1000*clock_period;
		
		
		
		stop_the_clock <= '1';
		wait for 48*clock_period; 
		
		wait;
	end process simu ;
	


end architecture behavioral;   


