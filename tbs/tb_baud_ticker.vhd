library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.uart_pkg.all;

entity tb_baud_ticker is
end entity tb_baud_ticker;

architecture rtl of tb_baud_ticker is
    
    constant T : time := 40 ns;

    signal tb_clk : std_logic := '0';
    signal tb_n_rst : std_logic := '0';
    signal tb_baud_tick : std_logic;

begin
    
    uut : entity work.uart_baud_ticker
        generic map (
            g_CLOCK      => 25000000,
            g_BAUDRATE   => 230400,
            g_OVERSAMPLE => 16
        )
        port map (
            i_clk       => tb_clk,
            i_n_rst     => tb_n_rst,
            o_baud_tick => tb_baud_tick -- Período esperado = 271 ns
        );
    
    clk_process: process
    begin
        tb_clk <= '0';
        wait for (T/2);
        tb_clk <= '1';
        wait for (T/2);
    end process clk_process;

    n_rst_process: process
    begin
        tb_n_rst <= '1';
        wait for (T);
        tb_n_rst <= '0';
        wait for (T);
        tb_n_rst <= '1';
        wait;
    end process n_rst_process;

end architecture rtl;