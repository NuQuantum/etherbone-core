--! @file eb_framer.vhd
--! @brief Produces EB content from WB operations
--!        
--!
--! Copyright (C) 2013-2014 GSI Helmholtz Centre for Heavy Ion Research GmbH 
--!
--! Muxes adress / data lines and inserts meta data generated by eb_record_gen
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
use work.eb_internals_pkg.all;

entity eb_framer is
  port(
    clk_i           : in  std_logic;            -- WB Clock
    rst_n_i         : in  std_logic;            -- async reset

    slave_i         : in  t_wishbone_slave_in;  -- WB op. -> not WB compliant, but the record format is convenient
    slave_stall_o   : out std_logic;            -- flow control    
    tx_send_now_i   : in std_logic;
    
    master_o        : out t_wishbone_master_out;
    master_i        : in  t_wishbone_master_in; 
    tx_flush_o      : out std_logic; 
    max_ops_i       : in unsigned(15 downto 0);
    length_i        : in unsigned(15 downto 0); 
    cfg_rec_hdr_i   : in t_rec_hdr -- EB cfg information, eg read from cfg space etc
);   
end eb_framer;

architecture rtl of eb_framer is

--signals
signal ctrl_fifo_q    : std_logic_vector(0 downto 0);
signal ctrl_fifo_d    : std_logic_vector(0 downto 0);

signal eop            : std_logic;
signal r_eop          : std_logic;

signal op_fifo_q      : std_logic_vector(31 downto 0);
signal op_fifo_d      : std_logic_vector(31 downto 0);
signal op_fifo_push   : std_logic;
signal op_fifo_pop    : std_logic;
signal op_fifo_full   : std_logic;
signal op_fifo_empty  : std_logic;

signal dat            : t_wishbone_data;
signal adr            : t_wishbone_address;
signal we             : std_logic;
signal stb            : std_logic;
signal cyc            : std_logic;

signal tx_cyc         : std_logic;
signal r_wait_for_tx  : std_logic;
signal r_rec_ack      : std_logic;
signal r_stall        : std_logic;
signal adr_wr         : t_wishbone_address;
signal adr_rd         : t_wishbone_address;
signal rec_hdr        : t_rec_hdr;
signal rec_valid      : std_logic;
signal op_pop         : std_logic;
signal r_first_rec    : std_logic;
signal r_eb_hdr       : t_eb_hdr;

-- FSMs
type t_mux_state is (s_IDLE, s_EB, s_REC, s_WA, s_RA, s_WRITE, s_READ, s_DONE, s_PAD);
signal r_mux_state    : t_mux_state;
signal r_cnt_ops     : unsigned(8 downto 0);
signal r_cnt_pad      : unsigned(16 downto 0);
signal r_max_ops_left : unsigned(15 downto 0);
signal r_global_word_cnt : unsigned(15 downto 0);
signal r_length : unsigned(15 downto 0);


function f_parse_rec(x : std_logic_vector) return t_rec_hdr is
    variable o : t_rec_hdr;
  begin
    o.bca_cfg  := x(31);
    o.rca_cfg  := x(30);
    o.rd_fifo  := x(29);
    o.res1     := x(28);
    o.drop_cyc := x(27);
    o.wca_cfg  := x(26);
    o.wr_fifo  := x(25);
    o.res2     := x(24);
    o.sel      := x(23 downto 16);
    o.wr_cnt   := unsigned(x(15 downto 8));
    o.rd_cnt   := unsigned(x( 7 downto 0));
    return o;
  end function;

function to_unsigned(b_in : std_logic; bits : natural)
return unsigned is
variable ret : std_logic_vector(bits-1 downto 0) := (others=> '0');
begin
  ret(0) := b_in;
  return unsigned(ret);
end function to_unsigned;

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
  PORT MAP (
         
      clk_i           => clk_i,
      rst_n_i         => rst_n_i,

      slave_i         => slave_i,
      slave_stall_o   => r_stall,
      rec_ack_i       => r_rec_ack,
      
      rec_valid_o     => rec_valid,
      rec_hdr_o       => rec_hdr,
      rec_adr_rd_o    => adr_rd, 
      rec_adr_wr_o    => adr_wr,
      max_ops_i       => r_max_ops_left,
      cfg_rec_hdr_i   => cfg_rec_hdr_i); 
 
------------------------------------------------------------------------------
-- fifos
------------------------------------------------------------------------------
  op_fifo : eb_fifo
    generic map(
      g_width => 32,
      g_size  => 256)
    port map (
      clk_i     => clk_i,
      rstn_i    => rst_n_i,
      w_full_o  => op_fifo_full,
      w_push_i  => op_fifo_push,
      w_dat_i   => op_fifo_d,
      r_empty_o => op_fifo_empty,
      r_pop_i   => op_fifo_pop,
      r_dat_o   => op_fifo_q);
      
   ctrl_fifo : eb_fifo
    generic map(
      g_width => 1,
      g_size  => 256)
    port map (
      clk_i     => clk_i,
      rstn_i    => rst_n_i,
      w_full_o  => open,
      w_push_i  => op_fifo_push,
      w_dat_i   => ctrl_fifo_d,
      r_empty_o => open,
      r_pop_i   => op_fifo_pop,
      r_dat_o   => ctrl_fifo_q);
       

  op_fifo_pop   <= op_pop and not op_fifo_empty;
  op_fifo_push  <= cyc and stb and not r_stall;
  op_fifo_d <= dat when we = '1'
              else adr;
              
  ctrl_fifo_d(0) <= tx_send_now_i;
  eopmux : with r_mux_state select
  eop <= '0'              when s_IDLE,
          ctrl_fifo_q(0)  when others;
  
  master_o.cyc <= tx_cyc;
  master_o.we <= '0';
  master_o.sel <= (others => '1');
  master_o.adr <= (others => '0');
------------------------------------------------------------------------------
-- Output Mux
------------------------------------------------------------------------------
  OMux : with r_mux_state select
  master_o.dat <= op_fifo_q(31 downto 0)  when s_WRITE | s_READ,
               f_format_rec(rec_hdr)   when s_REC,
               adr_wr                  when s_WA,
               adr_rd                  when s_RA, 
               f_format_eb(r_eb_hdr)   when s_EB,
               (others => '0')         when others;

      r_eb_hdr              <= c_eb_init;

  p_eb_mux : process (clk_i, rst_n_i) is
  variable v_state        : t_mux_state;
 
  begin
    if rst_n_i = '0' then
      r_mux_state           <= s_IDLE;

      --r_eb_hdr.no_response  <= '0';
      tx_cyc  <= '0';
      r_first_rec   <= '1';
      r_eop         <= '0'; 
    elsif rising_edge(clk_i) then

      v_state       := r_mux_state;                    
      op_pop        <= '0';
      master_o.stb  <= '0';
      r_rec_ack     <= '0';
      tx_flush_o    <= '0';
      r_first_rec   <= r_first_rec  or eop;
      r_eop         <= r_eop        or eop; --(tx_send_now_i or eop);
      
      
      case r_mux_state is
        when s_IDLE   =>  if(rec_valid = '1') then
                           if(r_first_rec = '1') then
                              tx_cyc            <= '1';
                              tx_flush_o        <= '1';
                              r_first_rec       <= '0';
                              r_length          <= length_i;
                              r_global_word_cnt <= (others => '0');
                              r_max_ops_left    <= max_ops_i;
                              v_state           := s_EB;
                            else
                              r_max_ops_left <= r_max_ops_left - (1 + to_unsigned(or rec_hdr.rd_cnt, 16)
                                                                    + to_unsigned(or rec_hdr.wr_cnt, 16) 
                                                                    + rec_hdr.rd_cnt  
                                                                    + rec_hdr.wr_cnt);
                              v_state       := s_REC;
                            end if;
                          end if;
                          
        when s_EB     =>  if(master_i.stall = '0') then
                            v_state    := s_REC; -- output EB hdr
                            r_global_word_cnt <= r_global_word_cnt + 2;                         
                          end if;
                          
        when s_REC    =>  if(master_i.stall = '0') then
                            if(rec_hdr.wr_cnt + rec_hdr.rd_cnt /= 0) then -- output record hdr
                              if(rec_hdr.wr_cnt /= 0) then
                                v_state    := s_WA;
                              else
                                v_state    := s_RA;
                              end if;
                              
                            else
                              v_state    := s_DONE;
                              
                            end if;
                            r_global_word_cnt <= r_global_word_cnt + 2;
                          end if;
        
        when s_WA     =>  if(master_i.stall = '0') then
                            r_cnt_ops    <= '0' & rec_hdr.wr_cnt -2; -- output write base address
                            --op_pop    <= '1';
                            v_state    := s_WRITE;
                            r_global_word_cnt <= r_global_word_cnt + 2;
                          end if;               
        
        when s_WRITE  =>  if(master_i.stall = '0') then
                            if(r_cnt_ops(r_cnt_ops'left) = '1') then -- output write values
                              if(rec_hdr.rd_cnt /= 0) then
                                v_state := s_RA;
                              else
                                v_state := s_DONE;
                              end if;
                            else
                              op_pop    <= '1';
                              r_cnt_ops <= r_cnt_ops-1;
                              r_global_word_cnt <= r_global_word_cnt + 2;
                            end if;
                          end if;
        
        when s_RA     =>  if(master_i.stall = '0') then
                            r_cnt_ops    <= '0' & rec_hdr.rd_cnt -2; -- output readback address
                            --op_pop    <= '1';
                            v_state    := s_READ;
                            r_global_word_cnt <= r_global_word_cnt + 2;
                          end if;  
        
        when s_READ   =>  if(master_i.stall = '0') then
                            if(r_cnt_ops(r_cnt_ops'left) = '1') then -- output read addresses
                              v_state := s_DONE;
                            else
                              op_pop    <= '1';
                              r_cnt_ops <= r_cnt_ops-1;
                              r_global_word_cnt <= r_global_word_cnt + 2;
                            end if;
                          end if;
        
        when s_DONE   =>  if(r_eop = '1') then    
                            -- if the packet is shorter than we specified for the header, we need to pad with empty eb records
                            if( r_global_word_cnt < r_length) then
                              r_cnt_pad     <= '0' & (r_length - r_global_word_cnt -2); 
                              v_state       := s_PAD;
                            else
                              tx_cyc        <= not r_eop;
                              r_eop         <= '0';
                              v_state       := s_IDLE;
                            end if;
                          else
                            v_state       := s_IDLE;
                          end if;
       
        when s_PAD    =>  if(r_cnt_pad(r_cnt_pad'left) = '1') then -- output padding
                              tx_cyc        <= not r_eop;
                              r_eop         <= '0';
                              v_state       := s_IDLE;
                            else
                              r_cnt_pad <= r_cnt_pad-2;
                              r_global_word_cnt <= r_global_word_cnt + 2;
                            end if;

        
        
        when others   =>  v_state := s_IDLE;
      end case;
    
      -- flags on state transition
      if((v_state /= s_IDLE) and (v_state /= s_DONE)) then
        master_o.stb    <= '1';
      end if;
      if(v_state = s_DONE) then
        r_rec_ack <= '1';
      end if;
                                        
      r_mux_state <= v_state;
    
    end if;
  end process;

end architecture;




