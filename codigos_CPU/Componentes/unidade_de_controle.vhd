-- ===============================================
--  UNIDADE DE CONTROLE (control_unit_FSM.vhd)
--  VERSAO CORRIGIDA (2 Processos) e COMPLETA
-- ===============================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity control_unit_FSM is
    Port (
        clk             : in  std_logic;
        rst             : in  std_logic;
        ROM_DATA_IN     : in  std_logic_vector(7 downto 0);
        FLAGS_IN        : in  std_logic_vector(7 downto 0);
        
        -- SAIDAS
        PC_WRITE_EN     : out std_logic;
        PC_JUMP_EN      : out std_logic;
        PC_TARGET       : out std_logic_vector(7 downto 0);
        ROM_ADDR_SEL    : out std_logic;
        RIH_WRITE_EN    : out std_logic;
        RIL_WRITE_EN    : out std_logic;
        REG_WRITE_EN    : out std_logic;
        REG_SEL_RD      : out std_logic_vector(3 downto 0);
        REG_SEL_A       : out std_logic_vector(3 downto 0);
        REG_SEL_B       : out std_logic_vector(3 downto 0);
        MEM_TO_REG_SEL  : out std_logic; -- (Legado, não usado por WRITEBACK_SRC)
        WRITEBACK_SRC   : out std_logic_vector(1 downto 0);
        ALU_OP_OUT      : out std_logic_vector(2 downto 0);
        ALU_SRC_B_SEL   : out std_logic;
        ALU_SRC_A_SEL   : out std_logic -- PORTA QUE FALTAVA NA SUA ENTITY
    );
end control_unit_FSM;

architecture Behavioral of control_unit_FSM is

    type state_type is (
        FETCH_OPCODE,
        FETCH_ARGS,
        EXECUTE
    );
    signal current_state, next_state : state_type := FETCH_OPCODE;
    
    signal s_opcode : std_logic_vector(7 downto 0) := (others => '0');
    signal s_args   : std_logic_vector(7 downto 0) := (others => '0'); 
    
    signal decoded_rd  : std_logic_vector(3 downto 0);
    signal decoded_rs1 : std_logic_vector(3 downto 0);

begin

    -- ===================================================
    -- COMBINACIONAL: DECODIFICADORES (Roda sempre)
    -- ==================================================
    decoded_rd  <= s_args(7 downto 4);
    decoded_rs1 <= s_args(3 downto 0);

    -- ===================================================
    -- PROCESSO 1 (SINCRONO): REGISTROS INTERNOS e TRANSIÇÃO DE ESTADOS
    -- ==================================================
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                current_state <= FETCH_OPCODE;
                s_opcode      <= (others => '0');
                s_args        <= (others => '0');
            else
                current_state <= next_state;
                
                -- Salva os dados lidos da ROM nos registradores internos
                if RIH_WRITE_EN = '1' then
                    s_opcode <= ROM_DATA_IN;
                end if;
                if RIL_WRITE_EN = '1' then
                    s_args <= ROM_DATA_IN;
                end if;
            end if;
        end if;
    end process;

    -- ===================================================
    -- PROCESSO 2 (COMBINACIONAL): GERAÇÃO DOS SINAIS DE CONTROLE
    -- ==================================================
    process(current_state, s_opcode, s_args, FLAGS_IN, decoded_rd, decoded_rs1)
    
        -- Variáveis para TODAS as saídas
        variable v_pc_write_en  : std_logic;
        variable v_pc_jump_en   : std_logic;
        variable v_pc_target    : std_logic_vector(7 downto 0);
        variable v_rom_addr_sel : std_logic;
        variable v_rih_write_en : std_logic;
        variable v_ril_write_en : std_logic;
        variable v_reg_write_en : std_logic;
        variable v_reg_sel_rd   : std_logic_vector(3 downto 0);
        variable v_reg_sel_a    : std_logic_vector(3 downto 0);
        variable v_reg_sel_b    : std_logic_vector(3 downto 0);
        variable v_mem_to_reg   : std_logic;
        variable v_wb_src       : std_logic_vector(1 downto 0);
        variable v_alu_op       : std_logic_vector(2 downto 0);
        variable v_alu_src_a    : std_logic;
        variable v_alu_src_b    : std_logic;
        
    begin
        -- ==================================================
        -- 1. DEFAULTS PARA TODAS AS SAÍDAS (Evita latches)
        -- ==================================================
        v_pc_write_en  := '0';
        v_pc_jump_en   := '0';
        v_pc_target    := s_args; -- Por padrão, o target é o RIL
        v_rom_addr_sel := '0';    -- Por padrão, ROM lê do PC
        v_rih_write_en := '0';
        v_ril_write_en := '0';
        v_reg_write_en := '0';
        v_reg_sel_rd   := (others => '0'); -- Default: R0
        v_reg_sel_a    := decoded_rd;      -- Default: Aponta A para Rd
        v_reg_sel_b    := decoded_rs1;     -- Default: Aponta B para Rs1
        v_mem_to_reg   := '0';
        v_wb_src       := "00"; -- Default: ALU
        v_alu_op       := "000";-- Default: ADD (para NOP ou MOV)
        v_alu_src_a    := '0';  -- Default: Registrador A
        v_alu_src_b    := '0';  -- Default: Registrador B
        
        -- ==================================================
        -- 2. LÓGICA DE ESTADO (Muda os defaults)
        -- ==================================================
        case current_state is

            when FETCH_OPCODE =>
                v_rih_write_en := '1';
                v_pc_write_en  := '1';
                next_state     <= FETCH_ARGS;

            when FETCH_ARGS =>
                v_ril_write_en := '1';
                v_pc_write_en  := '1';
                next_state     <= EXECUTE;

            when EXECUTE =>
                -- O default (v_reg_sel_a/b <= decoded_rd/rs1) já está correto.
                
                -- Decodificação do Opcode
                case s_opcode is
                
                    -- === GRUPO ARITMÉTICO (Reg-Reg) ===
                    -- (Destino = C (Fixo))
                    when "00000000" => -- ADD
                        v_reg_write_en := '1'; v_reg_sel_rd := "0010"; v_alu_op := "000";
                    when "00000001" => -- SUB
                        v_reg_write_en := '1'; v_reg_sel_rd := "0010"; v_alu_op := "001";
                    when "00000010" => -- MUL
                        v_reg_write_en := '1'; v_reg_sel_rd := "0010"; v_alu_op := "010";
                    when "00000011" => -- DIV
                        v_reg_write_en := '1'; v_reg_sel_rd := "0010"; v_alu_op := "011";
                    when "00000100" => -- MOD
                        v_reg_write_en := '1'; v_reg_sel_rd := "0010"; v_alu_op := "100";
                        
                    -- === GRUPO ARITMÉTICO (Reg-Imediato) ===
                    -- (Destino = C (Fixo))
                    when "00010000" => -- ADDI
                        v_reg_write_en := '1'; v_reg_sel_rd := "0010"; v_alu_op := "000"; v_alu_src_b := '1'; 
                    when "00010011" => -- DIVI
                        v_reg_write_en := '1'; v_reg_sel_rd := "0010"; v_alu_op := "011"; v_alu_src_b := '1';
                        
                    -- === GRUPO LÓGICO (Reg-Reg) ===
                    -- (Destino = C (Fixo))
                    when "00100000" => -- AND
                        v_reg_write_en := '1'; v_reg_sel_rd := "0010"; v_alu_op := "101";
                    when "00100001" => -- OR
                        v_reg_write_en := '1'; v_reg_sel_rd := "0010"; v_alu_op := "110";
                    when "00100010" => -- XOR
                        v_reg_write_en := '1'; v_reg_sel_rd := "0010"; v_alu_op := "111";

                    -- === GRUPO MOVIMENTAÇÃO (Exceções) ===
                    -- (Destino = decoded_rd)
                    when "01000000" => -- MOV Rd, Rs
                        v_reg_write_en := '1';
                        v_reg_sel_rd   := decoded_rd;
                        v_wb_src       := "10"; -- Fonte = REG_B (bypass)
                    
                    when "01000110" => -- MOVI Rd, imm (Rd <= 0 + imm)
                        v_reg_write_en := '1';
                        v_reg_sel_rd   := decoded_rd;
                        v_alu_op       := "000"; -- ULA = ADD (para 0 + imm)
                        v_alu_src_a    := '1';   -- Fonte A = 0
                        v_alu_src_b    := '1';   -- Fonte B = Imediato
                        v_wb_src       := "00";  -- Fonte = ALU
                        
                    -- === GRUPO JUMPS ===
                    when "01010110" => -- JMP
                        v_pc_write_en := '1';
                        v_pc_jump_en  := '1';
                    
                    when "01010001" => -- JZ
                        if FLAGS_IN(0) = '1' then
                            v_pc_write_en := '1';
                            v_pc_jump_en  := '1';
                        end if;
                        
                    when others =>
                        null; -- NOP
                end case;
                
                next_state <= FETCH_OPCODE;
        end case;
        
        -- ==================================================
        -- 3. ATRIBUIÇÃO DE SAÍDAS (Combinacional)
        -- ==================================================
        PC_WRITE_EN    <= v_pc_write_en;
        PC_JUMP_EN     <= v_pc_jump_en;
        PC_TARGET      <= v_pc_target;
        ROM_ADDR_SEL   <= v_rom_addr_sel;
        RIH_WRITE_EN   <= v_rih_write_en;
        RIL_WRITE_EN   <= v_ril_write_en;
        REG_WRITE_EN   <= v_reg_write_en;
        REG_SEL_RD     <= v_reg_sel_rd;
        REG_SEL_A      <= v_reg_sel_a;
        REG_SEL_B      <= v_reg_sel_b;
        MEM_TO_REG_SEL <= v_mem_to_reg;
        WRITEBACK_SRC  <= v_wb_src;
        ALU_OP_OUT     <= v_alu_op;
        ALU_SRC_A_SEL  <= v_alu_src_a; -- Conecta a nova porta
        ALU_SRC_B_SEL  <= v_alu_src_b;

    end process;
    
end Behavioral;