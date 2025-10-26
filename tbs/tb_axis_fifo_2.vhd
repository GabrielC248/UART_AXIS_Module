library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_axis_fifo_2 is
end entity tb_axis_fifo_2;

architecture behavior of tb_axis_fifo_2 is

    -- Constantes do Testbench
    constant c_DATA_WIDTH : natural := 8;
    constant c_DEPTH      : natural := 16;
    constant T            : time    := 10 ns; -- Clock de 100 MHz

    -- Sinais globais
    signal clk   : std_logic := '0';
    signal n_rst : std_logic := '0';

    -- Sinais para a entrada da FIFO
    signal s_axis_tdata  : std_logic_vector(c_DATA_WIDTH - 1 downto 0);
    signal s_axis_tvalid : std_logic := '0';
    signal s_axis_tready : std_logic;

    -- Sinais para a saída da FIFO
    signal m_axis_tdata  : std_logic_vector(c_DATA_WIDTH - 1 downto 0);
    signal m_axis_tvalid : std_logic;
    signal m_axis_tready : std_logic := '0';

begin

    -- Instanciação das FIFOs
    fifo_1 : entity work.axis_fifo -- work.axis_fifo / work.fifo_design_wrapper
        generic map (
            g_DATA_WIDTH => c_DATA_WIDTH,
            g_DEPTH      => c_DEPTH
        )
        port map (
            i_clk           => clk,
            i_n_rst         => n_rst,
            i_s_axis_tdata  => s_axis_tdata,
            i_s_axis_tvalid => s_axis_tvalid,
            o_s_axis_tready => s_axis_tready,
            o_m_axis_tdata  => m_axis_tdata,
            o_m_axis_tvalid => m_axis_tvalid,
            i_m_axis_tready => m_axis_tready  
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

    -- Teste Básico
    test_proc: process
        variable data_to_write : unsigned(c_DATA_WIDTH - 1 downto 0);
    begin
        -- Aguarda um tempo após o reset
        s_axis_tvalid <= '0';
        s_axis_tdata  <= (others => '0');
        m_axis_tready <= '0';
        wait for 8*T;
        
        -- Preenche a FIFO
        for i in 0 to 15 loop
            data_to_write := to_unsigned(15 + i, c_DATA_WIDTH);
            s_axis_tdata  <= std_logic_vector(data_to_write);
            s_axis_tvalid <= '1';
            wait for T;
        end loop;
        s_axis_tdata  <= (others => '0');
        s_axis_tvalid <= '0';

        -- Espera um pouco
        wait for 4*T;

        -- Lê todos os dados da FIFO
        for i in 0 to 15 loop
            m_axis_tready <= '1';
            wait for T;
        end loop;
        m_axis_tready <= '0';

        -- Espera um pouco
        wait for 4*T;

        -- Escreve o dado "4" na FIFO
        data_to_write := to_unsigned(4, c_DATA_WIDTH);
        s_axis_tdata  <= std_logic_vector(data_to_write);
        s_axis_tvalid <= '1';
        wait for T;
        s_axis_tvalid <= '0';
        s_axis_tdata  <= (others => '0');

        -- Espera um pouco
        wait for 4*T;

        -- Escreve o dado "5" e realiza uma leitura ao mesmo tempo
        data_to_write := to_unsigned(5, c_DATA_WIDTH);
        s_axis_tdata  <= std_logic_vector(data_to_write);
        s_axis_tvalid <= '1';
        m_axis_tready <= '1';
        wait for T;
        s_axis_tdata  <= (others => '0');
        s_axis_tvalid <= '0';
        m_axis_tready <= '0';

        wait;

    end process test_proc;

end architecture behavior;