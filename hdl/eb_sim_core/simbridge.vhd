library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.wishbone_pkg.all;
use work.simbridge_pkg.all;

entity simbridge is
  generic (
      g_sdb_address    : t_wishbone_address
    );
  port (
  clk_i    : in  std_logic;
  rstn_i   : in  std_logic;
  master_o : out t_wishbone_master_out;
  master_i : in  t_wishbone_master_in
    );
end entity;

architecture simulation of simbridge is
begin
  process
    variable master_o_cyc,master_o_stb,master_o_we  : std_logic;
    variable master_o_dat,master_o_adr,master_o_sel : integer;
    variable master_i_ack,master_i_err,master_i_rty,master_i_stall : std_logic;
    variable master_i_dat                                          : integer;
    constant stop_until_connected : integer := 1;
  begin
    master_o.cyc <= '0';
    master_o.stb <= '0';
    master_o.we  <= '0';
    master_o.adr <= (others => '0');
    master_o.dat <= (others => '0');
    master_o.sel <= (others => '0');

    wait until rising_edge(rstn_i);
    wait until rising_edge(clk_i);
    eb_simbridge_init(stop_until_connected, to_integer(signed(g_sdb_address)));
    while true loop

      wait until rising_edge(clk_i);
      eb_simbridge_control_out(master_o_cyc,master_o_stb,master_o_we,master_o_adr,master_o_dat,master_o_sel);
      master_o.cyc <= master_o_cyc;
      master_o.stb <= master_o_stb;
      master_o.we  <= master_o_we;
      master_o.adr <= std_logic_vector(to_signed(master_o_adr,32));
      master_o.dat <= std_logic_vector(to_signed(master_o_dat,32));      
      master_o.sel <= std_logic_vector(to_signed(master_o_sel, 4));    

      wait until falling_edge(clk_i);
      master_i_ack := master_i.ack;
      master_i_err := master_i.err;
      master_i_rty := master_i.rty;
      master_i_stall := master_i.stall;
      master_i_dat := to_integer(signed(master_i.dat));
      eb_simbridge_control_in(master_i_ack,master_i_err,master_i_rty,master_i_stall,master_i_dat);
      
    end loop;
  end process;

end architecture;
