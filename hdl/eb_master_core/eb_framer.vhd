entity eb_framer is
	generic(g_adr_hi_bits : natural)
  port(
    clk_i     : in  std_logic;
    rst_n_i   : in  std_logic;

    slave_i  			: in  t_wishbone_slave_in;
		slave_stall_o	: out std_logic;

		cfg_rec_hdr_i		: std_logic_vector(c_wishbone_data_width-1 downto 0);
		cfg_offset_i		: in std_logic_vector(g_adr_hi_bits-1 downto 0);	
		cfg_rdb_adr_i		: in std_logic_vector(c_wishbone_address_width-1 downto c_wishbone_address_width-g_adr_hi_bits);
		cfg_mtu_i				: in natural;


		stream_dat_o  : out std_logic_vector(c_wishbone_data_width-1 downto 0);
		stream_stb_o	: out std_logic;
		stream_stl_i  : in  std_logic;

end eb_framer;

architecture rtl of eb_framer is

function cp_rec_hdr(src t_rec_hdr)
		return t_rec_hdr is
	variable ret : t_rec_hdr := c_rec_init;
begin
	ret.bca_cfg 	:= '1';	
	ret.drop_cyc 	:= src.drop_cyc;			
	ret.rca_cfg 	:= src.rca_cfg;
	ret.rd_fifo 	:= src.rd_fifo;
	ret.wca_cfg 	:= src.wca_cfg;
	return ret;
end;

function is_inc(std_logic_vector A, std_logic_vector B)
	return boolean;
variable ret : boolean;
begin
	if(unsigned(A) = unsigned(B) + 4) then
		ret := true;
	else
		ret := false;
	end if;
	return ret;   
end; 

function eq(std_logic_vector A, std_logic_vector B)
	return boolean;
variable ret : boolean;
begin
	if(A = B) then
		ret := true;
	else
		ret := false;
	end if;
	return ret;   
end; 

--signals
signal push_in  : std_logic;
signal push_out : std_logic;

-- FIFO connectors
signal adrdat_fifo_q : std_logic_vector(c_wishbone_data_width-1 downto 0);
signal adrdat_fifo_d : std_logic_vector(c_wishbone_address_width-1 downto 0);
signal adrdat_fifo_push_in : std_logic;
signal adrdat_fifo_pop : std_logic;
signal adrdat_fifo_clr : std_logic;



--registers
signal r_stall 		: std_logic;
signal r_cyc 			: std_logic;
signal r_we 			: std_logic;	
signal r_adr 			: std_logic_vector(c_wishbone_address_width-1 downto 0);
signal r_dat 			: std_logic_vector(c_wishbone_data_width-1 downto 0);
signal r_sel 			: std_logic_vector(c_wishbone_data_width/8-1 downto 0);
signal r_adr_wr		: std_logic_vector(c_wishbone_address_width-1 downto 0);
signal r_adr_rd		: std_logic_vector(c_wishbone_address_width-1 downto 0);
signal r_adr_chg	: std_logic;
signal r_rec_hdr	: t_rec_hdr;
signal r_eb_hdr		: t_eb_hdr;

--- main fsm & Source selector MUX -----------------------------------------------
type t_mux_state is (S_NOP, S_PAD, S_EB_HDR, S_R_HDR, S_WADR, S_WRITE, S_RADR, S_READ);
type t_hdr_state is (s_START, s_WRITE, s_READ, s_OUPUT);
signal r_hdr_state : t_hdr_state;


begin

	push <= slave_i.cyc and slave_i.stb and not r_stall;

	--- ADR/DAT FIFO and MUX ---------------------------------------------------------
	with slave_i.we select
	adrdat_fifo_d	<= 	slave_i.dat when '1',
										slave_i.adr when others; 	

	adrdat_fifo_push_in 	<= push;
	adrdat_fifo_pop <= 	'1' when (state = S_WRITE) or (state = S_READ);
											'0' when others;
	adrdat_fifo_clr		<= (not slave_i.cyc and trn_done);
	----------------------------------------------------------------------------------



	TX_MUX: with state select
		stream_dat_o <= adrdat_fifo_q 	when S_WRITE | S_READ,
										r_eb_hdr				when S_EB_HDR,
										r_r_hdr					when S_R_HDR, 			
										r_wadr					when S_RADR,	
										r_radr					when S_WADR,
									(others => '0')	when others;
		stream_stb_o <= '0';
	----------------------------------------------------------------------------------



	process p_register_io(clk_i, rst_n_i)
	begin
		if rst_n_i = '0' then
		elsif rising_edge(clk_i) then
			r_cyc <= slave_i.cyc;
			r_push <= push;
			r_we 	<= slave_i.we;	
			r_dat <= slave_i.dat;
			r_sel	<= slave_i.sel;	
			r_adr	<= unsigned(slave_i.adr);
		end if;
	end;

	

	process p_cnt(clk_i, rst_n_i)
	begin
		if rst_n_i = '0' then
			r_wr_cnt <= (others => '0');
			r_rd_cnt <= (others => '0');
		elsif rising_edge(clk_i) then
			if(r_push_hdr = '1') then
				r_wr_cnt <= (others => '0');
				r_rd_cnt <= (others => '0');
			else
				--if a new entry is inserted into adr_dat fifo, inc rd & wr counters accordingly
				if(push = '1') then
					r_wr_cnt <= wr_cnt + unsigned(slave_i.we);
					r_rd_cnt <= rd_cnt + unsigned(not slave_i.we);
				end if;
			end if;	
		end if;	
	end; 

	process p_eb_rec_hdr_gen(clk_i, rst_n_i)
	variable v_rec_hdr 						: t_rec_hdr;
	variable v_cyc_falling				: boolean;
	variable v_cyc_rising					: boolean;
	variable v_mtu_reached				: boolean;
	variable v_state							: t_hdr_state;
			
	begin
		if rst_n_i = '0' then
			r_hdr_state	<= t_hdr_state;	
			r_rec_hdr 	<= c_rec_init;
			r_hdr_push	<= '0';
			r_adr_rd 		<= (others => '0');
			r_adr_wr 		<= (others => '0');
			r_mode 	 		<= UNKNOWN;
		elsif rising_edge(clk_i) then
		
			v_cyc_falling			:= (r_cyc = '1' and slave_i.cyc = '0');
			v_cyc_rising			:= (r_cyc = '0' and slave_i.cyc = '1'); 
			v_rec_hdr 				:= r_rec_hdr;
			v_rec_hdr.wr_cnt 	:= r_wr_cnt;	
			v_rec_hdr.rd_cnt 	:= r_rd_cnt;
			v_mtu_reached			:= (v_rec_hdr.wr_cnt + v_rec_hdr.rd_cnt >= cfg_mtu_i);			
			v_state 					:= r_hdr_state;										
			r_stall 					<= '0';

			case r_state is
				when s_START	=>	if(v_cyc_rising or r_push_hdr = '1'	) then
														--copy information from cycle cfg	
														v_rec_hdr 		:= cp_rec_hdr(cfg_rec_hdr_i);
														v_rec_hdr.sel := slave_i.sel; 
														r_adr_rd <= cfg_offset_i & slave_i.dat(c_wishbone_data_width-g_adr_hi_bits-1); 
														r_adr_wr <= cfg_offset_i & slave_i.adr(c_wishbone_address_width-g_adr_hi_bits-1);
														r_mode 	 <= UNKNOWN; 
													end if;

													if(push = '1') then
														if( slave_i.we = '1') then 
															v_state := s_WRITE;
														else
															v_state := s_READ;
														end if;	
													end if;
		 

				when s_WRITE	=>	if(push = '1') then
														if(slave_i.we = '0') then
															v_state := s_READ;
														else															
															--determine wr address mode															
															if(r_mode = UNKNOWN) then
																if(eq(slave_i.adr, r_adr)) then
																	r_mode <= WR_FIFO;		
																elsif(is_inc(slave_i.adr, r_adr)) then
																	r_mode <= WR_NORM;						
																else
																	r_mode <= WR_NORM;
																	v_rec_hdr.wr_fifo := '0';																
																	v_state := s_OUTP;
																end if;					 
															else
																-- output state if mode is not kept
																if((r_mode = WR_FIFO and not eq(slave_i.adr, r_adr))
																		r_mode = WR_NORM and not is_inc(slave_i.adr, r_adr))
																		v_cyc_falling	or v_mtu_reached ) then
																		v_state := s_OUTP;
																else
																	-- stay in write state
																	v_state := <= s_WRITE; 														
																end if;															
															end if;
														end if;
													end if;
			
				when s_READ		=>	if(push = '1') then
														--determine wr address mode															
														if(r_mode = UNKNOWN) then
															if(eq(slave_i.dat, r_dat)) then
																r_mode <= RD_FIFO;		
															elsif(is_inc(slave_i.dat, r_dat)) then
																r_mode <= RD_NORM;						
															else
																r_mode <= RD_NORM;
																v_state := s_OUTP;
															end if;					 
														else
															-- output state if mode is not kept
															if((r_mode = RD_FIFO and not eq(slave_i.dat, r_dat))
																	r_mode = RD_NORM and not is_inc(slave_i.dat, r_dat))
																	v_cyc_falling	or v_mtu_reached or slave_i.we = '1' ) then
																	v_state := s_OUTP;
															else
																-- stay in write state
																v_state := s_READ; 														
															end if;															
														end if;
													end if;

				when s_OUTP		=>	v_state := s_START;	
				when others		=>	v_state := s_START;
			end case;
		
			-- flags to occur on state transition
			if(v_state /= r_state) then
				r_stall <= '1';
			end if;
			if(v_state = s_OUTP) then
				r_push_hdr <= '1';
			end if;
																				
			r_rec_hdr <= v_rec_hdr;		
			r_state <= v_state;
		
		end if;
	end process;

end architecture;




