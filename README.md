# Processador de 8 bits em VHDL

Processador didático de 8 bits descrito em VHDL, com unidade de controle baseada em
máquina de estados, ULA própria, banco de registradores e um montador (assembler)
escrito em C que converte programas `.asm` no arquivo `binout.txt` carregado pela
memória de instruções durante a simulação.

---

## Sumário

- [Visão geral](#visão-geral)
- [Estrutura do repositório](#estrutura-do-repositório)
- [Arquitetura](#arquitetura)
- [Formato das instruções](#formato-das-instruções)
- [Conjunto de instruções (ISA)](#conjunto-de-instruções-isa)
- [Montador (assembler)](#montador-assembler)
- [Simulação](#simulação)
- [Limitações conhecidas](#limitações-conhecidas)

---

## Visão geral

| Característica          | Valor                                              |
|-------------------------|----------------------------------------------------|
| Largura de dados        | 8 bits                                             |
| Memória de instruções   | 256 posições × 8 bits (carregada de `binout.txt`)  |
| Registradores de uso geral | `A`, `B`, `C`                                   |
| Registradores especiais | `PC`, `RIH`, `RIL`, `FLAGS`                        |
| Tamanho da instrução    | 2 bytes (opcode + argumentos)                      |
| Ciclo de instrução      | 3 estados: `FETCH_OPCODE` → `FETCH_ARGS` → `EXECUTE` |
| Flags                   | Zero, Carry, Overflow, Negativo                    |
| Simulador de referência | GHDL 3.0 (VHDL-2008) no EDA Playground             |

## Estrutura do repositório

```
Processador-8bits/
├── README.md
└── codigos_CPU/
    ├── compilador.c              # Montador: .asm -> binout.txt
    ├── run_bash_EDAPG.txt        # Script de compilação/simulação com GHDL (run.bash)
    └── Comp0nENtesaaaa/          # Componentes VHDL
        ├── design.vhd            # Entidade de topo (interliga todos os blocos)
        ├── unidade_de_controle.vhd  # FSM de controle (control_unit_FSM)
        ├── registradores.vhd     # Banco de registradores (register_file)
        ├── ULA.vhd               # ULA de 8 bits (ULA_8_BITS) e suas subunidades
        ├── SHIFTER_8BIT.vhd      # Deslocador lógico de 1 bit (SLB/SRB)
        ├── fila_de_instrucao.vhd # Memória de instruções (rom_memoria)
        ├── incrementador_pc.vhd  # PC + 1
        └── mux_2_para_1.vhd      # MUX 2:1 de 8 bits
```

## Arquitetura

```
                 ┌──────────────────────┐
                 │  control_unit_FSM    │◄──────── FLAGS
                 │ FETCH_OPCODE         │
                 │ FETCH_ARGS           │── sinais de controle ──┐
                 │ EXECUTE              │                        │
                 └──────────▲───────────┘                        ▼
                            │ opcode / args          ┌───────────────────────┐
┌──────────┐   ADDR   ┌─────┴──────┐                 │    register_file      │
│ PC + 1   ├──►MUX──► │ rom_memoria│                 │ A B C | PC RIH RIL    │
└────▲─────┘  (jump)  │ (binout.txt)│                │ FLAGS                 │
     │                └────────────┘                 └───┬───────────▲───────┘
     │                                        data_A/B   │           │ write-back
     └──────────────── PC ◄──────────────────────────────┤           │ (ALU / MEM / Reg B)
                                                         ▼           │
                                                  ┌──────────────┐   │
                                imediato (4 bits)►│  ULA_8_BITS  ├───┘
                                                  └──────────────┘
```

### Componentes

- **`design.vhd`** – entidade de topo `design` (portas `clk`, `rst` e saídas de depuração
  `r0_dbg` … `r7_dbg`). Instancia todos os blocos, monta o imediato (`"0000" & RIL(3:0)`),
  empacota as flags e implementa o MUX de write-back (`00` = ULA, `01` = memória de dados,
  `10` = registrador B). Contém também uma memória de dados simples, ainda não controlada pela FSM.
- **`unidade_de_controle.vhd`** – FSM com dois processos (síncrono para estado/registros
  internos e combinacional para os sinais de controle). Busca o opcode, depois os argumentos,
  e executa a instrução decodificada.
- **`registradores.vhd`** – escrita síncrona separada para GPRs (`A`, `B`, `C`) e para os
  registradores especiais (`PC`, `RIH`, `RIL`, `FLAGS`); duas portas de leitura assíncronas.
- **`ULA.vhd`** – somador ripple-carry, subtrator por complemento de 2, multiplicador,
  divisor (com detecção de divisão por zero), unidade lógica, comparador e deslocador.
- **`fila_de_instrucao.vhd`** – memória de 256 bytes inicializada a partir de `binout.txt`
  (via `TEXTIO`, apenas em simulação) com leitura assíncrona.
- **`incrementador_pc.vhd`** e **`mux_2_para_1.vhd`** – lógica de próximo PC (`PC+1` ou alvo de salto).

### Mapa de registradores

| Registrador | Código | Saída de debug |
|-------------|--------|----------------|
| `A`         | `0000` | `r0_dbg`       |
| `B`         | `0001` | `r1_dbg`       |
| `C`         | `0010` | `r2_dbg`       |
| `RIH`       | `0011` | `r3_dbg`       |
| `RIL`       | `0100` | `r4_dbg`       |
| `PC`        | `0101` | `r5_dbg`       |
| `FLAGS`     | `0110` | `r6_dbg`       |

`FLAGS` é empacotado como `Z C V N 0 0 0 0` (bit 7 → bit 0).

### Operações da ULA

| `OP`   | Operação | `OP`   | Operação |
|--------|----------|--------|----------|
| `0000` | ADD      | `0110` | OR       |
| `0001` | SUB      | `0111` | XOR      |
| `0010` | MUL (8 bits baixos) | `1000` | NOT A |
| `0011` | DIV      | `1001` | SLB (shift left, bit que sai → Carry) |
| `0100` | MOD      | `1010` | SRB (shift right, bit que sai → Carry) |
| `0101` | AND      |        |          |

## Formato das instruções

Cada instrução ocupa **2 bytes** consecutivos na memória:

```
byte 0 (RIH): OOOOOOOO          opcode de 8 bits
byte 1 (RIL): XXXX YYYY         argumento 1 (bits 7..4) | argumento 2 (bits 3..0)
```

- Argumentos podem ser registradores (código de 4 bits) ou imediatos de **0 a 15**.
- Instruções sem argumentos recebem `00000000` no segundo byte.
- Em saltos (`JMP`, `JZ`) o byte `RIL` inteiro é usado como endereço de destino.

## Conjunto de instruções (ISA)

Nas instruções aritméticas e lógicas o resultado é sempre gravado em **`C`**.

### Implementadas na unidade de controle

| Mnemônico | Opcode     | Sintaxe        | Efeito                     |
|-----------|------------|----------------|----------------------------|
| `ADD`     | `00000000` | `ADD Ra Rb`    | `C ← Ra + Rb`              |
| `SUB`     | `00000001` | `SUB Ra Rb`    | `C ← Ra − Rb`              |
| `MUL`     | `00000010` | `MUL Ra Rb`    | `C ← Ra × Rb`              |
| `DIV`     | `00000011` | `DIV Ra Rb`    | `C ← Ra ÷ Rb`              |
| `MOD`     | `00000100` | `MOD Ra Rb`    | `C ← Ra mod Rb`            |
| `CP`      | `00000111` | `CP Ra Rb`     | Calcula `Ra − Rb`, só atualiza flags |
| `ADDI`    | `00010000` | `ADDI Ra imm`  | `C ← Ra + imm`             |
| `SUBI`    | `00010001` | `SUBI Ra imm`  | `C ← Ra − imm`             |
| `MULI`    | `00010010` | `MULI Ra imm`  | `C ← Ra × imm`             |
| `DIVI`    | `00010011` | `DIVI Ra imm`  | `C ← Ra ÷ imm`             |
| `AND`     | `00100000` | `AND Ra Rb`    | `C ← Ra and Rb`            |
| `OR`      | `00100001` | `OR Ra Rb`     | `C ← Ra or Rb`             |
| `XOR`     | `00100010` | `XOR Ra Rb`    | `C ← Ra xor Rb`            |
| `NOT`     | `00100011` | `NOT Ra Rb`    | `C ← not Ra`               |
| `MOV`     | `01000000` | `MOV Rd Rs`    | `Rd ← Rs`                  |
| `MOVI`    | `01000110` | `MOVI Rd imm`  | `Rd ← imm`                 |
| `JMP`     | `01010110` | `JMP addr`     | `PC ← addr`                |
| `JZ`      | `01010001` | `JZ addr`      | `PC ← addr` se Zero = 1    |

### Reconhecidas pelo montador, ainda não implementadas no hardware

`CALL`, `RET`, `PUSH`, `POP`, `LDR`, `STR`, `JNE`, `HLT`, `INC`, `DEC`, `MODI`,
`NAND`, `NOR`, `NXOR`, `SLB`, `SRB`, `NOP`. No hardware, opcodes não reconhecidos
são tratados como `NOP`.

## Montador (assembler)

O arquivo `codigos_CPU/compilador.c` traduz um programa em assembly para `binout.txt`
(um byte por linha, em texto binário).

### Compilação e uso

```bash
cd codigos_CPU
gcc -o montador compilador.c
./montador programa.asm      # gera binout.txt no diretório atual
```

### Sintaxe

- Uma instrução por linha; argumentos separados por espaço (sem vírgula).
- Comentários começam com `;`.
- Registradores: `A`, `B`, `C`, `RIH`, `RIL`, `PC`, `FLAGS`.
- Imediatos: decimais de 0 a 15.

### Exemplo

`programa.asm`:

```asm
MOVI A 5    ; A = 5
MOVI B 3    ; B = 3
ADD A B     ; C = A + B = 8
JMP 0       ; volta ao início
```

`binout.txt` gerado:

```
01000110
00000101
01000110
00010011
00000000
00000001
01010110
00000000
```

## Simulação

### EDA Playground

1. Adicione todos os arquivos de `codigos_CPU/Comp0nENtesaaaa/` no painel **Design** (direita).
2. Gere o `binout.txt` com o montador e adicione-o também no painel **Design**.
3. Em *Tools & Simulators*, configure:
   - Linguagem: **VHDL**
   - Top entity: **`design`**
   - Simulador: **GHDL 3.0**
   - Marque **Use run.bash** e **Open EPWave after run**
4. Crie o arquivo `run.bash` no painel **Testbench** (esquerda) com o conteúdo de
   `codigos_CPU/run_bash_EDAPG.txt`.
5. Adicione o `testbench.vhd` no painel **Testbench**.
6. Clique em **Save** e depois **Run**. No EPWave, observe principalmente os sinais
   `r0_dbg` … `r6_dbg` para conferir o resultado das operações.

### GHDL local

Com o GHDL instalado, a mesma sequência do `run.bash` funciona localmente:

```bash
ghdl -i --std=08 -fsynopsys *.vhd
ghdl -m --std=08 testbench
ghdl -r testbench --stop-time=400ns --vcd=wave.vcd
gtkwave wave.vcd
```

> O `binout.txt` precisa estar no diretório onde a simulação é executada.

## Limitações conhecidas

- **Testbench ausente:** o `testbench.vhd` usado na simulação ainda não está no repositório.
- **Nomes no `run.bash`:** o script referencia arquivos com sufixo `_ajeitado`
  (ex.: `ULA_ajeitada.vhd`, `rom_ajeitado.vhd`); ajuste os nomes para os do repositório
  ou renomeie os arquivos ao subir no EDA Playground.
- **Opcodes divergentes:** `SLB`, `SRB` e `NOP` têm opcodes diferentes no montador
  (`01000011`, `01000100`, `01000101`) e na unidade de controle (`01000111`, `01001000`, `01111111`).
- **`JZ`:** a FSM testa `FLAGS(0)`, mas a flag Zero é empacotada no bit 7 de `FLAGS`,
  então o salto condicional nunca é tomado.
- **Memória de dados:** existe em `design.vhd`, mas o sinal de escrita ainda não é
  controlado pela FSM (`LDR`/`STR` não funcionam).
- **Imediatos de 4 bits:** apenas valores de 0 a 15.
