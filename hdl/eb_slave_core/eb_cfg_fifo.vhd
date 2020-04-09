------------------------------------------------------------------------------
-- Title      : Etherbone Config Master FIFO
-- Project    : Etherbone Core
------------------------------------------------------------------------------
-- File       : eb_cfg_fifo.vhd
-- Author     : Wesley W. Terpstra
-- Company    : GSI
-- Created    : 2013-04-08
-- Last update: 2020-04-09
-- Platform   : FPGA-generic
-- Standard   : VHDL'93
-------------------------------------------------------------------------------
-- Description: Buffers Config space requests
--
--              Can be used as MSI slave and provides three registers that
--              can be polled in the following order:
--              1) 0x40: address field of the MSI
--              2) 0x44: data field of the MSI
--              3) 0x48: MSI counter and valid flags
--                       bits 31 downto 17 : number of accepted MSI by the slave interface
--                       bits 16 downto 2  : sequence number of the last polled MSI
--                       bit   1           : more MSI are waiting to be polled
--                       bit   0           : the current MSI is valid.
-------------------------------------------------------------------------------
-- Copyright (c) 2013 GSI
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author          Description
-- 2013-04-08  1.0      terpstra        Created
-- 2020-04-09  1.1      reese           Add MSI slave and a polling interface
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.wishbone_pkg.all;
use work.eb_internals_pkg.all;
use work.etherbone_pkg.all;

entity eb_cfg_fifo is
  generic(
    g_sdb_address : t_wishbone_address);
  port(
    clk_i       : in  std_logic;
    rstn_i      : in  std_logic;

    errreg_i    : in  std_logic_vector(63 downto 0);

    cfg_i       : in  t_wishbone_slave_in;
    cfg_o       : out t_wishbone_slave_out;

    -- MSI interface
    msi_slave_i   : in  t_wishbone_slave_in;
    msi_slave_o   : out t_wishbone_slave_out;

    fsm_stb_i   : in  std_logic;
    fsm_adr_i   : in  t_wishbone_address;
    fsm_full_o  : out std_logic;

    mux_pop_i   : in  std_logic;
    mux_dat_o   : out t_wishbone_data;
    mux_empty_o : out std_logic;

    my_mac_o    : out std_logic_vector(47 downto 0);
    my_ip_o     : out std_logic_vector(31 downto 0);
    my_port_o   : out std_logic_vector(15 downto 0));

end eb_cfg_fifo;

architecture rtl of eb_cfg_fifo is

  constant c_pad  : std_logic_vector(31 downto 16) := (others => '0');

  signal r_mac  : std_logic_vector(6*8-1 downto 0);
  signal r_ip   : std_logic_vector(4*8-1 downto 0);
  signal r_port : std_logic_vector(2*8-1 downto 0);
  
  signal s_fsm_adr     : std_logic_vector(4 downto 0);
  signal s_fifo_adr    : std_logic_vector(4 downto 0);
  signal s_fifo_empty  : std_logic;
  signal s_fifo_pop    : std_logic;
  signal r_cache_empty : std_logic;
  signal r_cache_adr   : std_logic_vector(4 downto 0);

  -- msi registers and constants
  signal msi_full      : std_logic;
  signal msi_push      : std_logic := '0';
  signal msi_dat_adr_push : std_logic_vector(63 downto 0):=(others => '0');
  signal msi_dat_adr_pop : std_logic_vector(63 downto 0):=(others => '0');
  signal msi_empty     : std_logic;
  signal msi_pop       : std_logic := '0';
  signal msi_dat : std_logic_vector(31 downto 0):=(others => '0');
  signal msi_adr : std_logic_vector(31 downto 0):=(others => '0');
  signal msi_cnt : std_logic_vector(31 downto 0):=(others => '0');
  signal msi_counter    : unsigned(14 downto 0);
  signal msi_counter_in : unsigned(14 downto 0);
  signal msi_lock : std_logic := '0';
  type msi_state_t is (MSI_S_WAIT_NOT_EMPTY, MSI_S_READ_FIFO,  MSI_S_PROVIDE_DATA);
  signal msi_state : msi_state_t := MSI_S_WAIT_NOT_EMPTY;

  impure function update(x : std_logic_vector) return std_logic_vector is
    alias    y : std_logic_vector(x'length-1 downto 0) is x;
    variable o : std_logic_vector(x'length-1 downto 0);
  begin
    for i in (y'length/8)-1 downto 0 loop
      if cfg_i.sel(i) = '1' then
        o(i*8+7 downto i*8) := cfg_i.dat(i*8+7 downto i*8);
      else
        o(i*8+7 downto i*8) := y(i*8+7 downto i*8);
      end if;
    end loop;

    return o;
  end update;

begin

  cfg_o.err <= '0';
  cfg_o.rty <= '0';
  cfg_o.stall <= '0';

  cfg_wbs : process(rstn_i, clk_i) is
  begin
    if rstn_i = '0' then
      r_mac  <= x"D15EA5EDBEEF";
      r_ip   <= x"C0A80064";
      r_port <= x"EBD0";

      cfg_o.ack <= '0';
      cfg_o.dat <= (others => '0');
    elsif rising_edge(clk_i) then
      if cfg_i.cyc = '1' and cfg_i.stb = '1' and cfg_i.we = '1' then
        case to_integer(unsigned(cfg_i.adr(5 downto 2))) is
          when 4 => r_mac(47 downto 32) <= update(r_mac(47 downto 32));
          when 5 => r_mac(31 downto  0) <= update(r_mac(31 downto  0));
          when 6 => r_ip   <= update(r_ip);
          when 7 => r_port <= update(r_port);
          when others => null;
        end case;
      end if;

      cfg_o.ack <= cfg_i.cyc and cfg_i.stb;
      
      case to_integer(unsigned(cfg_i.adr(6 downto 2))) is
        when 0 => cfg_o.dat <= errreg_i(63 downto 32);
        when 1 => cfg_o.dat <= errreg_i(31 downto  0);
        when 2 => cfg_o.dat <= (others => '0');
        when 3 => cfg_o.dat <= g_sdb_address;
        when 4 => cfg_o.dat <= c_pad & r_mac(47 downto 32);
        when 5 => cfg_o.dat <= r_mac(31 downto 0);
        when 6 => cfg_o.dat <= r_ip;
        when 7 => cfg_o.dat <= c_pad & r_port;
        when others => cfg_o.dat <= x"00000000";
      end case;

    end if;
  end process;

  -- Discard writes.
  s_fsm_adr  <= fsm_adr_i(6 downto 2);
  
  fifo : eb_fifo
    generic map(
      g_width => 5,
      g_size  => c_queue_depth)
    port map(
      clk_i     => clk_i,
      rstn_i    => rstn_i,
      w_full_o  => fsm_full_o,
      w_push_i  => fsm_stb_i,
      w_dat_i   => s_fsm_adr,
      r_empty_o => s_fifo_empty,
      r_pop_i   => s_fifo_pop,
      r_dat_o   => s_fifo_adr);

  s_fifo_pop <= not s_fifo_empty and (r_cache_empty or mux_pop_i);

  cache : process(rstn_i, clk_i) is
  begin
    if rstn_i = '0' then
      r_cache_empty <= '1';
      r_cache_adr   <= (others => '0');
    elsif rising_edge(clk_i) then
      if r_cache_empty = '1' or mux_pop_i = '1' then
        r_cache_empty <= s_fifo_empty;
        r_cache_adr   <= s_fifo_adr;
      end if;
    end if;
  end process;

  mux_empty_o <= r_cache_empty;
  
  with r_cache_adr select 
  mux_dat_o <= 
    errreg_i(63 downto 32)                           when "00000",
    errreg_i(31 downto  0)                           when "00001",
    x"00000000"                                      when "00010",
    g_sdb_address                                    when "00011",
    c_pad & r_mac(47 downto 32)                      when "00100",
            r_mac(31 downto  0)                      when "00101",
    r_ip                                             when "00110",
    c_pad & r_port                                   when "00111",
    -- what follows is for MSI
    x"00000000"                                      when "01000",
    x"00000000"                                      when "01001",
    x"00000000"                                      when "01010",
    x"00000001"                                      when "01011",
    x"00000000"                                      when "01100",
    c_ebs_msi.sdb_component.addr_first(31 downto  0) when "01101",
    x"00000000"                                      when "01110",
    c_ebs_msi.sdb_component.addr_last(31 downto  0)  when "01111",
    msi_adr                                          when "10000",
    msi_dat                                          when "10001",
    msi_cnt                                          when "10010",
    x"00000000"                                      when others;

  my_mac_o  <= r_mac;
  my_ip_o   <= r_ip;
  my_port_o <= r_port;

  -- MSI polling
  msi_slave_o.stall <= msi_full; 
  msi_push          <= msi_slave_i.stb and msi_slave_i.cyc and not msi_full;
  msi_slave_o.ack   <= msi_slave_i.stb and msi_slave_i.cyc and not msi_full;
  msi_dat_adr_push  <= msi_slave_i.dat & msi_slave_i.adr;
  msi_slave_o.dat   <= (others => '-');
  msi_slave_o.rty   <= '0';
  msi_slave_o.err   <= '0';

  msi : eb_fifo
    generic map(
      g_width => 64,
      g_size  => c_queue_depth)
    port map(
      clk_i     => clk_i,
      rstn_i    => rstn_i,
      w_full_o  => msi_full,
      w_push_i  => msi_push,
      w_dat_i   => msi_dat_adr_push,
      r_empty_o => msi_empty,
      r_pop_i   => msi_pop,
      r_dat_o   => msi_dat_adr_pop);

  msi_output : process(rstn_i, clk_i) is
  begin
    if rstn_i = '0' then
      msi_counter <= (others => '0');
      msi_counter_in <= (others => '0');
      msi_state <= MSI_S_WAIT_NOT_EMPTY;
    elsif rising_edge(clk_i) then
      if msi_push = '1' then
        msi_counter_in <= msi_counter_in + 1;
      end if;
      msi_pop <= '0';
      case msi_state is 
        when MSI_S_WAIT_NOT_EMPTY =>
          if msi_empty = '0' and mux_pop_i = '0' and msi_lock = '0' then 
            msi_state <= MSI_S_READ_FIFO;
            msi_dat <= msi_dat_adr_pop(63 downto 32);
            msi_adr <= msi_dat_adr_pop(31 downto  0);
            msi_cnt <= std_logic_vector(msi_counter_in) & std_logic_vector(msi_counter + 1) & not msi_empty & '1';
            msi_counter <= msi_counter + 1;
          end if;
        when MSI_S_READ_FIFO =>
          msi_pop <= '1';
          msi_state <= MSI_S_PROVIDE_DATA;
        when MSI_S_PROVIDE_DATA =>
          if msi_empty = '0' then 
            msi_cnt(1) <= '1';
          end if;
          if mux_pop_i = '1' and r_cache_empty = '0' and r_cache_adr = "10010" then
            msi_state <= MSI_S_WAIT_NOT_EMPTY;
            msi_cnt <= (others => '0');
          end if;
      end case;

      -- msi_lock prevents a pop from the fifo while MSI registers are polled by the host.
      -- access to msi_adr at config address 0x40 sets the lock
      -- access to msi_cnt at config address 0x48 releases the lock
      if mux_pop_i = '1' and r_cache_empty = '0' and r_cache_adr = "10000" then
        msi_lock <= '1';
      end if;
      if mux_pop_i = '1' and r_cache_empty = '0' and r_cache_adr = "10010" then
        msi_lock <= '0';
      end if;

    end if;

  end process;

end rtl;
