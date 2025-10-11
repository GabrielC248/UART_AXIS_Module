----------------------------------------------------------------------------------
-- Company: CEPEDI
-- Engineer: Gabriel Cavalcanti Coelho
-- Create Date: 23.09.2025
-- Module Name: uart_baud_ticker
----------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.math_real.all;

entity uart_baud_ticker is
    generic (
        g_CLOCK      : positive := 25000000; -- Frequência do clock de entrada em Hz
        g_BAUDRATE   : positive := 115200;   -- Baudrate desejado para a comunicação UART
        g_OVERSAMPLE : positive := 16        -- Fator de oversampling usado nos módulos UART
    );
    port (
        i_clk       : in  std_logic; -- Entrada do clock de sistema
        i_n_rst     : in  std_logic; -- Reset síncrono, ativo em nível lógico baixo ('0')
        o_baud_tick : out std_logic  -- Saída de um pulso ('tick'), ativa por um ciclo na frequência desejada
    );
end entity uart_baud_ticker;

architecture rtl of uart_baud_ticker is

    -- Constante que calcula o fator de divisão necessário
    constant DIV : natural := natural(round(real(g_CLOCK)/real(g_BAUDRATE*g_OVERSAMPLE)));

    -- Sinal do contador que conta os ciclos do clock principal (i_clk)
    signal counter_reg : natural range 0 to DIV-1 := 0;

    -- Sinal que armazena o estado do pulso de saída
    signal baud_tick_reg : std_logic := '0';

begin

    -- Processo síncrono que implementa a lógica de geração do pulso
    counter_proc: process(i_clk)
    begin
        if rising_edge(i_clk) then
            if (i_n_rst = '0') then -- Lógica de reset síncrono
                counter_reg <= 0;
                baud_tick_reg <= '1'; -- O tick é resetado em '1', para que o reset síncrono dos módulos tx e rx também aconteçam
            else -- Lógica de contagem
                if (counter_reg = DIV-1) then
                    counter_reg <= 0;
                    baud_tick_reg <= '1';
                else
                    counter_reg <= counter_reg + 1;
                    baud_tick_reg <= '0';
                end if;
            end if;
        end if;
    end process counter_proc;

    -- Conecta o registrador à saída
    o_baud_tick <= baud_tick_reg;

end architecture rtl;