----------------------------------------------------------------------------------
-- Company: CEPEDI
-- Engineer: Gabriel Cavalcanti Coelho
-- Create Date: 16.10.2025
-- Module Name: axis_fifo
----------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity axis_fifo is
    generic (
        g_DATA_WIDTH : natural := 8; -- Largura da palavra de dados em bits
        g_DEPTH      : natural := 16 -- Profundidade da FIFO (número de palavras)
    );
    port (
        -- Sinais Globais
        i_clk   : in  std_logic; -- Clock global
        i_n_rst : in  std_logic; -- Reset síncrono, ativo em baixo

        -- Interface AXIS de Escrita (Slave)
        i_s_axis_tdata  : in  std_logic_vector(g_DATA_WIDTH - 1 downto 0);
        i_s_axis_tvalid : in  std_logic;
        o_s_axis_tready : out std_logic;

        -- Interface AXIS de Leitura (Master)
        o_m_axis_tdata  : out std_logic_vector(g_DATA_WIDTH - 1 downto 0);
        o_m_axis_tvalid : out std_logic;
        i_m_axis_tready : in  std_logic
    );
end entity axis_fifo;

-- Arquitetura da FIFO
architecture rtl of axis_fifo is

    -- Tipo para a memória interna da FIFO
    type mem_type is array (0 to g_DEPTH-1) of std_logic_vector(g_DATA_WIDTH-1 downto 0);

    -- Sinais internos
    signal mem        : mem_type;                          -- A memória interna
    signal wr_ptr     : natural range 0 to g_DEPTH-1 := 0; -- Ponteiro de escrita
    signal rd_ptr     : natural range 0 to g_DEPTH-1 := 0; -- Ponteiro de leitura
    signal data_count : natural range 0 to g_DEPTH   := 0; -- Contador de elementos (precisa de um bit a mais para contar até g_DEPTH)
    
    -- Registradores para as Saídas
    signal axis_tdata_reg  : std_logic_vector(g_DATA_WIDTH - 1 downto 0);
    signal axis_tvalid_reg : std_logic := '0';

    -- Sinais internos para os flags de cheio/vazio
    signal fifo_full  : std_logic;
    signal fifo_empty : std_logic;

    -- Sinais para o handshake
    signal wr_en : std_logic; -- Habilita a escrita na memória
    signal rd_en : std_logic; -- Habilita a leitura da memória
    
begin

    -- ---------------- Processo de Escrita - I ----------------
    write_process: process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_n_rst = '0' then
                wr_ptr <= 0;
            else
                if wr_en = '1' then
                    -- Escreve o dado na posição do ponteiro de escrita
                    mem(wr_ptr) <= i_s_axis_tdata;
                    -- Incrementa o ponteiro de escrita, com wrap-around
                    if wr_ptr = g_DEPTH-1 then
                        wr_ptr <= 0;
                    else
                        wr_ptr <= wr_ptr+1;
                    end if;
                end if;
            end if;
        end if;
    end process write_process;

    -- ---------------- Processo de Leitura - I ----------------

    read_process: process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_n_rst = '0' then
                rd_ptr <= 0;
            else
                -- Lógica para o ponteiro de leitura
                if rd_en = '1' then
                    -- Incrementa o ponteiro de leitura, com wrap-around
                    if rd_ptr = g_DEPTH-1 then
                        rd_ptr <= 0;
                    else
                        rd_ptr <= rd_ptr+1;
                    end if;
                end if;

                -- Saídas Registradas
                axis_tdata_reg <= mem(rd_ptr);
                axis_tvalid_reg <= not fifo_empty;

            end if;
        end if;
    end process read_process;

    -- ---------------- Processo do Contador - I ----------------
    counter_process: process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_n_rst = '0' then
                data_count <= 0;
            else
                -- Se wr_en e rd_en forem ambos '1' ou ambos '0', o contador não muda
                if wr_en = '1' and rd_en = '0' then -- Apenas escrita
                    data_count <= data_count + 1;
                elsif wr_en = '0' and rd_en = '1' then -- Apenas leitura
                    data_count <= data_count - 1;
                end if;

            end if;
        end if;
    end process counter_process;

    -- ---------------- Lógica de Handshake e Flags - I ----------------

    -- Definição das flags a partir do contador
    fifo_full  <= '1' when data_count = g_DEPTH else '0';
    fifo_empty <= '1' when data_count = 0       else '0';

    -- A escrita ocorre quando o lado Slave tem dados válidos e a FIFO está pronta
    wr_en <= i_s_axis_tvalid and not fifo_full;
    -- A leitura ocorre quando o lado Master está pronto e a FIFO tem dados válidos
    rd_en <= i_m_axis_tready and not fifo_empty;

    -- A FIFO está pronta para receber dados se não estiver cheia
    o_s_axis_tready <= not fifo_full;

    -- Liga o dado de saída. O dado lido é sempre o que está no endereço rd_ptr
    o_m_axis_tdata <= mem(rd_ptr);
    -- A FIFO tem dados válidos para enviar se não estiver vazia
    o_m_axis_tvalid <= not fifo_empty;

end architecture rtl;