-- ===============================================
--  Componente: Memória de Instrução (RAM Inicializável)
--  Tamanho: 256 endereços (0 a 255)
--  Carrega o programa a partir de "binout.txt"
-- ===============================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
-- Bibliotecas necessárias para ler arquivos de texto
use STD.TEXTIO.all;
use IEEE.STD_LOGIC_TEXTIO.all;

entity rom_memoria is
    Port (
        ADDR : in  std_logic_vector(7 downto 0); -- Endereço (0-255) vindo do PC
        DATA : out std_logic_vector(7 downto 0)  -- Dado de 8 bits (Instrução)
    );
end rom_memoria;

architecture Behavioral of rom_memoria is

    -- 1. Definição do tipo da memória
    type MEMORY_ARRAY is array (0 to 255) of std_logic_vector(7 downto 0);
    
    -- 2. A memória agora é um "signal", não uma "constant".
    --    Isso significa que ela é uma memória real (RAM) que 
    --    pode ter seus valores alterados.
    --    Nós a inicializamos com zeros.
    signal PROGRAM_MEM : MEMORY_ARRAY := (others => (others => '0'));

    -- Sinal auxiliar para o endereço
    signal s_address : integer range 0 to 255;
    
begin

    -- =========================================================
    -- PROCESSO DE CARREGAMENTO DO ARQUIVO (Apenas para Simulação)
    -- =========================================================
    -- Este 'process' roda APENAS UMA VEZ no início da simulação
    -- (antes do clock começar) para carregar o arquivo.
    LOAD_FILE: process
        -- O arquivo "binout.txt" DEVE estar na mesma pasta
        -- onde a simulação é executada.
        constant file_name : string := "binout.txt";
        
        -- Variáveis para manipulação do arquivo
        file F           : TEXT open READ_MODE is file_name;
        variable L       : LINE; -- Uma linha do arquivo de texto
        variable V       : std_logic_vector(7 downto 0); -- O valor binário lido
        variable i       : integer := 0; -- O endereço da memória (contador)
    begin
        -- Loop: "enquanto não for o fim do arquivo"
        while not endfile(F) loop
            
            -- 1. Lê uma linha do arquivo (ex: "01000001")
            readline(F, L);
            
            -- 2. Checa se a linha não está vazia
            if L'length > 0 then
                
                -- 3. Converte o TEXTO da linha para std_logic_vector
                read(L, V);
                
                -- 4. Armazena o valor lido na nossa memória interna
                PROGRAM_MEM(i) <= V;
                
                -- 5. Avança para o próximo endereço da memória
                i := i + 1;
            end if;
            
            -- Para o loop se o arquivo for maior que a memória
            if i > 255 then
                report "Aviso: 'binout.txt' é maior que 256 linhas. Interrompendo leitura." severity warning;
                exit; -- Sai do loop 'while'
            end if;
            
        end loop;
        
        -- 6. O processo "espera" para sempre. Ele nunca mais será executado.
        wait;
        
    end process LOAD_FILE;


    -- =========================================================
    -- LOGICA DE LEITURA (O Hardware Real)
    -- =========================================================
    -- Esta parte do código descreve o hardware que será sintetizado.
    
    -- 1. Converte o endereço de entrada (vetor de bits) para um número inteiro
    s_address <= to_integer(unsigned(ADDR));
    
    -- 2. Lê a memória de forma ASSINCRONA.
    --    (Sempre que 's_address' mudar, 'DATA' é atualizado imediatamente)
    DATA <= PROGRAM_MEM(s_address);
    
end Behavioral;