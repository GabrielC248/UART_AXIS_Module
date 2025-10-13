library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.uart_pkg.all;

-- ESSA SIMULAÇÃO PRECISA DE NO MÍNIMO 100 us!!!

entity tb_rx_axis_interface is
end entity tb_rx_axis_interface;

architecture rtl of tb_rx_axis_interface is

    constant T : time := 40 ns;
    constant B : time := 271*16 ns; -- Périodo do baud tick esperado vezes o oversample

    -- Sinais do baud ticker
    signal tb_clk       : std_logic := '0';
    signal tb_n_rst     : std_logic := '0';
    signal tb_baud_tick : std_logic;

    -- Sinais do módulo RX
    signal tb_rx       : std_logic := '1';
    signal tb_rx_data  : std_logic_vector(7 downto 0);
    signal tb_rx_valid : std_logic;
    signal tb_rx_ready : std_logic;

    -- Sinais da interface
    signal axis_tdata : std_logic_vector(7 downto 0);
    signal axis_tvalid : std_logic;

begin
    
    baud_unit : entity work.uart_baud_ticker
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

    rx_unit : entity work.uart_rx
        generic map (
            g_OVERSAMPLE => 16,
            g_DATA_BITS  => 8,
            g_PARITY_BIT => EVEN,
            g_STOP_BITS  => ONE_BIT
        )
        port map (
            i_baud  => tb_baud_tick,
            i_n_rst => tb_n_rst,
            i_rx    => tb_rx,
            o_data  => tb_rx_data,
            o_valid => tb_rx_valid,
            o_ready => tb_rx_ready
        );

    uut : entity work.rx_axis_interface
        generic map (
            g_DATA_BITS => 8
        )
        port map (
        i_clk         => tb_clk,
        i_n_rst       => tb_n_rst,
        i_rx_data     => tb_rx_data,
        i_rx_valid    => tb_rx_valid,
        i_axis_tready => '1',
        o_axis_tdata  => axis_tdata,
        o_axis_tvalid => axis_tvalid
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

    stim_process: process
    begin
        tb_rx <= '1';
        wait for (4*T);

        -- DATA (01010101)
        tb_rx <= '0'; -- START BIT
        wait for (B);
        tb_rx <= '1'; -- DATA BIT 7
        wait for (B); 
        tb_rx <= '0'; -- DATA BIT 6
        wait for (B);
        tb_rx <= '1'; -- DATA BIT 5
        wait for (B);
        tb_rx <= '0'; -- DATA BIT 4
        wait for (B);
        tb_rx <= '1'; -- DATA BIT 3
        wait for (B);
        tb_rx <= '0'; -- DATA BIT 2
        wait for (B);
        tb_rx <= '1'; -- DATA BIT 1
        wait for (B);
        tb_rx <= '0'; -- DATA BIT 0
        wait for (B);
        tb_rx <= '0'; -- PARITY BIT
        wait for (B);
        tb_rx <= '1'; -- STOP BIT
        wait for (B);

        -- DATA (10101010)
        tb_rx <= '0'; -- START BIT
        wait for (B);
        tb_rx <= '0'; -- DATA BIT 7
        wait for (B); 
        tb_rx <= '1'; -- DATA BIT 6
        wait for (B);
        tb_rx <= '0'; -- DATA BIT 5
        wait for (B);
        tb_rx <= '1'; -- DATA BIT 4
        wait for (B);
        tb_rx <= '0'; -- DATA BIT 3
        wait for (B);
        tb_rx <= '1'; -- DATA BIT 2
        wait for (B);
        tb_rx <= '0'; -- DATA BIT 1
        wait for (B);
        tb_rx <= '1'; -- DATA BIT 0
        wait for (B);
        tb_rx <= '0'; -- PARITY BIT
        wait for (B);
        tb_rx <= '1'; -- STOP BIT
        wait for (B);

        wait; -- END

    end process stim_process;

end architecture rtl;