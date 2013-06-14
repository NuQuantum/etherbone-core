--! @file eb_master_wb_if.vhd
--! @brief Ctrl wishbone interface for the EtherBone master
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

entity eb_master_wb_if is
generic(g_adr_bits_hi : natural := 8);
port(
  clk_i       : in  std_logic;
  rst_n_i     : in  std_logic;

  wb_rst_n_o  : out std_logic;
  flush_o     : out std_logic;

  slave_i     : in  t_wishbone_slave_in;
  slave_dat_o : out t_wishbone_data;
  slave_ack_o : out  std_logic;
  slave_err_o : out  std_logic;
  
  my_mac_o    : out std_logic_vector(47 downto 0);
  my_ip_o     : out std_logic_vector(31 downto 0);
  my_port_o   : out std_logic_vector(15 downto 0);
  
  his_mac_o   : out std_logic_vector(47 downto 0); 
  his_ip_o    : out std_logic_vector(31 downto 0);
  his_port_o  : out std_logic_vector(15 downto 0); 
  length_o    : out unsigned(15 downto 0);
  
  adr_hi_o    : out t_wishbone_address;
  eb_opt_o    : out t_rec_hdr);
end eb_master_wb_if;



architecture rtl of  eb_master_wb_if is

constant c_ctrl_reg_spc_width : natural := 5; --fix me: need log2 function

subtype t_r_adr is natural range 0 to 2**c_ctrl_reg_spc_width-1;
--Register map
constant c_RESET        : t_r_adr := 0;                 --wo    00
constant c_FLUSH        : t_r_adr := c_RESET        +1; --wo    04
constant c_STATUS       : t_r_adr := c_FLUSH        +1; --rw    08
constant c_SRC_MAC_HI   : t_r_adr := c_STATUS       +1; --rw    0C
constant c_SRC_MAC_LO   : t_r_adr := c_SRC_MAC_HI   +1; --rw    10 
constant c_SRC_IPV4     : t_r_adr := c_SRC_MAC_LO   +1; --rw    14 
constant c_SRC_UDP_PORT : t_r_adr := c_SRC_IPV4     +1; --rw    18
constant c_DST_MAC_HI   : t_r_adr := c_SRC_UDP_PORT +1; --rw    1C
constant c_DST_MAC_LO   : t_r_adr := c_DST_MAC_HI   +1; --rw    20
constant c_DST_IPV4     : t_r_adr := c_DST_MAC_LO   +1; --rw    24
constant c_DST_UDP_PORT : t_r_adr := c_DST_IPV4     +1; --rw    28
constant c_MTU          : t_r_adr := c_DST_UDP_PORT +1; --rw    2C
constant c_OPA_HI       : t_r_adr := c_MTU          +1; --rw    30
constant c_OPA_MSK      : t_r_adr := c_OPA_HI       +1; --rw    34
constant c_WOA_BASE     : t_r_adr := c_OPA_MSK      +1; --ro    38
constant c_ROA_BASE     : t_r_adr := c_WOA_BASE     +1; --ro    3C
constant c_EB_OPT       : t_r_adr := c_ROA_BASE     +1; --rw    40
constant c_LAST         : t_r_adr := c_EB_OPT; 

constant c_STAT_CONFIGURED  : t_wishbone_data := x"00000001";
constant c_STAT_BUSY        : t_wishbone_data := x"00000002";
constant c_STAT_ERROR       : t_wishbone_data := x"00000004";
constant c_STAT_EB_SENT     : t_wishbone_data := x"FFFF0000";

type t_ctrl is array(0 to c_LAST) of t_wishbone_data;

signal r_ctrl   : t_ctrl;
signal r_ack    : std_logic;
signal r_err    : std_logic;
signal r_rst_n  : std_logic;
signal r_flush  : std_logic;
signal push     : std_logic;
signal r_busy   : std_logic;
signal r_eb_sent : std_logic;
constant c_adr_mask : std_logic_vector(31 downto 0) := not std_logic_vector(to_unsigned(2**(32-g_adr_bits_hi+1)-1, 32));



begin

--SLAVE IF
slave_ack_o   <= r_ack;
slave_err_o   <= r_err;
push <= slave_i.cyc and slave_i.stb;
r_eb_sent <= r_busy; 


--CTRL REGs
wb_rst_n_o  <= r_rst_n;
flush_o     <= r_flush;
his_mac_o   <= r_ctrl(c_DST_MAC_HI) & r_ctrl(c_DST_MAC_LO)(31 downto 16);
his_ip_o    <= r_ctrl(c_DST_IPV4);
his_port_o  <= r_ctrl(c_DST_UDP_PORT)(his_port_o'left downto 0);
my_mac_o    <= r_ctrl(c_SRC_MAC_HI) & r_ctrl(c_SRC_MAC_LO)(31 downto 16);
my_ip_o     <= r_ctrl(c_SRC_IPV4);
my_port_o   <= r_ctrl(c_SRC_UDP_PORT)(my_port_o'left downto 0);
length_o    <= unsigned(r_ctrl(c_MTU)(length_o'left downto 0));
adr_hi_o    <= r_ctrl(c_OPA_HI);
eb_opt_o    <= f_parse_rec(r_ctrl(c_EB_OPT));



p_wb_if : process (clk_i, rst_n_i) is
variable v_adr : t_r_adr;

procedure wr( adr   : in natural := 1;
              msk   : in std_logic_vector(c_wishbone_data_width-1 downto 0) := x"FFFFFFFF"
                    ) is
begin
  r_ctrl(adr) <= slave_i.dat and msk;
  r_ack       <= '1'; 
end procedure wr;

procedure rd( adr   : in natural := 1;
              msk   : in std_logic_vector(c_wishbone_data_width-1 downto 0) := x"FFFFFFFF"
                    ) is
begin
  slave_dat_o <=    r_ctrl(adr) and msk;
  r_ack       <= '1'; 
end procedure rd;

begin
	
	if rising_edge(clk_i) then
    if rst_n_i = '0' then
	    slave_dat_o  <= (others => '0');
	    r_rst_n      <= '0';
	    --set everything except MTU to zero
	    for I in c_STATUS to c_MTU-1 loop
	      r_ctrl(I) <= (others => '0');
	    end loop;
	    r_ctrl(c_MTU) <= t_wishbone_data(to_unsigned(512, 32));
	    for I in c_MTU+1 to c_LAST loop
	      r_ctrl(I) <= (others => '0');
	    end loop;
	  else  
    r_ack       <= '0';    
    r_err       <= '0';
    r_rst_n     <= '1';
    r_flush     <= '0';    
    --r_debug_adr <= slave_i.adr(5-1+3 downto 2); 
    v_adr       := to_integer(unsigned(slave_i.adr(7 downto 2))); 
    r_rst_n      <= '1';
    
    if(push = '1') then
      --CTRL REGISTERS
      if(slave_i.adr(32-g_adr_bits_hi+1) = '0') then
        if(slave_i.we = '1') then
          case v_adr is
            when c_RESET          => r_rst_n <= '0';
            when c_FLUSH          => r_flush <= '1';
            when c_SRC_MAC_HI     => wr(v_adr);
            when c_SRC_MAC_LO     => wr(v_adr,  x"FFFF0000");
            when c_SRC_IPV4       => wr(v_adr);
            when c_SRC_UDP_PORT   => wr(v_adr,  x"0000FFFF");
            when c_DST_MAC_HI     => wr(v_adr);
            when c_DST_MAC_LO     => wr(v_adr,  x"FFFF0000");
            when c_DST_IPV4       => wr(v_adr);
            when c_DST_UDP_PORT   => wr(v_adr,  x"0000FFFF");
            when c_MTU            => wr(v_adr,  x"000000FF"); 
            when c_OPA_HI         => wr(v_adr, c_adr_mask);
            when c_OPA_MSK        => wr(v_adr); 
            when c_EB_OPT         => wr(v_adr,  x"0000FFFF");
            when others           => r_err <= '1';
          end case;
        
        else  
          case v_adr is
            when c_STATUS         => rd(v_adr);
            when c_SRC_MAC_HI     => rd(v_adr);
            when c_SRC_MAC_LO     => rd(v_adr);
            when c_SRC_IPV4       => rd(v_adr);
            when c_SRC_UDP_PORT   => rd(v_adr);
            when c_DST_MAC_HI     => rd(v_adr);
            when c_DST_MAC_LO     => rd(v_adr);
            when c_DST_IPV4       => rd(v_adr);
            when c_DST_UDP_PORT   => rd(v_adr);
            when c_MTU            => rd(v_adr); 
            when c_OPA_HI         => rd(v_adr);
            when c_OPA_MSK        => rd(v_adr); 
            when c_WOA_BASE       => rd(v_adr);
            when c_ROA_BASE       => rd(v_adr);
            when c_EB_OPT         => rd(v_adr);
            when others           => r_err <= '1';
          end case;    
        end if;
      --STAGING AREA   
      else
        if(slave_i.we = '1') then
          -- check if the core is configured
          if( (r_ctrl(c_STATUS) and c_STAT_CONFIGURED) = c_STAT_CONFIGURED) then 
            null; -- valid access to the framer. we dont need to do anything about that here
          else
            r_err <= '1'; --give back an error, the eth/udp/ip info is bad
          end if;
        else
          r_err <= '1'; -- a read on the framer ?! That's forbidden, give the user a scolding
        end if;
        
      --BAD/UNMAPPED ADR
    
        r_err <= '1';
      end if;
    end if;
  end if;
end if;
end process;

end architecture;
