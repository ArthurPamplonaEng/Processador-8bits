#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <ctype.h>

#define MSG_ERRO_LINHA "Erro na linha:"
#define WORD_SIZE 8

typedef struct{
    const char* mnemonic;
    const char* reg_code;
} reg_format;

typedef struct{
    const char* mnemonic;
    const char* opcode;
    int argumentos;
} opc_format;

reg_format regs[] = {
    {"A", "0000"},
    {"B", "0001"},
    {"C", "0010"},
    {"RIH", "0011"},
    {"RIL","0100"},
    {"PC","0101"},
    {"FLAGS","0110"}
};

opc_format opcodes[] = {
    {"ADD", "00000000", 2},
    {"ADDI", "00010000", 2},
    {"AND", "00100000", 2},
    {"CALL", "01100000", 1},
    {"CP", "00000111", 2},
    {"DEC", "00000110", 1},
    {"DIV", "00000011", 2},
    {"DIVI", "00010011", 2},
    {"HLT", "01100100", 0},
    {"INC", "00000101", 1},
    {"JMP", "01010110", 1},
    {"JNE", "01010101", 1},
    {"JZ", "01010001", 1},
    {"LDR", "01000001", 2},
    {"MOD", "00000100", 2},
    {"MODI", "00010100", 2},
    {"MOV", "01000000", 2},
    {"MOVI","01000110",2},
    {"MUL", "00000010", 2},
    {"MULI", "00010010", 2},
    {"NAND", "00100100", 2},
    {"NOP", "01000101", 0},
    {"NOR", "00100101", 2},
    {"NOT", "00100011", 2},
    {"NXOR", "00100110", 2},
    {"OR", "00100001", 2},
    {"POP", "01100011", 1},
    {"PUSH", "01100010", 1},
    {"RET", "01100001", 0},
    {"SLB", "01000011", 2},
    {"SRB", "01000100", 2},
    {"STR", "01000010", 2},
    {"SUB", "00000001", 2},
    {"SUBI", "00010001", 2},
    {"XOR", "00100010", 2}
};

static const size_t TAM_OPCODES = sizeof(opcodes) / sizeof(opcodes[0]);
static const size_t TAM_REGS = sizeof(regs) / sizeof(regs[0]);

// fwrite(bin_teste, sizeof(char),strlen(bin_teste),fbin);


void rm_comentarios(char* s){
    char* pos_comentario = strchr(s, ';');
    if(pos_comentario != NULL) *pos_comentario = '\0';
}

void trim_espacos(char* s){
    char tmp[1024];
    size_t di = 0;
    for(size_t i = 0; s[i] != '\0' && di + 1 < sizeof(tmp); ++i){
        if(s[i] == '\t') tmp[di++] = ' ';
        else if(s[i] == '\r') continue;
        else tmp[di++] = s[i];
    }
    tmp[di] = '\0';

    // trim e colapsa múltiplos espaços
    size_t src = 0, dest = 0;
    // pula espaços iniciais
    while(tmp[src] != '\0' && isspace((unsigned char)tmp[src])) src++;
    int in_space = 0;
    while(tmp[src] != '\0' && dest + 1 < sizeof(tmp)){
        if(isspace((unsigned char)tmp[src])){
            if(!in_space){
                // escreve um único espaço
                tmp[dest++] = ' ';
                in_space = 1;
            }
        } else {
            tmp[dest++] = tmp[src];
            in_space = 0;
        }
        src++;
    }
    // remove possível espaço final
    if(dest > 0 && tmp[dest-1] == ' ') dest--;
    tmp[dest] = '\0';

    // copia de volta
    strncpy(s, tmp, dest + 1);
}

int buscar_mnemonic(char* src, char* dest, size_t dest_tam){
    if(src == NULL || src[0] == '\0'){
        if(dest_tam > 0) dest[0] = '\0';
        return 2;
    }
    char* pos = strchr(src, ' ');
    size_t tam;
    if(pos == NULL) tam = strlen(src);
    else tam = (size_t)(pos - src);

    if (tam >= dest_tam) {
        tam = dest_tam - 1;
        strncpy(dest,src,tam);
        dest[tam] = '\0';
        return 1;
    }

    strncpy(dest, src, tam);
    dest[tam] = '\0';
    return 0;
}

int main(int argc, char** argv){
    if(argc < 2){
        fprintf(stderr, "Uso: %s arquivo.asm\n", argv[0]);
        return 1;
    }

    char* asm_path = argv[1];

    FILE *fasm, *fbin;

    fasm = fopen(asm_path, "r");
    /* ALTERAÇÃO: gerar arquivo de texto com extensão .txt em vez de binário */
    fbin = fopen("binout.txt","w+");

    if (fasm == NULL){
        fprintf(stderr, "Não foi possível abrir %s\n", asm_path);
        return 1;
    }

    if (fbin == NULL){
        fprintf(stderr, "Não foi possível criar/abrir saída 'binout.txt'\n");
        fclose(fasm);
        return 1;
    }

    char linha_buffer[1024];
    char arg_buffer[64];
    int linha = 0;
    while(fgets(linha_buffer, sizeof(linha_buffer), fasm) != NULL){
        linha++;
        rm_comentarios(linha_buffer);
        trim_espacos(linha_buffer);
        if(linha_buffer[0] == '\0') continue;

        char* p = linha_buffer;
        char mnemonic_buffer[64];
        int rc = buscar_mnemonic(p, mnemonic_buffer, sizeof(mnemonic_buffer));
        if(rc == 2) continue;
        size_t len_mn = strlen(mnemonic_buffer);
        p += len_mn;
        if(*p == ' ') p++;

        int found_opcode = 0;
        for(size_t i = 0; i < TAM_OPCODES; i++){
            if (strcmp(mnemonic_buffer,opcodes[i].mnemonic) == 0){
                found_opcode = 1;
                fwrite(opcodes[i].opcode, sizeof(char), strlen(opcodes[i].opcode),fbin);
                fputc('\n', fbin);

                int num_args = opcodes[i].argumentos;
                if (num_args == 0) {
                    fwrite("00000000", sizeof(char), 8, fbin);
                    fputc('\n', fbin);
                    break; // nada mais a processar nesta linha
                }
                for(int j = 0; j < num_args; j++){
                    /* Monta uma linha de 8 bits contendo os argumentos.
                       Cada argumento ocupa 4 bits:
                       - argumento 0 -> bits altos (pos 0..3)
                       - argumento 1 -> bits baixos (pos 4..7)
                       Se faltar argumento, preenche com '0's.
                    */
                    char argline[9];
                    for(int zz=0; zz<8; zz++) argline[zz] = '0';
                    argline[8] = '\0';

                    int arg_index = 0;
                    /* processa até num_args argumentos ou até não haver mais texto */
                    for(; arg_index < num_args; arg_index++){
                        if(p == NULL || *p == '\0') {
                            /* nenhum mais argumento — deixa zeros no restante */
                            break;
                        }
                        int rc2 = buscar_mnemonic(p, arg_buffer, sizeof(arg_buffer));
                        if(rc2 == 2){
                            fprintf(stderr, "%s %d: argumento inválido\n", MSG_ERRO_LINHA, linha);
                            break;
                        } else if(rc2 == 1){
                            fprintf(stderr, "%s %d: argumento truncado (buffer pequeno)\n", MSG_ERRO_LINHA, linha);
                        }

                        size_t len_arg = strlen(arg_buffer);
                        p += len_arg;
                        if(p && *p == ' ') p++;

                        int found_reg = 0;
                        for(size_t k = 0; k < TAM_REGS; k++){
                            if (strcmp(arg_buffer, regs[k].mnemonic) == 0){
                                /* copia 4 bits do registrador para a posição correta */
                                int pos = arg_index * 4;
                                memcpy(&argline[pos], regs[k].reg_code, 4);
                                found_reg = 1;
                                break;
                            }
                        }
                        if(!found_reg){
                            int is_num = 1;
                            for(size_t c = 0; c < strlen(arg_buffer); c++){
                                if(!isdigit((unsigned char)arg_buffer[c])) {
                                    is_num = 0;
                                    break;
                                }
                            }
                            if(is_num){
                                int val = atoi(arg_buffer);
                                if(val < 0 || val > 15){
                                    fprintf(stderr, "%s %d: imediato fora do intervalo (0–15): %d\n",
                                            MSG_ERRO_LINHA, linha, val);
                                } else {
                                    /* converte para binário de 4 bits e copia na posição */
                                    for(int b = 0; b < 4; b++){
                                        argline[arg_index*4 + b] = ((val >> (3 - b)) & 1) ? '1' : '0';
                                    }
                                }
                            } else {
                                fprintf(stderr, "Aviso: argumento '%s' (linha %d) não reconhecido.\n",
                                        arg_buffer, linha);
                            }
                        }
                    } /* end processa argumentos */

                    /* grava a linha de argumentos como 8 caracteres e quebra de linha */
                    fwrite(argline, sizeof(char), 8, fbin);
                    fputc('\n', fbin);
                    /* após processar os argumentos, sair do loop j (pois já tratamos todos os
                       argumentos esperados em argline) */
                    break;
                }
            }
        }
        if(!found_opcode){
            fprintf(stderr, "%s %d: mnemonic desconhecido '%s'\n", MSG_ERRO_LINHA, linha, mnemonic_buffer);
        }

    }

    printf("Assemble concluído — arquivo: binout.txt\n");

    fclose(fasm);
    fclose(fbin);
    

    return 0;
}