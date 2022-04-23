global so_emul

section .bss
    registers: resb 8 ; w rsi A, D, X, Y, PC, nieużyte, C, Z

section .text
get_value: ; w r8w ma kod argumentu używa tylko rejestrów r8w,r9w,ax w rax zwraca wartość
; w al zwraca wartosc nie w rax!
    xor rax,rax
    lea r9, [rel registers]
    cmp r8, 4
    jge get_value.greater_equal_4
    mov rax, [r9 + r8]
    ret 
.greater_equal_4:
    xor rax,rax
    test r8, 00001H ; testuje bit ostatni odpowiedzialny za X czy Y 
    jz get_value.X
    mov al, [r9 + 3] ; bierzemy wartość y
    jmp get_value.add_d
.X:
    mov al, [r9 + 2] ; bierzemy wartość x
.add_d:
    test r8, 00002H ; sprawdzamy czy dodajemy D
    jz get_value.value_from_adress
    add al, [r9 + 1] ; moooooooooooooodullllllllllllllloooooooooooooooooo %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
.value_from_adress:
    mov al, [rsi + rax]
    ret

put_value: ; w r8 co musimy wstawić w r11 numer kodu na który wstawiamy
    lea r9, [rel registers]
    cmp r11b, 4
    jge put_value.greater_equal_4
    ;lea r10b, [r9+r11]
    mov [r9 + r11], r8b
    ret 
.greater_equal_4:
    test r11b, 00001H ; testuje bit ostatni odpowiedzialny za X czy Y 
    jz put_value.X
    mov al, [r9 + 3] ; bierzemy wartość y
    jmp put_value.add_d
.X:
    mov al, [r9 + 2] ; bierzemy wartość x
.add_d:
    test r11b, 00002H ; sprawdzamy czy dodajemy D
    jz put_value.value_from_adress
    add al, [r9 + 1] ; moooooooooooooodullllllllllllllloooooooooooooooooo %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
.value_from_adress:
    mov [rsi + rax], r8b
    ret

SET_Z_FLAG: ;flaga Z jest ustawiona odpowiednio nie zmieniać argumentu 8! bo tam jest wynik operacji; zmienia r9 używa
    lea r9, [rel registers]
    jz SET_Z_FLAG.set_z
.unset_z:
    mov byte [r9 + 7], 0
    ret
.set_z:
    mov byte [r9 + 7], 1
    ret
SET_PROGRAM_Z_FLAG: ;ustawia lokalnie Z flagę w zależności od Z flagi w strukturze
    mov rax, [rel registers + 7]
    cmp rax, 1
    je SET_PROGRAM_Z_FLAG.set_z_flag
    clc ; czyści carry flag
    ret
.set_z_flag:
    stc ; ustawia carry flag
    ret




OR_INSTR: ; r8 wartosc arg1; r9 wartość arg2/imm; w r11 jest kod argumentu gdzie wpisac
    or r8b, r9b
    call SET_Z_FLAG
.push_value:
    call put_value
    ret
MOV_INSTR: ; r8 arg1 wartosc ; r9 arg2/imm ; r11 kod argumentu1 gdzie zapisujemy
    mov r8b, r9b
    call put_value
    ret

; bit carry odpowiednio ustawiony
ADD_INSTR: ; r8 arg1 wartosc ; r9 arg2/imm ; r11 kod argumentu1 gdzie zapisujemy
    add r8b, r9b
    call put_value
    ret


so_emul: ; rdi - kod; rsi - data; rdx - steps ;rcx - core;
    push r12 
    lea r9, [rel registers]
    mov r12, [r9 + 4]; która instrukcja teraz wykonywana numer
next_instruction:
    xor r8, r8
    xor r9, r9
    xor r10, r10
    xor r11, r11
    mov r8w, [rdi+r12*2]
two_arguments:
    test r8w, 0C000H ; dwa najbardziej znaczące bity są zerami  czyli koniunkcja musi być 0
    jnz arg_and_imm
    shl r8w, 2
    shr r8w, 13
    call get_value ; wyliczamy arg2
    mov r10w, ax ; pomocniczo skopiowanie obliczonej wartosci
    xor r8, r8
    mov r8w, [rdi+r12*2]
    shl r8w, 5
    shr r8w, 13
    mov r11w, r8w ; skopiowwanie argumentu wiloczonego
    call get_value ; wyliczamy arg1
    mov r8w, ax ; wartość w arg1
    mov r9w, r10w ; wartosć w arg2
    mov r10w, [rdi+r12*2] 
    shl r10w, 13 ; obliczamy instrukcje
    shr r10w, 13

.mov:
    test r10,7 ; bo instruckcja mov jest jako 000 więc koniunkca z 111 jak da zero to nasza instrukcja
    jnz two_arguments.or
    call MOV_INSTR
    jmp next
.or:
    test r10, 5; bo instukcja or to 010 więc w koniunkcji z 101 da zero
    jnz two_arguments.add
    ;???? znacznik z
    jmp next
.add:
    test r10,3
    jnz next
    ; jak kod instrukcji jest 110 lub 111 czyli drugi najbardziej znaczacy bit jest 1 to z przeniesieniem
    test r10, 2
    jnz next
    call ADD_INSTR
    jmp next
arg_and_imm:
    test r8w, 08000H; najbardziej znaczący bit musi być
    jnz next ; do innej instrukcji może być jeszcze !!!!!!!!!!!!!!!!!!!!!!!!!!
    shl r8w, 5 ; wyciągamy bity 3-5 licząc od najbardziej znaczących; wyciągamy argument
    shr r8w, 13; 16 - ile zostawiamy
    mov r11w, r8w ;pomocniczo zapisujemy arguemnt1 
    call get_value
    mov r9w, [rdi+r12*2]
    shl r9w, 8 ; obliczony imm8
    shr r9w, 8
    mov r10w, [rdi+r12*2] 
    shl r10w, 2 ; obliczamy instrukcje
    shr r10w, 13
.movi:
    test r10,7 ; bo instruckcja movi jest jako 000
    jnz next
    call MOV_INSTR
next: ; w rdx steps
    dec rdx
    lea r9, [rel registers]
    add r12, 1
    ; tymczasowo do przodu ...............................................
    ;add rdi, 2
    cmp rdx, 0 
    jne next_instruction
end:
    lea r9, [rel registers]
    mov [r9+4], r12
    mov rax, [rel registers]
    pop r12
    ret
