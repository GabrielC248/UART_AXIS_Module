----------------------------------------------------------------------------------
-- Company: CEPEDI
-- Engineer: Gabriel Cavalcanti Coelho
-- Create Date: 23.09.2025
-- Module Name: uart_pkg
----------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

package uart_pkg is
    
    type parity_type is (NONE, EVEN, ODD); -- Define os tipos de paridade do protocolo UART
    type stop_type is (ONE_BIT, TWO_BITS); -- Define os tipos de bits de parada do protocolo UART
    
end package uart_pkg;