-- ===============================================
-- Testbench do Processador (com registradores visíveis)
-- ===============================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity testbench is
end entity;

architecture Behavioral of testbench is

    -- Sinais do processador
    signal clk : std_logic := '0';
    signal rst : std_logic := '0';

    -- Sinais de debug dos registradores
    signal r0_dbg, r1_dbg, r2_dbg, r3_dbg,
           r4_dbg, r5_dbg, r6_dbg, r7_dbg : std_logic_vector(7 downto 0);

begin

    -- Instância do processador
    -- (Certifique-se que seu processador se chama 'design')
    uut: entity work.design
        port map (
            clk => clk,
            rst => rst,
            r0_dbg => r0_dbg,
            r1_dbg => r1_dbg,
            r2_dbg => r2_dbg,
            r3_dbg => r3_dbg,
            r4_dbg => r4_dbg,
            r5_dbg => r5_dbg,
            r6_dbg => r6_dbg,
            r7_dbg => r7_dbg
        );

    -- Geração do clock
    clk_process: process
    begin
        clk <= '0';
        wait for 10 ns;
        clk <= '1';
        wait for 10 ns;
    end process;

    -- Estímulo de reset
    stimulus: process
    begin
        report "==== INICIANDO SIMULACAO DO PROCESSADOR ====";
        rst <= '1';
        wait for 30 ns;
        rst <= '0';
        wait for 400 ns;
        report "==== SIMULACAO FINALIZADA ====";
        wait;
    end process;

end architecture;