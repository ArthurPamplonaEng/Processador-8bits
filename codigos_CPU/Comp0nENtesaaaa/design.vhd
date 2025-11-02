-- processor.vhd
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity design is
    Port (
        clk : in  std_logic;
        rst : in  std_logic;

        -- Debug registers outputs
        r0_dbg : out std_logic_vector(7 downto 0);
        r1_dbg : out std_logic_vector(7 downto 0);
        r2_dbg : out std_logic_vector(7 downto 0);
        r3_dbg : out std_logic_vector(7 downto 0);
        r4_dbg : out std_logic_vector(7 downto 0);
        r5_dbg : out std_logic_vector(7 downto 0);
        r6_dbg : out std_logic_vector(7 downto 0);
        r7_dbg : out std_logic_vector(7 downto 0)
    );
end entity design;

architecture Behavioral of design is

    -- COMPONENT DECLARATIONS 
    component control_unit_FSM
        Port (
            clk         : in  std_logic;
            rst         : in  std_logic;
            ROM_DATA_IN : in  std_logic_vector(7 downto 0);
            FLAGS_IN    : in  std_logic_vector(7 downto 0);
            PC_WRITE_EN : out std_logic;
            PC_JUMP_EN  : out std_logic;
            PC_TARGET   : out std_logic_vector(7 downto 0);
            ROM_ADDR_SEL: out std_logic;
            RIH_WRITE_EN: out std_logic;
            RIL_WRITE_EN: out std_logic;
            REG_WRITE_EN: out std_logic;
            FLAGS_WRITE_EN: out std_logic;
            REG_SEL_RD  : out std_logic_vector(3 downto 0);
            REG_SEL_A   : out std_logic_vector(3 downto 0);
            REG_SEL_B   : out std_logic_vector(3 downto 0);
            MEM_TO_REG_SEL : out std_logic;
            WRITEBACK_SRC  : out std_logic_vector(1 downto 0);
            ALU_OP_OUT     : out std_logic_vector(3 downto 0);
            --O ALU_SRC_A_SEL ADICIONADO AGORA 01/11/2025 11:29 POR ARTHUR PAMPLONA
            ALU_SRC_A_SEL  : out std_logic; -- << 
            ALU_SRC_B_SEL  : out std_logic
        );
    end component;

    component register_file
        Port (
            clk                : in  std_logic;
            rst                : in  std_logic;
            gpr_write_enable   : in  std_logic;
            gpr_reg_select     : in  std_logic_vector(3 downto 0);
            gpr_data_in        : in  std_logic_vector(7 downto 0);
            pc_write_enable    : in  std_logic;
            pc_data_in         : in  std_logic_vector(7 downto 0);
            rih_write_enable   : in  std_logic;
            rih_data_in        : in  std_logic_vector(7 downto 0);
            ril_write_enable   : in  std_logic;
            ril_data_in        : in  std_logic_vector(7 downto 0);
            flags_write_enable : in  std_logic;
            flags_data_in      : in  std_logic_vector(7 downto 0);
            read_sel_A         : in  std_logic_vector(3 downto 0);
            read_sel_B         : in  std_logic_vector(3 downto 0);
            data_out_A         : out std_logic_vector(7 downto 0);
            data_out_B         : out std_logic_vector(7 downto 0);
            rih_out            : out std_logic_vector(7 downto 0);
            ril_out            : out std_logic_vector(7 downto 0);
            flags_out          : out std_logic_vector(7 downto 0);
            pc_out             : out std_logic_vector(7 downto 0);
            
            
            -- Debug outputs (added)
        	r0_dbg : out std_logic_vector(7 downto 0);
        	r1_dbg : out std_logic_vector(7 downto 0);
        	r2_dbg : out std_logic_vector(7 downto 0);
        	r3_dbg : out std_logic_vector(7 downto 0);
        	r4_dbg : out std_logic_vector(7 downto 0);
        	r5_dbg : out std_logic_vector(7 downto 0);
        	r6_dbg : out std_logic_vector(7 downto 0);
        	r7_dbg : out std_logic_vector(7 downto 0)
        );
    end component;

    component ULA_8_BITS
        Port (
            Fst    : in  std_logic_vector(7 downto 0);
            Scd    : in  std_logic_vector(7 downto 0);
            OP     : in  std_logic_vector(3 downto 0);
            RESULT : out std_logic_vector(7 downto 0);
            COUT   : out std_logic;
            ZERO   : out std_logic;
            OVF    : out std_logic;
            NEG    : out std_logic
        );
    end component;

    component rom_memoria
        Port (
            ADDR : in  std_logic_vector(7 downto 0);
            DATA : out std_logic_vector(7 downto 0)
        );
    end component;

    component incrementador_pc
        Port (
            PC_IN  : in  std_logic_vector(7 downto 0);
            PC_OUT : out std_logic_vector(7 downto 0)
        );
    end component;

    component mux_2_para_1
        Port (
            IN_A : in  std_logic_vector(7 downto 0);
            IN_B : in  std_logic_vector(7 downto 0);
            SEL  : in  std_logic;
            OUT_S: out std_logic_vector(7 downto 0)
        );
    end component;

    -- Simple data memory (internal) signals and parameters
    constant MEM_SIZE : integer := 256;
    type mem_array_t is array (0 to MEM_SIZE-1) of std_logic_vector(7 downto 0);

    -- Internal signals
    signal pc_write_en_sig  : std_logic;
    signal pc_jump_en_sig   : std_logic;
    signal pc_target_sig    : std_logic_vector(7 downto 0);
    signal rom_addr_sel_sig : std_logic;
    signal rih_we_sig       : std_logic;
    signal ril_we_sig       : std_logic;
    signal reg_write_en_sig : std_logic;
    signal flags_write_en_sig : std_logic;
    signal reg_sel_rd_sig   : std_logic_vector(3 downto 0);
    signal reg_sel_a_sig    : std_logic_vector(3 downto 0);
    signal reg_sel_b_sig    : std_logic_vector(3 downto 0);
    signal mem_to_reg_sig   : std_logic;
    signal writeback_src_sig: std_logic_vector(1 downto 0);
    signal alu_op_sig       : std_logic_vector(3 downto 0);
    signal alu_src_b_sig    : std_logic;
    --ADCIONANDO MANUALEMNTE TALVEZ DE ERRO AAAAAAAAAAAAAAAAAAAA
	signal alu_src_a_sig    : std_logic;

    -- Connections to register_file
    signal gpr_data_in_sig  : std_logic_vector(7 downto 0);
    signal rf_data_A_sig    : std_logic_vector(7 downto 0);
    signal rf_data_B_sig    : std_logic_vector(7 downto 0);
    signal rih_out_sig      : std_logic_vector(7 downto 0);
    signal ril_out_sig      : std_logic_vector(7 downto 0);
    signal flags_out_sig    : std_logic_vector(7 downto 0);
    signal pc_out_sig       : std_logic_vector(7 downto 0);

    -- PC increment / selection
    signal pc_inc_sig       : std_logic_vector(7 downto 0);
    signal pc_next_sig      : std_logic_vector(7 downto 0);

    -- ROM
    signal rom_data_sig     : std_logic_vector(7 downto 0);
    signal rom_addr_sig     : std_logic_vector(7 downto 0);

    -- ALU
    signal alu_result_sig   : std_logic_vector(7 downto 0);
    signal alu_cout_sig     : std_logic;
    signal alu_zero_sig     : std_logic;
    signal alu_ovf_sig      : std_logic;
    signal alu_neg_sig      : std_logic;

    -- Data memory
    signal data_mem        : mem_array_t := (others => (others => '0'));
    signal data_mem_addr   : std_logic_vector(7 downto 0);
    signal data_mem_dout   : std_logic_vector(7 downto 0);
    signal data_mem_din    : std_logic_vector(7 downto 0);
    signal data_mem_we     : std_logic := '0'; -- NOT controlled by FSM yet 
  

    -- writeback MUX output
    signal wb_data_sig     : std_logic_vector(7 downto 0);

    -- flags to RF (pack in a byte)
    signal flags_from_alu  : std_logic_vector(7 downto 0);
    
    --sinal auxiliar para register
    signal flags_we_sig : std_logic;
    
    --sinal immediate
    signal imm_ext : std_logic_vector(7 downto 0);
    
    --sinal auxiliar (ALU)
    signal alu_fst_sig : std_logic_vector(7 downto 0);
    signal alu_scd_sig : std_logic_vector(7 downto 0);

begin
	--atribuicao do sinal auxiliar register
    flags_we_sig <= flags_write_en_sig;
   
    --atribuicao do sinal auxiliar alu (MUX A e MUX B) FEITO AGORA ARTHUR PAMPLONA 01/11/2025 11:35
-- MUX A: Seleciona 0 (se alu_src_a_sig=1) ou RegA (se alu_src_a_sig=0)
alu_fst_sig <= (others => '0') when alu_src_a_sig = '1' else rf_data_A_sig;

-- MUX B: Seleciona Imediato (se alu_src_b_sig=1) ou RegB (se alu_src_b_sig=0)
alu_scd_sig <= imm_ext when alu_src_b_sig = '1' else rf_data_B_sig;
  

    -- Instantiate control unit
    CU: control_unit_FSM
        port map(
            clk => clk,
            rst => rst,
            ROM_DATA_IN => rom_data_sig,
            FLAGS_IN    => flags_out_sig,
            PC_WRITE_EN => pc_write_en_sig,
            PC_JUMP_EN  => pc_jump_en_sig,
            PC_TARGET   => pc_target_sig,
            ROM_ADDR_SEL=> rom_addr_sel_sig,
            RIH_WRITE_EN=> rih_we_sig,
            RIL_WRITE_EN=> ril_we_sig,
            REG_WRITE_EN=> reg_write_en_sig,
            FLAGS_WRITE_EN => flags_write_en_sig,
            REG_SEL_RD  => reg_sel_rd_sig,
            REG_SEL_A   => reg_sel_a_sig,
            REG_SEL_B   => reg_sel_b_sig,
            MEM_TO_REG_SEL => mem_to_reg_sig,
            WRITEBACK_SRC  => writeback_src_sig,
            ALU_OP_OUT     => alu_op_sig,
            --O ALU_SRC_A_SEL ADICIONADO AGORA 01/11/2025 11:31 POR ARTHUR PAMPLONA
            ALU_SRC_A_SEL  => alu_src_a_sig,
            ALU_SRC_B_SEL  => alu_src_b_sig
        );

    -- Instantiate register file (your provided RF)
    RF: register_file
        port map(
            clk => clk,
            rst => rst,
            gpr_write_enable   => reg_write_en_sig,
            gpr_reg_select     => reg_sel_rd_sig,
            gpr_data_in        => gpr_data_in_sig,
            pc_write_enable    => pc_write_en_sig,
            pc_data_in         => pc_next_sig,
            rih_write_enable   => rih_we_sig,
            rih_data_in        => rom_data_sig,
            ril_write_enable   => ril_we_sig,
            ril_data_in        => rom_data_sig,
            flags_write_enable => flags_we_sig,
            flags_data_in      => flags_from_alu,
            read_sel_A         => reg_sel_a_sig,
            read_sel_B         => reg_sel_b_sig,
            data_out_A         => rf_data_A_sig,
            data_out_B         => rf_data_B_sig,
            rih_out            => rih_out_sig,
            ril_out            => ril_out_sig,
            flags_out          => flags_out_sig,
            pc_out             => pc_out_sig,
            
            
            -- Debug outputs
        	r0_dbg => r0_dbg,
        	r1_dbg => r1_dbg,
        	r2_dbg => r2_dbg,
        	r3_dbg => r3_dbg,
        	r4_dbg => r4_dbg,
        	r5_dbg => r5_dbg,
        	r6_dbg => r6_dbg,
        	r7_dbg => r7_dbg
        );

    -- PC incrementer
    PC_INC: incrementador_pc
        port map(PC_IN => pc_out_sig, PC_OUT => pc_inc_sig);

    -- PC select (jump or next)
    PC_MUX: mux_2_para_1
        port map(IN_A => pc_inc_sig, IN_B => pc_target_sig, SEL => pc_jump_en_sig, OUT_S => pc_next_sig);

    -- ROM (instruction memory)
    ROM: rom_memoria
        port map(ADDR => rom_addr_sig, DATA => rom_data_sig);

    -- ALU
    ALU: ULA_8_BITS
        port map(
            Fst => alu_fst_sig,
            Scd => alu_scd_sig,
            OP  => alu_op_sig,
            RESULT => alu_result_sig,
            COUT   => alu_cout_sig,
            ZERO   => alu_zero_sig,
            OVF    => alu_ovf_sig,
            NEG    => alu_neg_sig
        );

    -- NOTE:
    -- The assembler packs immediates in RIL nibble(s). We'll provide immediate to ALU by constructing
    -- a small vector from ril_out (low nibble) when alu_src_b_sig='1'.
    -- We must override ALU.ScD input in that case. Implement via combinational assignment:
    begin_process_immediate: process(ril_out_sig, alu_src_b_sig, rf_data_B_sig)
    begin
        if alu_src_b_sig = '1' then
            imm_ext <= "0000" & ril_out_sig(3 downto 0);
        else
            imm_ext <= rf_data_B_sig;
        end if;
    end process;

    -- flags pack
    flags_from_alu <= alu_zero_sig & alu_cout_sig & alu_ovf_sig & alu_neg_sig & "0000";

    -- ROM address selection: PC or Register B (for load/str addressing)
    rom_addr_sig <= pc_out_sig when rom_addr_sel_sig = '0' else rf_data_B_sig;

    -- DATA MEMORY (simple behavioral):
    -- asynchronous read, synchronous write on rising_edge(clk) when data_mem_we = '1'
    data_memory_proc : process(clk)
        variable addr_i : integer;
    begin
        if rising_edge(clk) then
            if data_mem_we = '1' then
                addr_i := to_integer(unsigned(data_mem_addr));
                data_mem(addr_i) <= data_mem_din;
            end if;
        end if;
    end process;

    -- asynchronous read (combinational)
    data_mem_dout <= data_mem(to_integer(unsigned(data_mem_addr)));

    -- Address and data wiring for data memory:
    -- By convention use rf_data_B_sig as memory address (you can change)
    data_mem_addr <= rf_data_B_sig;
    data_mem_din  <= rf_data_A_sig; -- store source from A (convention; adjust as needed)

    -- data_mem_we: TODO: connect to mem write control from FSM (quando tiver memoria ext fdp).
    -- For now left '0'; map to '1' when you add mem_write output in FSM.
    data_mem_we <= '0';

    -- WRITEBACK MUX (00=ALU,01=MEM,10=REG_B)
    wb_mux_proc: process(alu_result_sig, data_mem_dout, rf_data_B_sig, writeback_src_sig)
    begin
        case writeback_src_sig is
            when "00" => wb_data_sig <= alu_result_sig;
            when "01" => wb_data_sig <= data_mem_dout;
            when "10" => wb_data_sig <= rf_data_B_sig;
            when others => wb_data_sig <= alu_result_sig;
        end case;
    end process;

    -- Feed GPR write-back data
    gpr_data_in_sig <= wb_data_sig;

    -- Hook mux for MEM_TO_REG_SEL legacy (keeps backwards compat)
    -- (not needed if WRITEBACK_SRC used)
    MEM_TO_REG_SEL_COMP: process(mem_to_reg_sig, wb_data_sig, data_mem_dout, alu_result_sig)
    begin
        null; -- kept for clarity; writeback_src_sig controls final selection
    end process;
    
end Behavioral;

