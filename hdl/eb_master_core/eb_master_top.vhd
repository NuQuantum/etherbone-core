entity eb_framer is
  port(
    clk_i     : in  std_logic;
    rst_n_i   : in  std_logic;

    src_i     : in  t_wrf_src_in;									-- interface to NIC mux
    src_o    	: out t_wrf_src_out;

		wr_adr_i	: in std_logic_vector(c_wishbone_data_width-1 downto 0);		
		rd_adr_i	: in std_logic_vector(c_wishbone_data_width-1 downto 0);
		mtu_i			: natural;

    bridge_slave_o		: out t_wishbone_slave_out;	-- bridge interface
    bridge_slave_i  	: in  t_wishbone_slave_in

end eb_framer;

architecture rtl of eb__framer is

--signals
signal push : std_logic;

-- FIFO connectors
signal adrdat_fifo_q : std_logic_vector(c_wishbone_data_width-1 downto 0);
signal adrdat_fifo_d : std_logic_vector(c_wishbone_address_width-1 downto 0);
signal adrdat_fifo_push : std_logic;
signal adrdat_fifo_pop : std_logic;
signal adrdat_fifo_clr : std_logic;



--registers
signal r_bridge_slave : t_wishbone_slave_in;
signal r_stall 		: std_logic;
signal r_last_cyc : std_logic;
signal r_last_we 	: std_logic;	
signal r_last_adr : std_logic_vector(c_wishbone_address_width-1 downto 0);
signal r_adr_chg	: std_logic;
signal r_rec_hdr 	: t_rec_hdr;
signal r_eb_hdr		: t_eb_hdr;

--- main fsm & Source selector MUX -----------------------------------------------
type t_state is (S_NOP, S_PAD, S_EB_HDR, S_R_HDR, S_WADR, S_WRITE, S_RADR, S_READ);
signal r_state : t_state;



push <= bridge_slave_i.cyc and bridge_slave_i.stb and not r_stall;

process p_wb_ack(clk_i)
begin
	if rising_edge(clk_i) then
		bridge_slave_o.ack	<= push;
	end if;			 
end;


--- ADR/DAT FIFO and MUX ---------------------------------------------------------
with bridge_slave_i.we select
adrdat_fifo_d	<= 	bridge_slave_i.dat when '1',
									bridge_slave_i.adr when others; 	

adrdat_fifo_push 	<= push;
adrdat_fifo_pop <= 	'1' when (state = S_WRITE) or (state = S_READ);
										'0' when others;
adrdat_fifo_clr		<= (not bridge_slave_i.cyc and trn_done);
----------------------------------------------------------------------------------



TX_MUX: with state select
	tx_fifo_d <= 	adrdat_fifo_q 	when S_WRITE | S_READ,
								r_eb_hdr				when S_EB_HDR,
								r_r_hdr					when S_R_HDR, 			
								r_wadr					when S_RADR,	
								r_radr					when S_WADR,
								(others => '0')	when others;
	
--tx_fifo_push 		<=  '1' when (state /= S_WRITE) or (state = S_READ);
--										'0' when others;
----------------------------------------------------------------------------------



process p_register_io(clk_i, rst_n_i)
begin
	if rst_n_i = '0' then
		r_wr_adr_chg	<= '0';
	elsif rising_edge(clk_i) then
		r_last_cyc 	<= bridge_slave_i.cyc;
		r_last_we 	<= bridge_slave_i.we;	
		r_last_dat  <= bridge_slave_i.dat;	 	
		r_last_adr	<= unsigned(bridge_slave_i.adr);
		r_wr_adr_chg	<= (r_wr_adr_chg or (slave_i.we = '1' and (unsigned(slave_i.adr) /= (r_last_adr)))) and (slave_i.cyc and not r_push_hdr);
	end if;
end;




process p_wb_cfg(clk_i, rst_n_i)
--latch meta data from config register
begein

	if rst_n_i = '0' then
	elsif rising_edge(clk_i) then

		if(cfg_push = '1') then
		
end if;

-- memory mapped wb if stuff
--- direct wb if stuff
	if(r_last_cyc = '0' and slave_i.cyc = '1') then
		cfg_rec_hdr.sel 		<=  bridge_slave_i.sel;
	end if; 


--end if;


function cp_rec_hdr(src t_rec_hdr)
		return t_rec_hdr is
	variable ret : t_rec_hdr := c_rec_init;
begin
	ret.bca_cfg 	:= '1';	
	ret.wr_fifo  	:= src.wr_fifo;			
	ret.drop_cyc 	:= src.drop_cyc;			
	ret.rca_cfg 	:= src.rca_cfg;
	ret.rd_fifo 	:= src.rd_fifo;
	ret.wca_cfg 	:= src.wca_cfg;
	return ret;
end;

adr_cfg <= '1' when bridge_slave_i.adr(

process p_eb_rec_hdr_gen(clk_i, rst_n_i)
variable v_rec_hdr 						: t_rec_hdr;
variable v_write_discontious 	: boolean;
variable v_write_read_switch 	: boolean;
variable v_cyc_falling				: boolean;
variable v_mtu_reached				: boolean;
variable v_wr_adr_chg					: boolean;

begin
	if rst_n_i = '0' then
		r_rec_hdr 				<= c_rec_init;
		r_hdr_push 				<= '0';

	elsif rising_edge(clk_i) then
		--we dont't parse anything if this an access to the config space 		
		if(adr_cfg = '0') then 		
			v_write_discontious := (slave_i.we = '1' and (unsigned(bridge_slave_i.adr) /= (r_last_adr + (c_data_width/8)))) ;
			v_write_read_switch := (r_last_we = '0' and bridge_slave_i.we = '1');
			v_mtu_reached				:= (rec_hdr.wr_cnt + rec_hdr.rd_cnt >= r_MTU);
			v_cyc_falling				:= (r_last_cyc = '1' and bridge_slave_i.cyc = '0');
			v_cyc_rising				:= (r_last_cyc = '1' and bridge_slave_i.cyc = '0');  
			v_wr_adr_chg				:= r_wr_adr_chg = '1' or (bridge_slave_i.we = '1' and (unsigned(bridge_slave_i.adr) /= r_last_adr));
			v_sel_chg						:= r_last_sel /= bridge_slave_i.sel;

			r_hdr_push 					<= '0';
	
			if(v_cyc_rising or r_push_hdr = '1'	) then
				--copy information from cycle cfg			
				v_rec_hdr := cp_rec_hdr(cfg_rec_hdr);
			else		
				v_rec_hdr := cp_rec_hdr(r_rec_hdr);	
			end if;
		
			v_rec_hdr.wr_fifo  := to_std_logic(not v_wr_adr_chg);	
			
			--create a new hdr if ...
			if(	v_cyc_falling or v_write_read_switch or v_mtu_reached 
			 or send_now_i = '1' or (v_write_discontious and v_wr_adr_chg)
			 or v_sel_chg	) then 
				r_push_hdr 				<= '1';			
			end if;
		
			--if a new entry is inserted into adr_dat fifo, inc rd & wr counters accordingly
			if(push = '1') then
				wr_cnt <= wr_cnt + unsigned(slave_i.we);
				rd_cnt <= rd_cnt + unsigned(not slave_i.we);
			end if; 
			
			v_rec_hdr.wr_cnt := v_rec_hdr.wr_cnt + r_wr_cnt;	
			v_rec_hdr.rd_cnt := v_rec_hdr.rd_cnt + r_rd_cnt;	
			r_rec_hdr <= v_rec_hdr; 
		end if;
	end if;
end 




