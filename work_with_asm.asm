section .bss                    ; использование меток для хранения

    buf     resb 32             ; общий буфер, используемый _prnuint32
    bufa    resb 8              ; хранение первой строки буквы
    bufb    resb 8              ; хранилище для второй строки буквы
    lena    resb 4              ; длина первой строки буквы
    lenb    resb 4              ; длина второй строки буквы
    nch     resb 1              ; количество цифровых символов в _prnuint32
    ais     resb 1              ; 1й символ: 0-не альфа, 1-верхний, 2-нижний
    bis     resb 1              ; то же самое для 2го символа
   



section .data

    bufsz:  equ 32
    babsz:  equ 8
    tmsg:   db "first letter : "
    tlen:   equ $-tmsg
    ymsg:   db "second letter: "
    ylen:   equ $-ymsg
    dmsg:   db "char distance: "
    dlen:   equ $-dmsg
    emsg:   db "error", 0xa
    elen:   equ $-emsg
    nl:     db 0xa
    stdin:  equ 0               ; файл записывает свои запросы для запуска задачи в процессе
    stdout: equ 1               ; файл который ядро записывает свои выходные данные а запрашивающий его процесс обращается к информации
    read:   equ 3
    write:  equ 4
    exit:   equ 1


section .text
    global _start:
_start:
    mov     byte[ais], 0        ; нулевой флаг
    mov     byte[bis], 0
    
    mov     eax, write          ; подсказка для 1-й буквы
    mov     ebx, stdout
    mov     ecx, tmsg
    mov     edx, tlen
    int 80h                     ; __NR_write
    
    mov     eax, read           ; читать 1-ю буквенную строку
    mov     ebx, stdin
    mov     ecx, bufa
    mov     edx, babsz
    int 80h                     ; __NR_read
    
    mov     [lena], eax         ; сохранить номер символа в строке
    
; проверка ввода регистра
    call    _isupr              ; проверяет есть ли заглавные буквы
    cmp     eax, 1              ; проверяет возврат 0 или 1 (булева шняга)
    jne chkalwr                 ; если нет - переходит на проверку нижнего регистра
    
    mov     byte[ais], 1        ; установить флаг верхнего регистра для 1й буквы
    
    jmp getb                    ; ветвь на вторую строку
    
  chkalwr:
    call    _islwr              ; проверка в нижнем регистре
    cmp     eax, 1              ; проверка возврата
    jne notalpha                ; если первая буква не альфасимвол то ошибка
    
    mov     byte[ais], 2        ; установка флага нижнего регистра для 1ой буквы
    
  getb:                         ; второй символ
    mov     eax, write          ; подсказка для 2-й буквы
    mov     ebx, stdout
    mov     ecx, ymsg
    mov     edx, ylen
    int 80h                     ; __NR_write
    
    mov     eax, read           ; читать 2ую буквенную строку
    mov     ebx, stdin
    mov     ecx, bufb
    mov     edx, babsz
    int 80h                     ; __NR_read
    
    mov     [lenb], eax         ; сохранить номер символа в строке


; проверка ввода регистра
    call    _isupr              ; проверяет есть ли заглавные буквы
    cmp     eax, 1              ; проверяет возврат 0 или 1 (булева шняга)
    jne chkblwr                 ; если нет - переходит на проверку нижнего регистра
    
    mov     byte[bis], 1        ; установить флаг верхнего регистра для 2й буквы
    
    jmp chkboth

chkblwr:
    call    _islwr              ; проверка в нижнем регистре
    cmp     eax, 1              ; проверка возврата
    jne notalpha                ; если первая буква не альфа то ошибка
    
    mov     byte[bis], 2        ; установка флага нижнего регистра для 2ой буквы


chkboth:
    mov     al, byte[ais]       ; загрузка флагов в al, bl
    mov     bl, byte[bis]
    cmp     al, bl              ; равны ли флаги
    jne notalpha
    
    mov     eax, write          ; отображать вывод расстояния
    mov     ebx, stdout
    mov     ecx, dmsg
    mov     edx, dlen
    int 80h                     ; __NR_write
    
    mov     al, byte[bufa]      ; загрузка символа в al, bl
    mov     bl, byte[bufb]
    cmp     al, bl              ; равны ли символы 
    
    jns getdiff                 ; 1ый char >= 2ой char
    
    push    eax                 ; поменять местами символы
    push    ebx
    pop     eax
    pop     ebx

 getdiff:
    sub     eax, ebx            ; 1ый символ минус 2ой (а-б = ...)
    call _prnuint32             ; вывод разницы
    
    xor     ebx, ebx            ; установить EXIT_SUCCESS
    jmp     done

notalpha:                     ; notalpha = блок для вывода ошибки если символ не альфасимфол или регистры разные (не совпадают)

    mov     eax, write
    mov     ebx, stdout
    mov     ecx, emsg
    mov     edx, elen
    int 80h                     ; __NR_write
    
    mov     ebx, 1              ; установка EXIT_FAILURE

done:
    mov     eax, exit           ; __NR_exit
    int 80h

; вывод 32битного числа с помощью stdout
; аргументы:
;   eax - номер для вывода
; вывод:
;   нуль
_prnuint32:
    mov     byte[nch], 0        ; нулевой счетчик 
    
    mov     ecx, 0xa            ; base 10  (и новая строка)
    lea     esi, [buf + 31]     ; загрузить адрес последнего символа в buf
    mov     [esi], cl           ; put newline in buf
    inc     byte[nch]           ; увеличить количество символов в buf

_todigit:                       ; do {
    xor     edx, edx            ; регистр нулевого остатка
    div     ecx                 ; edx = остаток = последняя цифра = 0..9.  eax/=10
    
    or      edx, '0'            ; конвертация в ASCII
    dec     esi                 ; резервное копирование на следующий символ в buf
    mov     [esi], dl           ; скопировать ASCII в buf
    inc     byte[nch]           ; увеличить количество символов в buf

    test    eax, eax            ; } while (eax);
    jnz     _todigit

    mov     eax, 4              ; __NR_write from /usr/include/asm/unistd_32.h
    mov     ebx, 1              ; fd = STDOUT_FILENO
    mov     ecx, esi            ; скопировать адрес из esi в ecx (адрес 1-й буквы)
                                ; вычитание чтобы узнать длину
    mov     dl, byte[nch]       ; длина, включая \n
    int     80h                 ; write(1, string,  digits + 1)

    ret

; проверить, если символ islower() 
; параметры:
;   ecx - адрес удерживающий символ
; вывод:
;   eax - 0 или 1 (булева щняга снова)
_islwr:
    
    mov eax, 1                  ; возрват 1 (истины)
    
    cmp byte[ecx], 'a'          ; сравнить с "а"
    jge _chkz                   ; char >= 'a'
    
    mov eax, 0                  ; возрват 0 (ложь)
    ret
    
  _chkz:
    cmp byte[ecx], 'z'          ; сравниь с 'z'
    jle _rtnlwr                 ; <= нижний регистр (lowercase)
    
    mov eax, 0                  ;возврат 0 (ложь)
    
  _rtnlwr:
    ret


; проверить есть ли символ isupper()
; параметры:
;   ecx - адрес удерживающий символ
; вывод:
;   eax - 0 или 1 (булевааааа)
_isupr:
    
    mov eax, 1                  ; возврат 1 (истина)
    
    cmp byte[ecx], 'A'          ; сравнить с 'A'
    jge _chkZ                   ; char >= 'A'
    
    mov eax, 0                  ; возврат 0 (ложь)
    ret
    
  _chkZ:
    cmp byte[ecx], 'Z'          ; сравнить с 'Z'
    jle _rtnupr                 ; <= верхний регистр (uppercase)
    
    mov eax, 0                  ; возврат 0 (лооожь)
    
  _rtnupr:
    ret
