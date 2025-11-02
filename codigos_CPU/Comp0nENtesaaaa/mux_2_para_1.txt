-- ===============================================
--  Componente: MUX 2-para-1 (8 bits)
-- ===============================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity mux_2_para_1 is
    Port (
        IN_A : in  std_logic_vector(7 downto 0); -- Entrada A (selecionada quando SEL = '0')
        IN_B : in  std_logic_vector(7 downto 0); -- Entrada B (selecionada quando SEL = '1')
        SEL  : in  std_logic;                    -- Sinal de Seleção
        OUT_S : out std_logic_vector(7 downto 0) -- Saída
    );
end mux_2_para_1;

architecture Behavioral of mux_2_para_1 is
begin
    -- Este é um MUX combinacional.
    -- O 'with..select' é uma forma elegante de escrever um MUX em VHDL.
    with SEL select
        OUT_S <= IN_A when '0',
                 IN_B when '1',
                 (others => 'X') when others; -- 'X' para valor desconhecido

end Behavioral;