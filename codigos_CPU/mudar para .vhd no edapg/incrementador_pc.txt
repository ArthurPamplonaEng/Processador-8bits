-- ===============================================
--  Componente: Incrementador de PC (8 bits)
-- ===============================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL; -- Necessário para aritmética

entity incrementador_pc is
    Port (
        PC_IN  : in  std_logic_vector(7 downto 0);
        PC_OUT : out std_logic_vector(7 downto 0)
    );
end incrementador_pc;

architecture Behavioral of incrementador_pc is
begin
    -- Converte para 'unsigned' para somar, e depois converte de volta
    PC_OUT <= std_logic_vector(unsigned(PC_IN) + 1);
end Behavioral;