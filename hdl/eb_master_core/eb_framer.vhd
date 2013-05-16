--! @file eb_record_gen.vhd
--! @brief Parses WB Operations and generates meta data for EB records 
--!
--! Copyright (C) 2013-2014 GSI Helmholtz Centre for Heavy Ion Research GmbH 
--!
--! Important details about its implementation
--! should go in these comments.
--!
--! @author Mathias Kreider <m.kreider@gsi.de>
--!
--------------------------------------------------------------------------------
--! This library is free software; you can redistribute it and/or
--! modify it under the terms of the GNU Lesser General Public
--! License as published by the Free Software Foundation; either
--! version 3 of the License, or (at your option) any later version.
--!
--! This library is distributed in the hope that it will be useful,
--! but WITHOUT ANY WARRANTY; without even the implied warranty of
--! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
--! Lesser General Public License for more details.
--!  
--! You should have received a copy of the GNU Lesser General Public
--! License along with this library. If not, see <http://www.gnu.org/licenses/>.
---------------------------------------------------------------------------------

--! Standard library
library IEEE;
--! Standard packages   
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.wishbone_pkg.all;
use work.eb_hdr_pkg.all;
use work.etherbone_pkg.all;

entity eb_framer is
  generic(g_mtu     : natural := 16);           -- Word count before a header creation is forced
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
end eb_framer;

architecture rtl of eb_framer is

--signals
signal op_fifo_q      : std_logic_vector(32 downto 0);
signal op_fifo_d      : std_logic_vector(32 downto 0);
signal op_fifo_push   : std_logic;
signal op_fifo_pop    : std_logic;
signal op_fifo_full   : std_logic;
signal op_fifo_empty  : std_logic;
signal dat            : std_logic_vector(c_wishbone_data_width-1 downto 0);
signal adr            : std_logic_vector(c_wishbone_address_width-1 downto 0);
signal we             : std_logic;
signal stb            : std_logic;
signal cyc            : std_logic;

signal r_wait_for_tx         : std_logic;
signal r_rec_ack         : std_logic;
signal r_stall        : std_logic;


signal adr_wr       : std_logic_vector(c_wishbone_address_width-1 downto 0);
signal adr_rd       : std_logic_vector(c_wishbone_address_width-1 downto 0);
signal rec_hdr      : t_rec_hdr;
signal rec_valid     : std_logic;
signal op_pop : std_logic;
signal r_first_rec : std_logic;
signal r_eb_hdr       : t_eb_hdr;

-- FSMs
type t_mux_state is (s_IDLE, s_EB, s_REC, s_WA, s_RA, s_WRITE, s_READ, s_DONE);
signal r_mux_state    : t_mux_state;
signal r_cnt_ops     : unsigned(8 downto 0);

component eb_record_gen is
  generic(g_mtu     : natural := 16);           -- Word count before a header creation is forced
  port(
     clk_i          : in  std_logic;            -- WB Clock
    rst_n_i         : in  std_logic;            -- async reset

    slave_i         : in  t_wishbone_slave_in;  -- WB op. -> not WB compliant, but the record format is practical
    slave_stall_o   : out std_logic;            -- flow control    
    
    
    rec_valid_o     : out std_logic;            -- latch signal for meta data
    rec_hdr_o       : out t_rec_hdr;            -- EB record header
		rec_adr_rd_o    : out std_logic_vector(c_wishbone_address_width-1 downto 0); -- EB write base address
		rec_adr_wr_o    : out std_logic_vector(c_wishbone_address_width-1 downto 0); -- EB read back address
    rec_ack_i           : in std_logic;             -- full flag from op fifo
   
    cfg_rec_hdr_i   : t_rec_hdr -- EB cfg information, eg read from cfg space etc
);   
end component;
 
component eb_fifo is
  generic(
    g_width : natural;
    g_size  : natural);
  port(
    clk_i     : in  std_logic;
    rstn_i    : in  std_logic;
    w_full_o  : out std_logic;
    w_push_i  : in  std_logic;
    w_dat_i   : in  std_logic_vector(g_width-1 downto 0);
    r_empty_o : out std_logic;
    r_pop_i   : in  std_logic;
    r_dat_o   : out std_logic_vector(g_width-1 downto 0));
end component;

begin
------------------------------------------------------------------------------
-- IO assignments
------------------------------------------------------------------------------
cyc <= slave_i.cyc;
stb <= slave_i.stb;
we <=  slave_i.we;
adr <= slave_i.adr;
dat <= slave_i.dat;

slave_stall_o <= r_stall;


rgen: eb_record_gen 
   GENERIC MAP(g_mtu => g_mtu)
   PORT MAP (
         
		  clk_i           => clk_i,
		  rst_n_i         => rst_n_i,

		  slave_i  			  => slave_i,
			slave_stall_o	  => r_stall,
      rec_ack_i       => r_rec_ack,
      
      rec_valid_o     => rec_valid,
      rec_hdr_o       => rec_hdr,
		  rec_adr_rd_o    => adr_rd, 
		  rec_adr_wr_o    => adr_wr,
		  
			cfg_rec_hdr_i		=> cfg_rec_hdr_i); 
 
------------------------------------------------------------------------------
-- fifos
------------------------------------------------------------------------------
op_fifo : eb_fifo
  generic map(
    g_width => 33,
    g_size  => g_mtu)
  port map (
    clk_i     => clk_i,
    rstn_i    => rst_n_i,
    w_full_o  => op_fifo_full,
    w_push_i  => op_fifo_push,
    w_dat_i   => op_fifo_d,
    r_empty_o => op_fifo_empty,
    r_pop_i   => op_fifo_pop,
    r_dat_o   => op_fifo_q);

op_fifo_pop   <= op_pop and not op_fifo_empty;
op_fifo_push  <= cyc and stb and not r_stall;
op_fifo_d(31 downto 0)     <= dat when we = '1'
            else adr;
            
op_fifo_d(32) <= tx_send_now_i; 

------------------------------------------------------------------------------
-- Output Mux
------------------------------------------------------------------------------
OMux : with r_mux_state select
tx_data_o <=  op_fifo_q(31 downto 0)  when s_WRITE | s_READ,
             f_format_rec(rec_hdr)    when s_REC,
             adr_wr                   when s_WA,
             adr_rd                   when s_RA, 
             f_format_eb(r_eb_hdr)    when s_EB,
             (others => '0')          when others;



  p_eb_mux : process (clk_i, rst_n_i) is
  variable v_state        : t_mux_state;
 
  begin
    if rst_n_i = '0' then
      r_mux_state <= s_IDLE;
      r_eb_hdr    <= c_eb_init;
      r_eb_hdr.no_response <= '0';
      r_first_rec  <= '1';
      r_wait_for_tx <= '0'; 
        
    elsif rising_edge(clk_i) then
      
      v_state     := r_mux_state;                    
      tx_en_o     <= '0';
      op_pop <= '0';
      r_rec_ack <= '0';
      
      if(op_fifo_q(32) = '1') then
        r_first_rec  <= '1';
      end if;
      

      
    case r_mux_state is
      when s_IDLE   =>  if((rec_valid or r_wait_for_tx)  = '1') then
                          if(tx_rdy_i = '1') then
                            if(r_first_rec = '1') then
                              r_first_rec  <= '0';
                              v_state    := s_EB;
                            else
                              v_state    := s_REC;
                            end if;
                          else
                            r_wait_for_tx <= '1';   
                          end if;
                        end if;
                        
      when s_EB     =>  v_state    := s_REC; -- output EB hdr                         
      
      when s_REC    =>  if(rec_hdr.wr_cnt + rec_hdr.rd_cnt /= 0) then -- output record hdr
                          if(rec_hdr.wr_cnt /= 0) then
                            v_state    := s_WA; 
                          else
                            v_state    := s_RA;
                          end if;
                        else
                          v_state    := s_DONE;
                        end if;
      
      when s_WA     =>  r_cnt_ops    <= '0' & rec_hdr.wr_cnt -2; -- output write base address
                        op_pop    <= '1';
                        v_state    := s_WRITE;               
      
      when s_WRITE  =>  if(r_cnt_ops(r_cnt_ops'left) = '1') then -- output write valuees
                          if(rec_hdr.rd_cnt /= 0) then
                            op_pop    <= '1';
                            v_state := s_RA;
                          else
                            v_state := s_DONE;
                          end if;
                        else
                          op_pop    <= '1';
                          r_cnt_ops <= r_cnt_ops-1;
                        end if;
      
      when s_RA     =>  r_cnt_ops    <= '0' & rec_hdr.rd_cnt -2; -- output readback address
                        op_pop    <= '1';
                        v_state    := s_READ;
      
      when s_READ   =>  if(r_cnt_ops(r_cnt_ops'left) = '1') then -- output read addresses
                          v_state := s_DONE;
                        else
                          op_pop    <= '1';
                          r_cnt_ops <= r_cnt_ops-1;
                        end if;
      
      when s_DONE   =>  v_state := s_IDLE;
      
      when others   =>  v_state := s_IDLE;
    end case;
    
      -- flags on state transition
    
      if((v_state /= s_IDLE) and (v_state /= s_DONE)) then
        tx_en_o    <= '1';
      end if;
      if(v_state = s_DONE) then
        r_rec_ack <= '1';
      end if;
                                        
      r_mux_state <= v_state;
    
    end if;
  end process;

end architecture;




