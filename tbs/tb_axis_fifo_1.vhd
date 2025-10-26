library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_axis_fifo_1 is
end entity tb_axis_fifo_1;

architecture behavior of tb_axis_fifo_1 is

    -- Constantes do Testbench
    constant c_DATA_WIDTH : natural := 8;
    constant c_DEPTH      : natural := 16;
    constant T            : time    := 10 ns; -- Clock de 100 MHz

    -- Sinais globais
    signal clk   : std_logic := '0';
    signal n_rst : std_logic := '0';

    -- Sinais para a entrada da FIFO 1 (gerados pelo estímulo)
    signal s_axis_tdata_1  : std_logic_vector(c_DATA_WIDTH - 1 downto 0);
    signal s_axis_tvalid_1 : std_logic := '0';
    signal s_axis_tready_1 : std_logic;

    -- Sinais para a conexão entre FIFO 1 e FIFO 2
    signal inter_fifo_tdata  : std_logic_vector(c_DATA_WIDTH - 1 downto 0);
    signal inter_fifo_tvalid : std_logic;
    signal inter_fifo_tready : std_logic;

    -- Sinais para a saída da FIFO 2 (consumidos pelo verificador)
    signal m_axis_tdata_2  : std_logic_vector(c_DATA_WIDTH - 1 downto 0);
    signal m_axis_tvalid_2 : std_logic;
    signal m_axis_tready_2 : std_logic := '0';

begin

    -- Instanciação dos Componentes
    -- FIFO 1: Recebe dados do processo de estímulo e os envia para a FIFO 2
    fifo_1 : entity work.axis_fifo -- work.axis_fifo // work.fifo_design_wrapper
        generic map (
            g_DATA_WIDTH => c_DATA_WIDTH,
            g_DEPTH      => c_DEPTH
        )
        port map (
            i_clk           => clk,
            i_n_rst         => n_rst,
            i_s_axis_tdata  => s_axis_tdata_1,
            i_s_axis_tvalid => s_axis_tvalid_1,
            o_s_axis_tready => s_axis_tready_1,
            o_m_axis_tdata  => inter_fifo_tdata,  -- Saída Master
            o_m_axis_tvalid => inter_fifo_tvalid, -- Saída Master
            i_m_axis_tready => inter_fifo_tready  -- Saída Master
        );
        
    -- FIFO 2: Recebe dados da FIFO 1 e os envia para o processo de verificação
    fifo_2 : entity work.axis_fifo -- work.axis_fifo // work.fifo_design_wrapper
        generic map (
            g_DATA_WIDTH => c_DATA_WIDTH,
            g_DEPTH      => c_DEPTH
        )
        port map (
            i_clk           => clk,
            i_n_rst         => n_rst,
            i_s_axis_tdata  => inter_fifo_tdata,  -- Entrada Slave
            i_s_axis_tvalid => inter_fifo_tvalid, -- Entrada Slave
            o_s_axis_tready => inter_fifo_tready, -- Entrada Slave
            o_m_axis_tdata  => m_axis_tdata_2,
            o_m_axis_tvalid => m_axis_tvalid_2,
            i_m_axis_tready => m_axis_tready_2
        );

    -- Geradores de Clock e Reset
    clk_process: process
    begin
        clk <= '0';
        wait for (T/2);
        clk <= '1';
        wait for (T/2);
    end process clk_process;

    n_rst_process: process
    begin
        n_rst <= '0';
        wait for (T);
        n_rst <= '1';
        wait;
    end process n_rst_process;

    -- Processo de Estímulo (Escreve na FIFO 1)
    stimulus_proc : process
        variable data_to_write : unsigned(c_DATA_WIDTH - 1 downto 0);
    begin
        -- Espera o reset terminar
        s_axis_tvalid_1 <= '0';
        wait for 8*T;

        -- Loop para escrever 16 palavras de dados
        for i in 0 to 15 loop
            -- Prepara os dados e o sinal de validade
            data_to_write := to_unsigned(15 + i, c_DATA_WIDTH);
            s_axis_tdata_1  <= std_logic_vector(data_to_write);
            s_axis_tvalid_1 <= '1';
            wait for T;
        end loop;

        s_axis_tvalid_1 <= '0';
        s_axis_tdata_1  <= (others => '0');

        wait;

    end process stimulus_proc;

    -- 7. Processo de Verificação (Lê da FIFO 2)
    consumer_checker_proc : process
    begin
        -- Começa sem estar pronto para receber dados
        m_axis_tready_2 <= '0';
        wait for 28*T;

        -- Loop para ler as 16 palavras de dados
        for i in 0 to 15 loop
            -- Sinaliza que está pronto para receber
            m_axis_tready_2 <= '1';
            wait for T;
        end loop;

        m_axis_tready_2 <= '0';
        
        wait;

    end process consumer_checker_proc;

end architecture behavior;