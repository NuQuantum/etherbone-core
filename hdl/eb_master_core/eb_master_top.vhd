--! @file eb_master_top.vhd
--! @brief Top file for the EtherBone Master
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
use work.eb_internals_pkg.all;
use work.eb_hdr_pkg.all;
use work.etherbone_pkg.all;

entity eb_master_top is
port(
  clk_i       : in  std_logic;
  rst_n_i     : in  std_logic;

  slave_i     : in  t_wishbone_slave_in;
  slave_o     : out t_wishbone_slave_out;
  
  src_i        : in  t_wrf_source_in;
  src_o        : out t_wrf_source_out
);
end eb_master_top;

architecture rtl of eb_master_top is


signal r_err    : std_logic;
signal r_stall  : std_logic;
signal r_rst_n  : std_logic;
signal push     : std_logic;

  signal s_his_mac,  s_my_mac  : std_logic_vector(47 downto 0);
  signal s_his_ip,   s_my_ip   : std_logic_vector(31 downto 0);
  signal s_his_port, s_my_port : std_logic_vector(15 downto 0);
  
  signal s_tx_stb     : std_logic;
  signal s_tx_stall   : std_logic;
  signal s_skip_stb   : std_logic;
  signal s_skip_stall : std_logic;
  signal s_length     : unsigned(15 downto 0); -- of UDP in words
  
  signal s_rx2widen   : t_wishbone_master_out;
  signal s_widen2rx   : t_wishbone_master_in;
  signal s_widen2fsm  : t_wishbone_master_out;
  signal s_fsm2widen  : t_wishbone_master_in;
  signal s_fsm2narrow : t_wishbone_master_out;
  signal s_narrow2fsm : t_wishbone_master_in;
  signal s_narrow2tx  : t_wishbone_master_out;
  signal s_tx2narrow  : t_wishbone_master_in;
  

-- instances:
-- eb_master_wb_if
-- eb_framer
-- eb_eth_tx
-- eb_stream_narrow

narrow : eb_stream_narrow
    generic map(
      g_slave_width  => 32,
      g_master_width => 16)
    port map(
      clk_i    => clk_i,
      rst_n_i  => nRst_i,
      slave_i  => s_fsm2narrow,
      slave_o  => s_narrow2fsm,
      master_i => s_tx2narrow,
      master_o => s_narrow2tx);

  tx : eb_eth_tx
    generic map(
      g_mtu => g_mtu)
    port map(
      clk_i        => clk_i,
      rst_n_i      => nRst_i,
      src_i        => src_i,
      src_o        => src_o,
      slave_o      => s_tx2narrow,
      slave_i      => s_narrow2tx,
      stb_i        => s_tx_stb,
      stall_o      => s_tx_stall,
      mac_i        => s_his_mac,
      ip_i         => s_his_ip,
      port_i       => s_his_port,
      length_i     => s_length,
      skip_stb_i   => s_skip_stb,
      skip_stall_o => s_skip_stall,
      my_mac_i     => s_my_mac,
      my_ip_i      => s_my_ip,
      my_port_i    => s_my_port);

begin

--SLAVE IF
slave_o.ack   <= r_ack;
slave_o.err   <= r_err;
slave_o.stall <= r_stall;
slave_o.int   <= '0';
slave_o.rty   <= '0';
push <= slave_i.cyc and slave_i.stb and r_stall;

--CTRL REGs
his_mac_o   <= r_ctrl(c_DST_MAC_HI) & r_ctrl(c_DST_MAC_HI)(31 downto 16);
his_ip_o    <= r_ctrl(c_DST_IPV4);
his_port_o  <= r_ctrl(c_DST_UDP_PORT)(s_his_port'left downto 0);
my_mac_o    <= r_ctrl(c_SRC_MAC_HI) & r_ctrl(c_SRC_MAC_HI)(31 downto 16);
my_ip_o     <= r_ctrl(c_SRC_IPV4);
my_port_o   <= r_ctrl(c_SRC_UDP_PORT)(s_my_port'left downto 0);
length_o    <= r_ctrl(c_MTU)(s_length'left downto 0));
adr_hi_o    <= r_ctrl(c_OPA_HI);
eb_opt_o    <= r_ctrl(c_EB_OPT);


p_main : process (clk_i, rst_n_i) is
variable v_adr : t_r_adr;


begin
	if rst_n_i = '0' then
	elsif rising_edge(clk_i) then
    
  end if;
end if;
end process;

end architecture;
