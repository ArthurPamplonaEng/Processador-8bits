-- ===============================================
--  Componente: Banco de Registradores (CORRIGIDO)
--  Separa a escrita dos GPRs (A,B,C) da escrita
--  dos Registradores Especiais (PC, RIH, RIL, FLAGS)
-- ===============================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity register_file is
    Port (
        clk           : in  std_logic;
        rst           : in  std_logic;
        
        -- ==================================================
        -- PORTAS DE ESCRITA (Write-Back) PARA GPRs (A, B, C)
        -- ==================================================
        -- Conectado ao MUX_WriteBack (ULA/Mem)
        gpr_write_enable  : in  std_logic;                        
        gpr_reg_select    : in  std_logic_vector(3 downto 0); -- Endereço do Rd (A, B ou C)
        gpr_data_in       : in  std_logic_vector(7 downto 0); -- Resultado da ULA/Mem
        
        -- ==================================================
        -- PORTAS DE ESCRITA PARA REGISTRADORES ESPECIAIS
        -- ==================================================
        pc_write_enable   : in  std_logic;
        pc_data_in        : in  std_logic_vector(7 downto 0); -- Vindo do MUX do PC (PC+1 ou Jump)
        
        rih_write_enable  : in  std_logic;
        rih_data_in       : in  std_logic_vector(7 downto 0); -- Vindo da ROM (Opcode)
        
        ril_write_enable  : in  std_logic;
        ril_data_in       : in  std_logic_vector(7 downto 0); -- Vindo da ROM (Argumentos)
        
        flags_write_enable: in  std_logic;
        flags_data_in     : in  std_logic_vector(7 downto 0); -- Vindo da ULA (Flags)

        -- ==================================================
        -- PORTAS DE LEITURA (Para ULA)
        -- ==================================================
        read_sel_A    : in  std_logic_vector(3 downto 0);     
        read_sel_B    : in  std_logic_vector(3 downto 0);     
        data_out_A    : out std_logic_vector(7 downto 0);     
        data_out_B    : out std_logic_vector(7 downto 0);     
        
        -- ==================================================
        -- SAIDAS DIRETAS (Para CU, PC, etc.)
        -- ==================================================
        rih_out       : out std_logic_vector(7 downto 0);
        ril_out       : out std_logic_vector(7 downto 0);
        flags_out     : out std_logic_vector(7 downto 0);
        pc_out        : out std_logic_vector(7 downto 0);
        
        -- ===== SAIDAS DE DEBUG =====
        r0_dbg, r1_dbg, r2_dbg, r3_dbg,
        r4_dbg, r5_dbg, r6_dbg, r7_dbg : out std_logic_vector(7 downto 0)
    );
end register_file;

architecture Behavioral of register_file is

    -- REGISTRADORES INTERNOS (O hardware real)
    signal A_reg, B_reg, C_reg     : std_logic_vector(7 downto 0) := (others => '0');
    signal RIH_reg, RIL_reg    : std_logic_vector(7 downto 0) := (others => '0');
    signal PC_reg, FLAGS_reg   : std_logic_vector(7 downto 0) := (others => '0');

begin

    -- ===============================
    --  LOGICA DE ESCRITA SINCRONA (CORRIGIDA)
    -- ===============================
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                A_reg     <= (others => '0');
                B_reg     <= (others => '0');
                C_reg     <= (others => '0');
                RIH_reg   <= (others => '0');
                RIL_reg   <= (others => '0');
                PC_reg    <= (others => '0');
                FLAGS_reg <= (others => '0');
            else
                -- 1. Lógica de Escrita dos GPRs (A, B, C)
                --    Vem do MUX_WriteBack (ULA ou Memória)
                if gpr_write_enable = '1' then
                    case gpr_reg_select is
                        when "0000" => A_reg <= gpr_data_in; -- R0
                        when "0001" => B_reg <= gpr_data_in; -- R1
                        when "0010" => C_reg <= gpr_data_in; -- R2
                        when others => null; -- Ignora escrita em RIH, RIL, PC, etc.
                    end case;
                end if;
                
                -- 2. Lógica de Escrita do PC (Independente)
                if pc_write_enable = '1' then
                    PC_reg <= pc_data_in;
                end if;
                
                -- 3. Lógica de Escrita do RIH (Independente)
                if rih_write_enable = '1' then
                    RIH_reg <= rih_data_in;
                end if;
                
                -- 4. Lógica de Escrita do RIL (Independente)
                if ril_write_enable = '1' then
                    RIL_reg <= ril_data_in;
                end if;
                
                -- 5. Lógica de Escrita dos FLAGS (Independente)
                if flags_write_enable = '1' then
                    FLAGS_reg <= flags_data_in;
                end if;
            end if;
        end if;
    end process;

    -- ===============================
    --  LOGICA DE LEITURA ASSINCRONA (Estava correta)
    -- ===============================
    with read_sel_A select
        data_out_A <= A_reg     when "0000",
                      B_reg     when "0001",
                      C_reg     when "0010",
                      RIH_reg   when "0011",
                      RIL_reg   when "0100",
                      PC_reg    when "0101",
                      FLAGS_reg when "0110",
                      (others => '0') when others;

    with read_sel_B select
        data_out_B <= A_reg     when "0000",
                      B_reg     when "0001",
                      C_reg     when "0010",
                      RIH_reg   when "0011",
                      RIL_reg   when "0100",
                      PC_reg    when "0101",
                      FLAGS_reg when "0110",
                      (others => '0') when others;

    -- ===============================
    -- SAIDAS DIRETAS (Estava correta)
    -- ===============================
    pc_out    <= PC_reg;
    flags_out <= FLAGS_reg;
    rih_out   <= RIH_reg;
    ril_out   <= RIL_reg;
    
    -- ===============================
    --  SAIDAS DE DEPURACAO (DEBUG)
    -- ===============================
    r0_dbg <= A_reg;  -- R0
    r1_dbg <= B_reg;  -- R1
    r2_dbg <= C_reg;  -- R2
    r3_dbg <= RIH_reg; -- RIH
    r4_dbg <= RIL_reg; -- RIL
    r5_dbg <= PC_reg;  -- PC
    r6_dbg <= FLAGS_reg; -- FLAGS
    r7_dbg <= (others => '0'); -- Reservado / livre


end Behavioral;