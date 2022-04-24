global so_emul

section .bss
    registers: resb 8 ; A, D, X, Y, PC, nieużyte, C, Z

section .text

get_value: ; w r8w ma kod argumentu używa tylko rejestrów r8w,r9w, w al zwraca wartosc
    xor rax,rax
    cmp r8, 4
    jge get_value.greater_equal_4
    mov al, [r15 + r8] ; w r15 wskaznik na pierwszy element structury na strukture bierzemy 8 bitów z tablicy
    ret 
.greater_equal_4:
    test r8, 00001H ; testuje bit ostatni odpowiedzialny za X czy Y 
    jz get_value.X
    mov al, [r15 + 3] ; bierzemy wartość y
    jmp get_value.add_d
.X:
    mov al, [r15 + 2] ; bierzemy wartość x
.add_d:
    test r8, 00002H ; sprawdzamy czy dodajemy D 
    jz get_value.value_from_adress
    add al, [r15 + 1] ; moooooooooooooodullllllllllllllloooooooooooooooooo %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
.value_from_adress:
    mov al, [rsi + rax]
    ret

put_value: ; w r8 co musimy wstawić w r11 numer kodu na który wstawiamy
    cmp r11b, 4
    jge put_value.greater_equal_4
    ;lea r10b, [r9+r11]
    mov [r15 + r11], r8b ; w r15 wskaznik na strukture
    ret 
.greater_equal_4:
    test r11b, 00001H ; testuje bit ostatni odpowiedzialny za X czy Y 
    jz put_value.X
    mov al, [r15 + 3] ; bierzemy wartość y
    jmp put_value.add_d
.X:
    mov al, [r15 + 2] ; bierzemy wartość x
.add_d:
    test r11b, 00002H ; sprawdzamy czy dodajemy D
    jz put_value.value_from_adress
    add al, [r15 + 1] ; moooooooooooooodullllllllllllllloooooooooooooooooo %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
.value_from_adress:
    mov [rsi + rax], r8b
    ret

SET_Z_FLAG: ;flaga Z jest ustawiona odpowiednio nie zmieniać argumentu 8! bo tam jest wynik operacji; zmienia r9 używa
    test r8, 000FFH ; jeśli dwa najmniej znaczące bity to 00
    jz SET_Z_FLAG.set_z
.unset_z:
    mov byte [r15 + 7], 0 ; w r15 wskaznik na rel registers
    ret
.set_z:
    mov byte [r15 + 7], 1
    ret
SET_C_FLAG: ;flaga C jest nie ustawiona; liczba przekroczyła zakres
    cmp r8, 000FFH ; jeśli dwa najbardziej znaczące bity to 00
    jg SET_Z_FLAG.set_z
.unset_c:
    mov byte [r15 + 6], 0 ; w r15 wskaznik na rel registers
    ret
.set_c:
    mov byte [r15 + 6], 1
    ret

SET_C_FLAG_SET: ;flaga C jest ustawiona odpowiednio nie zmieniać argumentu 8! bo tam jest wynik operacji; zmienia r9 używa
    jc SET_C_FLAG_SET.set_c
.unset_c:
    mov byte [r15 + 6], 0 ; w r15 wskaznik na rel registers
    ret
.set_c:
    mov byte [r15 + 6], 1
    ret
SET_C_LOCAL: ;ustawia lokalnie C flagę w zależności od C flagi w strukturze ; w r15 wskaznik na registers
    mov al, [r15 + 7]
    cmp al, 1
    je SET_C_LOCAL.set_c_flag
    clc ; czyści carry flag
    ret
.set_c_flag:
    stc ; ustawia carry flag
    ret




OR_INSTR: ; r8 wartosc arg1; r9 wartość arg2/imm; w r11 jest kod argumentu gdzie wpisac
    or r8b, r9b
    call SET_Z_FLAG
    call put_value
.push_value:
    call put_value
    ret
MOV_INSTR: ; r8 arg1 wartosc ; r9 arg2/imm ; r11 kod argumentu1 gdzie zapisujemy
    mov r8b, r9b
    call put_value
    ret
ADD_INSTR: ; r8 arg1 wartosc ; r9 arg2/imm ; r11 kod argumentu1 gdzie zapisujemy
    add r8b, r9b
    call SET_Z_FLAG
    call put_value
    ret
SUB_INSTR: ; r8 arg1 wartosc ; r9 arg2/imm ; r11 kod argumentu1 gdzie zapisujemy
    sub r8b, r9b
    call SET_Z_FLAG
    call put_value
    ret
ADC_INSTR: ; r8 arg1 wartosc ; r9 arg2/imm ; r11 kod argumentu1 gdzie zapisujemy -----------------------------------nope
    call SET_C_LOCAL
    adc r8b, r9b
    call SET_Z_FLAG
    call SET_C_FLAG
    call put_value
    ret
SBB_INSTR: ; r8 arg1 wartosc ; r9 arg2/imm ; r11 kod argumentu1 gdzie zapisujemy -----------------------------------nope
    call SET_C_LOCAL
    sbb r8b, r9b
    call SET_Z_FLAG
    call SET_C_FLAG
    call put_value
    ret
    
so_emul: ; rdi - kod; rsi - data; rdx - steps ;rcx - core;
    push r12 ; na nr instrukcji ktora teraz wykonuje 
    push r15 ; na rel registers
    lea r15, [rel registers]
    xor r12, r12
    mov r12b, [r15 + 4]; która instrukcja teraz wykonywana numer
    cmp rdx, 0 
    je end_f
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
    mov r11w, r8w ; skopiowwanie argumentu widoczonego
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
    call OR_INSTR
    jmp next
.add:
    test r10,3
    jnz two_arguments.sub
    call ADD_INSTR
    jmp next
.sub:
    test r10,2
    jnz two_arguments.adc
    call SUB_INSTR
    jmp next
.adc:
    test r10, 1
    jnz two_arguments.sbb
    call ADC_INSTR
    jmp next
.sbb:
    test r10, 0
    jnz next
    call SBB_INSTR
    jmp next
arg_and_imm:
    test r8w, 08000H; najbardziej znaczący bit musi być
    jnz none_arg ; do innej instrukcji może być jeszcze !!!!!!!!!!!!!!!!!!!!!!!!!!
    shl r8w, 5 ; wyciągamy bity 3-5 licząc od najbardziej znaczących; wyciągamy argument
    shr r8w, 13; 16 - ile zostawiamy
    mov r11w, r8w ;pomocniczo zapisujemy arguemnt1 
    call get_value
    mov r8b, al
    mov r9w, [rdi+r12*2]
    shl r9w, 8 ; obliczony imm8
    shr r9w, 8
    mov r10w, [rdi+r12*2] 
    shl r10w, 2 ; obliczamy instrukcje
    shr r10w, 13
.movi:
    test r10, 7 ; bo instruckcja movi jest jako 000
    jnz arg_and_imm.xori
    call MOV_INSTR
    jmp next
.xori:
    test r10, 5
    jnz arg_and_imm.addi
    xor r8w, r9w
    call SET_Z_FLAG
    call put_value
    jmp next
.addi:
    test r10, 3
    jnz arg_and_imm.cmpi
    add r8w, r9w
    call SET_Z_FLAG
    call put_value
    jmp next
.cmpi:
    test r10, 2
    jnz arg_and_imm.RCR
    cmp r8w, r9w
    call SET_Z_FLAG
    call SET_C_FLAG
    call put_value
    jmp next
.RCR:
    test r10, 1 ;bo bity mają być 0111 0___ 0000 0001 gdzie _ to argument czyli w 1000 1___ 1111 1110 
    jnz next
    ; napisać ..................................................................................................................
    xor r8, r8
    mov r8w, [rdi+r12*2]
    shl r8w, 5 ; obliczony arg1
    shr r8w, 13
    mov r11b, r8b 
    call get_value
    mov r8b, al
    ;dodaj  jak c jest
    cmp [r15 + 6], byte 0
    je .not_set_c
    add r8, 000100H ;dodawanie tej jedynki ktorą przesuwamy
.not_set_c:
    rcr r8, 1
    call SET_C_FLAG_SET
    call put_value
    jmp next
BRK:
    cmp r8w, 0FFFFH
    jne next
    add r12, 1; przechodzi na kolejny element moooooooooooooooddddddddddddullllllllo
    jmp end_f
none_arg:
.clc:
    cmp r8w, 08000H
    jne none_arg.stc
    mov [r15 + 6], byte 0
    ;...........................................................
    jmp next
.stc:
    cmp r8w, 08100H
    jne imm8
    mov [r15 + 6], byte 1
    jnz next
    ;...............................................................
imm8: ;JMP 1100 0iii ssss ssss i - instrukcja s -stała czyli w koniunkcji 0011 1___ ___ ___ _ cokolwiek
    test r8w, 03800H  
    jnz next
    xor r10,r10
    mov r10w, [rdi+r12*2]
    shl r10w, 5 ; obliczony instrukcje
    shr r10w, 13
    xor r8,r8 
    mov r8w, [rdi+r12*2]
    shl r8w, 8 ; obliczony imm8
    shr r8w, 8
    ; r10 instr r8 zmienna od skoku
.JMP:
    test r10, 7 ; bo jmp ma bity 000 więc w koniunkcji z 111 musi dać 0
    jnz imm8.JNC
    add r12w, r8w; overflow ?????????????????????????
    jmp next
.JNC:
    test r10, 5 ; bo jmp ma bity 000 więc w koniunkcji z 111 musi dać 0
    jnz imm8.JC
    xor r9, r9
    mov r9b, [r15 + 6] ; wartosc carry
    cmp r9, 0 ; ma być zero
    jne next
    add r12w, r8w
    jmp next
.JC:
    test r10, 4 ; bo jmp ma bity 000 więc w koniunkcji z 111 musi dać 0
    jnz imm8.JNZ
    xor r9, r9
    mov r9b, [r15 + 6] ; wartosc carry
    cmp r9, 1 ; ma być 1
    jne next
    add r12w, r8w
    ;.............................................................................................
    jmp next
.JNZ:
    test r10, 3 ; bo jmp ma bity 000 więc w koniunkcji z 111 musi dać 0
    jnz imm8.JZ
    xor r9, r9
    mov r9b, [r15 + 7] ; wartosc carry
    cmp r9, 0 ; ma być zero
    jne next
    add r12w, r8w 
    ;.............................................................................................
    jmp next
.JZ:
    test r10, 2 ; bo jmp ma bity 000 więc w koniunkcji z 111 musi dać 0
    jnz next
    xor r9, r9
    mov r9b, [r15 + 7] ; wartosc carry
    cmp r9, 1 ; ma być 1
    jne next
    add r12w, r8w 
    ;.............................................................................................
    jmp next

next: 
    dec rdx ; w rdx steps zmniejszenie wartości do wykonania
    add r12, 1 ; w r12 którą instrukcję wykonuję
    cmp rdx, 0 
    jne next_instruction
end_f:
    mov [r15+4], r12b ; zaktualizowanie 
    mov rax, [rel registers] ; wrzucenie tablicy do rax
    pop r15
    pop r12
    ret
