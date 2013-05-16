--! @file eb_master_top.vhd
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
use work.eb_internals_pkg.all;
use work.eb_hdr_pkg.all;
use work.etherbone_pkg.all;

entity eb_master_top is
port(
  clk_i       : in  std_logic;
  rst_n_i     : in  std_logic;

  slave_i     : in  t_wishbone_slave_in;
  slave_o     : out t_wishbone_slave_out;
  
  my_mac_o    : out std_logic_vector(47 downto 0);
  my_ip_o     : out std_logic_vector(31 downto 0);
  my_port_o   : out std_logic_vector(15 downto 0);
  
  his_mac_o   : out std_logic_vector(47 downto 0); 
  his_ip_o    : out std_logic_vector(31 downto 0);
  his_port_o  : out std_logic_vector(15 downto 0); 
  length_o    : out std_logic_vector(15 downto 0);
  
  adr_hi_o    : std_logic_vector(c_wishbone_data_width-1 downto 0);
  eb_opt_o    : std_logic_vector(c_wishbone_data_width-1 downto 0)
);
end eb_master_top;

architecture rtl of eb_master_top is

constant c_ctrl_reg_spc_width : natural := 5; --fix me: need log2 function

subtype t_r_adr is natural range 0 to 2**c_ctrl_reg_spc_width-1;
--Register map
constant c_RESET        : t_r_adr := 0;                 --wo
constant c_STATUS       : t_r_adr := c_RESET        +1; --rw
constant c_SRC_MAC_HI   : t_r_adr := c_STATUS       +1; --rw
constant c_SRC_MAC_LO   : t_r_adr := c_SRC_MAC_HI   +1; --rw
constant c_SRC_IPV4     : t_r_adr := c_SRC_MAC_LO   +1; --rw
constant c_SRC_UDP_PORT : t_r_adr := c_SRC_IPV4     +1; --rw
constant c_DST_MAC_HI   : t_r_adr := c_SRC_UDP_PORT +1; --rw
constant c_DST_MAC_LO   : t_r_adr := c_DST_MAC_HI   +1; --rw
constant c_DST_IPV4     : t_r_adr := c_DST_MAC_LO   +1; --rw
constant c_DST_UDP_PORT : t_r_adr := c_DST_IPV4     +1; --rw
constant c_MTU          : t_r_adr := c_DST_UDP_PORT +1; --rw
constant c_OPA_HI       : t_r_adr := c_MTU          +1; --rw
constant c_OPA_MSK      : t_r_adr := c_OPA_HI       +1; --rw
constant c_RBA_HI       : t_r_adr := c_OPA_MSK      +1; --rw
constant c_RBA_MSK      : t_r_adr := c_RBA_HI       +1; --rw
constant c_WOA_BASE     : t_r_adr := c_RBA_MSK      +1; --ro
constant c_ROA_BASE     : t_r_adr := c_WOA_BASE     +1; --ro
constant c_EB_OPT       : t_r_adr := c_ROA_BASE     +1; --rw
constant c_LAST         : t_r_adr := c_EB_OPT; 

subtype t_reg is std_logic_vector(c_wishbone_data_width-1 downto 0);
type t_ctrl is array(0 to c_LAST) of t_reg;

signal r_ctrl   : t_ctrl;
signal r_ack    : std_logic;
signal r_err    : std_logic;
signal r_stall  : std_logic;
signal r_rst_n  : std_logic;
signal push     : std_logic;



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
  slave_o.dat <=    r_ctrl(adr) and msk;
  r_ack       <= '1'; 
end procedure rd;

begin
	if rst_n_i = '0' then
	 slave_o.dat   <= (others => '0');
	elsif rising_edge(clk_i) then
    r_ack       <= '0';    
    r_err       <= '0';
    r_rst_n     <= '1';   
    --r_debug_adr <= slave_i.adr(5-1+3 downto 2); 
    v_adr       := to_integer(unsigned(slave_i.adr(c_ctrl_reg_spc_width-1+2 downto 2))); 
    
    if(push = '1') then
      --CTRL REGISTERS
      if(unsigned(slave_i.adr(slave_i.adr'left downto c_ctrl_reg_spc_width+2) /= 0) then
        if(slave_i.we = '1') then
          case v_adr is
            when c_RESET          => r_rst_n <= '0';
            when c_SRC_MAC_HI     => wr(v_adr);
            when c_SRC_MAC_LO     => wr(v_adr,  x"FFFF0000");
            when c_SRC_IPV4       => wr(v_adr);
            when c_SRC_UDP_PORT   => wr(v_adr,  x"0000FFFF");
            when c_DST_MAC_HI     => wr(v_adr);
            when c_DST_MAC_LO     => wr(v_adr,  x"FFFF0000");
            when c_DST_IPV4       => wr(v_adr);
            when c_DST_UDP_PORT   => wr(v_adr,  x"0000FFFF");
            when c_MTU            => wr(v_adr,  x"000000FF"); 
            when c_OPA_HI         => wr(v_adr);
            when c_OPA_MSK        => wr(v_adr); 
            when c_RBA_HI         => wr(v_adr);
            when c_RBA_MSK        => wr(v_adr); 
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
            when c_RBA_HI         => rd(v_adr);
            when c_RBA_MSK        => rd(v_adr); 
            when c_WOA_BASE       => rd(v_adr);
            when c_ROA_BASE       => rd(v_adr);
            when c_EB_OPT         => rd(v_adr);
            when others           => r_err <= '1';
          end case;    
        end if;
      --STAGING AREA   
      elsif(unsigned(slave_i.adr and r_ctrl(c_OPA_MSK)) /= 0) then
        if(slave_i.we = '1') then
        
        else
          r_err <= '1';
        end if;
        
      --BAD/UNMAPPED ADR
      else
        r_err <= '1';
      end if;
  end if;
end if;
end process;

end architecture;
