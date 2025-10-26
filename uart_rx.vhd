----------------------------------------------------------------------------------
-- Company: CEPEDI
-- Engineer: Gabriel Cavalcanti Coelho
-- Create Date: 10.10.2025
-- Module Name: uart_rx
----------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.uart_pkg.all;

entity uart_rx is
    generic (
        g_OVERSAMPLE : positive := 16;      -- Fator de oversampling, define quantos ciclos de clock duram um bit na transmissão (quanto maior mais preciso)
        g_DATA_BITS  : positive := 8;       -- Número de bits de dados a serem transmitidos
        g_PARITY_BIT : parity_type := EVEN; -- Tipo de paridade: "NONE" (nenhuma), "EVEN" (par) ou "ODD" (ímpar)
        g_STOP_BITS  : stop_type := ONE_BIT -- Número de stop bits: "ONE_BIT" ou "TWO_BITS"
    );
    port (
        i_baud  : in  std_logic;                                -- Clock do UART
        i_n_rst : in  std_logic;                                -- Reset síncrono, ativo em nível lógico baixo ('0')
        i_rx    : in  std_logic;                                -- Linha de recepção serial
        o_data  : out std_logic_vector(g_DATA_BITS-1 downto 0); -- Bits de dados recebidos pela linha serial
        o_valid : out std_logic;                                -- Pulso de um ciclo indicando que 'o_data' contém um novo dado lido e válido
        o_ready : out std_logic                                 -- Sinaliza que o receptor está pronto para uma nova leitura
    );
end entity uart_rx;

architecture rtl of uart_rx is

    -- Definição e declaração dos estados da máquina de estados que controlam a leitura
    type state_type is (IDLE, START, DATA, PARITY, FIRST_STOP, LAST_STOP);
    signal state, next_state : state_type := IDLE;

    -- Registradores para os sinais de saída
    signal data_reg, next_data_reg   : std_logic_vector(g_DATA_BITS-1 downto 0) := (others => '0');
    signal ready_reg, next_ready_reg : std_logic := '1';
    signal valid_reg, next_valid_reg : std_logic := '0';

    -- Contador que conta os ciclos de i_baud para determinar a duração de um bit na transmissão UART
    signal baud_cnt, next_baud_cnt : integer range 0 to g_OVERSAMPLE-1 := 0;

    -- Contador que controla qual bit de dado está sendo recebido
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
                data_reg <= (others => '0');
                ready_reg <= '1';
                valid_reg <= '0';
                baud_cnt <= 0;
                bit_cnt <= 0;
                parity_reg <= '0';
            else -- Lógica de atualização de estado
                state <= next_state;
                data_reg <= next_data_reg;
                ready_reg <= next_ready_reg;
                valid_reg <= next_valid_reg;
                baud_cnt <= next_baud_cnt;
                bit_cnt <= next_bit_cnt;
                parity_reg <= next_parity_reg;
            end if;
        end if;
    end process sync_process;

    -- Processo combinacional (lógica do próximo estado)
    comb_process: process(i_rx, state, data_reg, ready_reg, valid_reg, baud_cnt, bit_cnt, parity_reg)
    begin
        -- Atribuições padrões (evitam a inferência de latches)
        next_state <= state;
        next_data_reg <= data_reg;
        next_ready_reg <= ready_reg;
        next_valid_reg <= valid_reg;
        next_baud_cnt <= baud_cnt;
        next_bit_cnt <= bit_cnt;
        next_parity_reg <= parity_reg;
        case(state) is
            when IDLE => -- Estado IDLE: O receptor está ocioso, monitorando a linha e esperando por um start bit ('0')
                next_ready_reg <= '1';
                next_valid_reg <= '0';
                if (i_rx = '0') then -- Se queda na linha serial, vai para o estado de verificação do start bit
                    next_ready_reg <= '0';
                    next_baud_cnt <= 0;
                    next_state <= START;
                end if;
            when START =>  -- Estado START: Verifica se o start bit é válido
                if (baud_cnt = (g_OVERSAMPLE/2)-1) then -- Aguarda metade da duração de um bit para posicionar a amostragem no centro
                    if (i_rx = '0') then -- Se, no meio do bit, a linha ainda estiver em '0', o start bit é válido e o módulo segue para a leitura dos bits de dados
                        next_baud_cnt <= 0;
                        next_bit_cnt <= 0;
                        next_parity_reg <= '0';
                        next_state <= DATA;
                    else -- Se a linha voltou para '1', foi um ruído, então volta para o estado IDLE
                        next_state <= IDLE;
                    end if;
                else
                    next_baud_cnt <= baud_cnt + 1; -- Incrementa o contador de clock
                end if;
            when DATA => -- Estado DATA: Recebe os bits de dados
                if (baud_cnt = g_OVERSAMPLE-1) then -- Aguarda a duração de um bit completo (o sampling ainda se mantém no meio)
                    next_data_reg(bit_cnt) <= i_rx;         -- Amostra e armazena o bit
                    next_parity_reg <= parity_reg xor i_rx; -- Atualiza o cálculo da paridade
                    next_baud_cnt <= 0;
                    if (bit_cnt = g_DATA_BITS-1) then -- Se foi o último bit de dados segue para o bit de paridade ou para o(s) bit(s) de parada
                        if (g_PARITY_BIT = NONE) then
                            if (g_STOP_BITS = ONE_BIT) then
                                next_state <= LAST_STOP;
                            else
                                next_state <= FIRST_STOP;
                            end if;
                        else
                            next_state <= PARITY;
                        end if;
                    else
                        next_bit_cnt <= bit_cnt + 1; -- Avança para o próximo bit de dados
                    end if;
                else
                    next_baud_cnt <= baud_cnt + 1; -- Incrementa o contador de clock
                end if;
            when PARITY => -- Estado PARITY: Verifica o bit de paridade
                if (baud_cnt = g_OVERSAMPLE-1) then -- Aguarda a duração de um bit completo para posicionar o sampling
                    next_baud_cnt <= 0;
                    -- Compara a paridade calculada (parity_reg) com a recebida (i_rx)
                    -- Se houver erro, a recepção é abortada e retorna para IDLE, senão segue para o(s) bit(s) de parada
                    if (g_PARITY_BIT = ODD) then 
                        if (not(parity_reg) = i_rx) then
                            if (g_STOP_BITS = ONE_BIT) then
                                next_state <= LAST_STOP;
                            else
                                next_state <= FIRST_STOP;
                            end if;
                        else
                            next_state <= IDLE;
                        end if;
                    end if;
                    if (g_PARITY_BIT = EVEN) then
                        if (parity_reg = i_rx) then
                            if (g_STOP_BITS = ONE_BIT) then
                                next_state <= LAST_STOP;
                            else
                                next_state <= FIRST_STOP;
                            end if;
                        else
                            next_state <= IDLE;
                        end if;
                    end if;
                else
                    next_baud_cnt <= baud_cnt + 1;
                end if;
            when FIRST_STOP => -- Estado FIRST_STOP: Verifica o primeiro stop bit (para o caso de 2 stop bits)
                if (baud_cnt = g_OVERSAMPLE-1) then -- Posiciona o sampling e verifica se é um stop bit
                    next_baud_cnt <= 0;
                    if (i_rx = '1') then
                        next_state <= LAST_STOP;
                    else
                        next_state <= IDLE;
                    end if;
                else
                    next_baud_cnt <= baud_cnt + 1;
                end if;
            when LAST_STOP => -- Estado LAST_STOP: Verifica o último (ou único) stop bit e ativa o pulso de validade (o_valid) ou não
                if (baud_cnt = g_OVERSAMPLE-1) then -- Posiciona o sampling e verifica se é um stop bit
                    if (i_rx = '1') then
                        next_valid_reg <= '1'; -- Caso seja um stop bit, leva o o_valid para nível lógico alto
                    end if;
                    next_state <= IDLE; -- Se houver erro de framing, volta para o IDLE
                else
                    next_baud_cnt <= baud_cnt + 1;
                end if;
        end case;
    end process comb_process;

    -- Mapeamento das saídas
    o_data <= data_reg;
    o_valid <= valid_reg;
    o_ready <= ready_reg;

end architecture rtl;