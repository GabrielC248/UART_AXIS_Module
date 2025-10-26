library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.uart_pkg.all;

entity tb_uart is
end entity tb_uart;

architecture testbench of tb_uart is
    
    constant Tc  : time := 1 ns;
    constant Tb  : time := 2 ns;

    -- Sinais Gerais
    signal clk   : std_logic := '0';
    signal baud  : std_logic := '0';
    signal n_rst : std_logic := '0';

    -- Saída do baud_gen
    signal baud_tick : std_logic;

    -- Sinais módulo tx
    signal tx_valid  : std_logic := '0';
    signal tx_data   : std_logic_vector(7 downto 0) := "00000000";
    signal tx_rx     : std_logic;
    signal tx_ready  : std_logic;

    -- Sinais módulo rx
    signal rx_data  : std_logic_vector(7 downto 0);
    signal rx_valid : std_logic;
    signal rx_ready : std_logic;

begin
    
    baud_uut : entity work.uart_baud_ticker
        generic map(
            g_CLOCK      => 1000000000,
            g_BAUDRATE   => 31250000,
            g_OVERSAMPLE => 16
        )
        port map(
            -- Sinais de Controle
            i_clk       => clk,
            i_n_rst     => n_rst,
            -- Saída de Tick
            o_baud_tick => baud_tick
        );

    tx_uut : entity work.uart_tx
        generic map(
            g_OVERSAMPLE => 16,
            g_DATA_BITS  => 8,
            g_PARITY_BIT => EVEN,
            g_STOP_BITS  => ONE_BIT
        )
        port map(
            -- Sinais de Controle
            i_baud  => baud,
            i_n_rst => n_rst,
            -- Interface de Entrada
            i_valid => tx_valid,
            i_data  => tx_data,
            -- Interface de Saída
            o_tx    => tx_rx,
            o_ready => tx_ready
        );

    rx_uut : entity work.uart_rx
        generic map(
            g_OVERSAMPLE => 16,
            g_DATA_BITS  => 8,
            g_PARITY_BIT => EVEN,
            g_STOP_BITS  => ONE_BIT
        )
        port map(
            -- Sinais de Controle
            i_baud   => baud_tick,
            i_n_rst => n_rst,
            -- Interface de Entrada
            i_rx    => tx_rx,
            -- Interface de Saída
            o_data  => rx_data,
            o_valid => rx_valid,
            o_ready => rx_ready
        );

    -- Gera o clock do testbench
    clock_gen: process
    begin
        clk <= '0';
        wait for (Tc/2);
        clk <= '1';
        wait for (Tc/2);
    end process clock_gen;

    -- Gera o baudrate na frequência ideal
    baud_gen: process
    begin
        baud <= '0';
        wait for (Tb/2);
        baud <= '1';
        wait for (Tb/2);
    end process baud_gen;

    -- Acionamento do reset
    reset_gen: process
    begin
        n_rst <= '0';
        wait for (Tb);        
        n_rst <= '1';
        wait;
    end process reset_gen;

    -- Estimulos fornecidos
    stim_proc: process
    begin
        wait for (Tb);
        tx_data <= "01010101";
        tx_valid <= '1';
        wait for (Tb);
        tx_valid <= '0';
        wait for (352 ns);
        --wait until tx_ready = '1';
        --wait for(Tb);
        tx_data <= "11001100";
        tx_valid <= '1';
        wait for (Tb);
        tx_valid <= '0';
        wait;
    end process stim_proc;

end architecture testbench;