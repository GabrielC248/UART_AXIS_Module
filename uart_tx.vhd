----------------------------------------------------------------------------------
-- Company: CEPEDI
-- Engineer: Gabriel Cavalcanti Coelho
-- Create Date: 23.09.2025
-- Module Name: uart_tx
----------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.uart_pkg.all;

entity uart_tx is
    generic (
        g_OVERSAMPLE : positive := 16;      -- Fator de oversampling, define quantos ciclos de clock duram um bit na transmissão (quanto maior mais preciso)
        g_DATA_BITS  : positive := 8;       -- Número de bits de dados a serem transmitidos
        g_PARITY_BIT : parity_type := EVEN; -- Tipo de paridade: "NONE" (nenhuma), "EVEN" (par) ou "ODD" (ímpar)
        g_STOP_BITS  : stop_type := ONE_BIT -- Número de stop bits: "ONE_BIT" ou "TWO_BITS"
    );
    port (
        i_baud  : in  std_logic;                                -- Clock do UART
        i_n_rst : in  std_logic;                                -- Reset síncrono, ativo em nível lógico baixo ('0')
        i_valid : in  std_logic;                                -- Habilita a transmissão pelo o_tx
        i_data  : in  std_logic_vector(g_DATA_BITS-1 downto 0); -- Bits de dados a serem transmitidos
        o_tx    : out std_logic;                                -- Linha de transmissão serial
        o_ready : out std_logic                                 -- Sinaliza que o transmissor está pronto para enviar dados
    );
end entity uart_tx;

architecture rtl of uart_tx is

    -- Definição e declaração dos estados da máquina de estados que controlam a transmissão
    type state_type is (IDLE, START, DATA, PARITY, FIRST_STOP, LAST_STOP);
    signal state, next_state : state_type := IDLE;

    -- Registradores para os sinais de saída
    signal tx_reg, next_tx_reg : std_logic := '1';
    signal ready_reg, next_ready_reg : std_logic := '1';

    -- Registradores que armazenam os bits de dados da entrada (i_data) para a transmissão
    signal data_reg, next_data_reg : std_logic_vector(g_DATA_BITS-1 downto 0) := (others => '0');

    -- Contador que conta os ciclos de i_baud para determinar a duração de um bit na transmissão UART
    signal clk_cnt, next_clk_cnt : integer range 0 to g_OVERSAMPLE-1 := 0;

    -- Contador que controla qual bit de data_reg está sendo transmitido
    signal bit_cnt, next_bit_cnt : integer range 0 to g_DATA_BITS-1 := 0;

    -- Registrador para o cálculo acumulado do bit de paridade
    signal parity_reg, next_parity_reg : std_logic := '0';

begin

    -- Processo síncrono de reset e atualização de estado
    sync_process: process(i_baud)
    begin
        if rising_edge(i_baud) then
            if i_n_rst = '0' then -- Lógica de reset (síncrono)
                state <= IDLE;
                tx_reg <= '1';
                ready_reg <= '1';
                data_reg <= (others => '0');
                clk_cnt <= 0;
                bit_cnt <= 0;
                parity_reg <= '0';
            else -- Lógica de atualização de estado
                state <= next_state;
                tx_reg <= next_tx_reg;
                ready_reg <= next_ready_reg;
                data_reg <= next_data_reg;
                clk_cnt <= next_clk_cnt;
                bit_cnt <= next_bit_cnt;
                parity_reg <= next_parity_reg;
            end if;
        end if;
    end process sync_process;

    -- Processo combinacional (lógica do próximo estado)
    comb_process: process(i_valid, state, tx_reg, ready_reg, i_data, data_reg, clk_cnt, bit_cnt, parity_reg)
    begin
        -- Atribuições padrões (evitam a inferência de latches)
        next_state <= state;
        next_tx_reg <= tx_reg;
        next_ready_reg <= ready_reg;
        next_data_reg <= data_reg;
        next_clk_cnt <= clk_cnt;
        next_bit_cnt <= bit_cnt;
        next_parity_reg <= parity_reg;
        case(state) is
            when IDLE => -- Estado IDLE: O transmissor está ocioso (o_tx = '1' e o_ready = '1') e esperando habilitação (i_valid = '1')
                next_tx_reg <= '1';
                next_ready_reg <= '1';
                if i_valid = '1' then -- Se habilitado, registra os bits de dado da entrada (i_data) e prepara o início da transmissão
                    next_ready_reg <= '0';
                    next_data_reg <= i_data;
                    next_clk_cnt <= 0;
                    next_state <= START;
                end if;
            when START => -- Estado START: Envia o Start Bit ('0')
                next_tx_reg <= '0'; -- Coloca a linha de transmissão em nível lógico baixo
                if (clk_cnt = g_OVERSAMPLE-1) then -- Aguarda a duração de 1 bit
                    next_clk_cnt <= 0;      -- Reseta contador de clock
                    next_bit_cnt <= 0;      -- Reseta contador de bits transmitidos
                    next_parity_reg <= '0'; -- Reseta o cálculo da paridade
                    next_state <= DATA;
                else
                    next_clk_cnt <= clk_cnt + 1; -- Incrementa o contador de clock
                end if;
            when DATA => -- Estado DATA: Envia os bits de dados, do menos significativo (LSB) ao mais significativo (MSB)
                next_tx_reg <= data_reg(bit_cnt); -- Coloca o bit de dado atual na linha de transmissão
                if (clk_cnt = g_OVERSAMPLE-1) then
                    next_parity_reg <= parity_reg xor data_reg(bit_cnt); -- No final da janela de cada bit transmitido, realiza o cálculo da paridade
                    next_clk_cnt <= 0;
                    if (bit_cnt = g_DATA_BITS-1) then -- Verifica se todos os bits de dados foram enviados
                        if (g_PARITY_BIT = NONE) then -- Se a paridade estiver desabilitada, pula para os bits de parada
                            if (g_STOP_BITS = ONE_BIT) then
                                next_state <= LAST_STOP;
                            else
                                next_state <= FIRST_STOP;
                            end if;
                        else
                            next_state <= PARITY; -- Se houver paridade, vai para o estado PARITY
                        end if;
                    else
                        next_bit_cnt <= bit_cnt + 1; -- Se ainda houver bits de dados, avança para o próximo
                    end if;
                else
                    next_clk_cnt <= clk_cnt + 1;
                end if;
            when PARITY => -- Estado PARITY: Envia o bit de paridade
                if g_PARITY_BIT = ODD then
                    next_tx_reg <= not(parity_reg); -- Se paridade ímpar, inverte o resultado dos XORs
                else
                    next_tx_reg <= parity_reg; -- Senão, paridade par, usa o resultado dos XORs
                end if;
                if (clk_cnt = g_OVERSAMPLE-1) then -- Aguarda a duração de 1 bit e vai para o estado do tipo de parada definido
                    next_clk_cnt <= 0;
                    if (g_STOP_BITS = ONE_BIT) then
                        next_state <= LAST_STOP;
                    else
                        next_state <= FIRST_STOP;
                    end if;
                else
                    next_clk_cnt <= clk_cnt + 1;
                end if;
            when FIRST_STOP => -- Estado FIRST_STOP: Envia o primeiro Stop Bit (caso g_STOP_BITS = TWO_BITS)
                next_tx_reg <= '1';
                if (clk_cnt = g_OVERSAMPLE-1) then -- Segura o estado pela duração de 1 bit
                    next_clk_cnt <= 0;
                    next_state <= LAST_STOP;
                else
                    next_clk_cnt <= clk_cnt + 1;
                end if;
            when LAST_STOP => -- Estado LAST_STOP: Envia o último (ou único) Stop Bit
                next_tx_reg <= '1';
                if (clk_cnt = g_OVERSAMPLE-1) then -- Segura o estado pela duração de 1 bit
                    next_state <= IDLE;
                else
                    next_clk_cnt <= clk_cnt + 1;
                end if;
        end case;
    end process comb_process;

    -- Mapeamento das saídas
    o_tx <= tx_reg;
    o_ready <= ready_reg;

end architecture rtl;