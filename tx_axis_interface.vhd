----------------------------------------------------------------------------------
-- Company: CEPEDI
-- Engineer: Gabriel Cavalcanti Coelho
-- Create Date: 10.10.2025
-- Module Name: tx_axis_interface
----------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.uart_pkg.all;

entity tx_axis_interface is
    generic (
        g_DATA_BITS  : positive := 8 -- Número de bits de dados
    );
    port (
        i_clk         : in  std_logic;                                 -- Clock de sistema
        i_n_rst       : in  std_logic;                                 -- Reset síncrono, ativo em nível lógico baixo ('0')
        i_tx_ready    : in  std_logic;                                 -- Sinal que indica que o TX está pronto
        o_tx_data     : out std_logic_vector(g_DATA_BITS-1 downto 0);  -- Dado enviado para o TX
        o_tx_valid    : out std_logic;                                 -- Sinal que indica que o TX deve enviar
        i_axis_tdata  : in  std_logic_vector(g_DATA_BITS-1 downto 0);  -- Dado a ser transimitido
        i_axis_tvalid : in  std_logic;                                 -- Sinal de entrada para o hand-shake
        o_axis_tready : out std_logic                                  -- Sinal de saída para o hand-shake
    );
end entity tx_axis_interface;

architecture rtl of tx_axis_interface is

    -- Definição e declaração dos estados da máquina de estados
    type state_type is (VALID, TRIM);
    signal state, next_state : state_type := VALID;

    -- Registradores internos para os sinais de saída
    signal tx_data : std_logic_vector(g_DATA_BITS-1 downto 0) := (others => '0');
    signal axis_tready, next_axis_tready : std_logic := '0';

begin

    -- Processo síncrono que atualiza o estado e os registradores na borda de subida do clock
    sync_proc: process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_n_rst = '0' then
                state <= VALID;
                tx_data <= (others => '0');
                axis_tready <= '0';
            else
                state <= next_state;
                tx_data <= i_axis_tdata;
                axis_tvalid <= next_axis_tvalid;
            end if;
        end if;
    end process sync_proc;

    -- Processo combinacional da lógica de próximo estado e das saídas
    comb_proc: process(state, axis_tvalid, i_rx_valid, i_axis_tready)
    begin
        next_state <= state;
        next_axis_tvalid <= '0';
        case(state) is
            when VALID => -- Estado VALID: Aguarda o sinal válido do RX e prontidão do hand-shake axis
                if (i_rx_valid = '1') then
                    if (i_axis_tready = '1') then
                        next_axis_tvalid <= '1'; -- Eleva o axis valid para o nível lógico alto por um ciclo de clock do sistema
                        next_state <= TRIM;
                    end if;
                end if;
            when TRIM => -- Estado TRIM: Garante que o mesmo pulso de i_rx_valid não seja processado mais vezes
                if (i_rx_valid = '0') then
                    next_state <= VALID;
                end if;
        end case ;
    end process comb_proc;
    
    -- Conecta os registradores internos às portas de saída
    o_axis_tdata <= rx_data;
    o_axis_tvalid <= axis_tvalid;

end architecture rtl;