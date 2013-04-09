------------------------------------------------------------------------------
-- Title      : Etherbone Tag FIFO
-- Project    : Etherbone Core
------------------------------------------------------------------------------
-- File       : eb_tag_fifo.vhd
-- Author     : Wesley W. Terpstra
-- Company    : GSI
-- Created    : 2013-04-08
-- Last update: 2013-04-08
-- Platform   : FPGA-generic
-- Standard   : VHDL'93
-------------------------------------------------------------------------------
-- Description: Tracks which channel the MUX should pop next
-------------------------------------------------------------------------------
-- Copyright (c) 2013 GSI
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author          Description
-- 2013-04-08  1.0      terpstra        Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.wishbone_pkg.all;
use work.eb_internals_pkg.all;

entity eb_tag_fifo is
  port(
    clk_i       : in  std_logic;
    rstn_i      : in  std_logic;
    
    fsm_stb_i   : in  std_logic;
    fsm_dat_i   : in  t_tag;
    fsm_full_o  : out std_logic;

    mux_pop_i   : in  std_logic;
    mux_dat_o   : out t_tag;
    mux_empty_o : out std_logic);
end eb_tag_fifo;

architecture rtl of eb_tag_fifo is
begin

  fifo : eb_fifo
    generic map(
      g_width => t_tag'length,
      g_size  => 1024) -- 4* the length of the other FIFOs
    port map(
      clk_i     => clk_i,
      rstn_i    => rstn_i,
      w_full_o  => fsm_full_o,
      w_push_i  => fsm_stb_i,
      w_dat_i   => fsm_dat_i,
      r_empty_o => mux_empty_o,
      r_pop_i   => mux_pop_i,
      r_dat_o   => mux_dat_o);
      
end rtl;
