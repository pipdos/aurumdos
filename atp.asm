; ==================================================================
; ATPF Spreadsheet for AurumDOS
; COM file, loaded at segment 0x2000, offset 0x8000 (call 32768)
; DS = 0x2000 when running
; int 22h for filesystem
; ==================================================================
[BITS 16]
[ORG 0x8000]        ; kernel executes us via "call 32768"

TABLE_ROWS  equ 18
TABLE_COLS  equ 7
COL_W       equ 10
CELL_SZ     equ 10
ROW_W       equ 4

C_NORM  equ 0x07
C_HEAD  equ 0x70
C_SEL   equ 0x1F
C_STAT  equ 0x17
C_INP   equ 0x0F
C_REF   equ 0x0B
C_ERR   equ 0x4F

SK_UP    equ 0x48
SK_DOWN  equ 0x50
SK_LEFT  equ 0x4B
SK_RIGHT equ 0x4D
SK_DEL   equ 0x53
SK_F2    equ 0x3C
SK_F3    equ 0x3D

CH_ENTER equ 0x0D
CH_ESC   equ 0x1B
CH_BS    equ 0x08
CH_TAB   equ 0x09

; ==================================================================
_start:
    ; DS уже = 0x2000 от ядра, не меняем
    ; Сохраним стек ядра и сделаем свой
    mov [saved_sp], sp
    mov [saved_ss], ss

    ; Очистим экран (режим 3 уже установлен ядром)
    ; Просто зальём атрибутом C_NORM
    call clr

    call table_clear
    call redraw

.loop:
    xor ax, ax
    int 16h
    call on_key
    jmp .loop

; ==================================================================
; Возврат в ядро
; ==================================================================
do_return:
    ; восстановить экран ядра не нужно - ядро само напечатает prompt
    mov ss, [saved_ss]
    mov sp, [saved_sp]
    ; очистить экран перед возвратом
    call clr
    ret                 ; возврат в kernel execute_bin -> get_cmd

; ==================================================================
; Очистка экрана через BIOS scroll
; ==================================================================
clr:
    push ax
    push bx
    push cx
    push dx
    mov ax, 0x0600      ; scroll up, 0 lines = clear
    mov bh, C_NORM
    xor cx, cx
    mov dx, 0x184F      ; row 24, col 79
    int 10h
    ; курсор в 0,0
    mov ah, 0x02
    xor bh, bh
    xor dx, dx
    int 10h
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ==================================================================
; Скрыть/показать курсор
; ==================================================================
hide_cur:
    push ax
    push cx
    mov ah, 0x01
    mov cx, 0x2000
    int 10h
    pop cx
    pop ax
    ret

show_cur:
    push ax
    push cx
    mov ah, 0x01
    mov cx, 0x0607
    int 10h
    pop cx
    pop ax
    ret

; ==================================================================
; Установить позицию курсора: DH=row, DL=col
; ==================================================================
setpos:
    push ax
    push bx
    mov ah, 0x02
    xor bh, bh
    int 10h
    pop bx
    pop ax
    ret

; ==================================================================
; Вывод символа AL с атрибутом BL в позиции DH,DL
; Не двигает курсор
; ==================================================================
pc:
    push ax
    push bx
    push cx
    push dx
    ; установить позицию
    mov ah, 0x02
    xor bh, bh
    int 10h
    ; вывести символ с атрибутом
    mov ah, 0x09
    mov bh, 0           ; страница 0
    ; bl = атрибут (уже в BL)
    mov cx, 1
    int 10h
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ==================================================================
; Вывод строки ASCIIZ: SI=str, BL=attr, DH=row, DL=col
; Инкрементирует DL
; ==================================================================
ps:
    push ax
    push si
.l:
    lodsb
    cmp al, 0
    je .d
    call pc
    inc dl
    jmp .l
.d:
    pop si
    pop ax
    ret

; ==================================================================
; Заполнить CX символов AL с атрибутом BL начиная с DH,DL
; ==================================================================
pf:
    push cx
.l:
    cmp cx, 0
    je .d
    call pc
    inc dl
    dec cx
    jmp .l
.d:
    pop cx
    ret

; Заполнить пробелами
psp:
    push ax
    mov al, ' '
    call pf
    pop ax
    ret

; ==================================================================
; ИНИЦИАЛИЗАЦИЯ
; ==================================================================
table_clear:
    push ax
    push cx
    push di
    mov di, cells
    mov cx, TABLE_ROWS * TABLE_COLS * CELL_SZ
    xor al, al
    rep stosb
    mov byte [cur_r], 0
    mov byte [cur_c], 0
    mov byte [editing], 0
    mov byte [edit_len], 0
    mov byte [fname], 0
    pop di
    pop cx
    pop ax
    ret

; ==================================================================
; АДРЕС ЯЧЕЙКИ: g_r, g_c -> BX
; ==================================================================
cp:
    push ax
    push cx
    push dx          ; mul portit DX (= DH stroki ekrana), sohranyaem
    xor ah, ah
    mov al, [g_r]
    mov cl, TABLE_COLS
    mul cl           ; ax = row * TABLE_COLS, dx = 0
    xor ch, ch
    mov cl, [g_c]
    add ax, cx       ; ax = row*COLS + col
    mov cx, CELL_SZ
    mul cx           ; ax = offset, dx = 0
    add ax, cells
    mov bx, ax
    pop dx           ; vosstanovit DH
    pop cx
    pop ax
    ret

; ==================================================================
; ОБРАБОТКА КЛАВИШ
; ==================================================================
on_key:
    cmp byte [editing], 1
    je edit_key

    cmp al, 0
    je .spec
    cmp al, CH_ESC
    je .esc
    cmp al, CH_ENTER
    je .ent
    cmp al, CH_TAB
    je .tab
    cmp al, 0x20
    jl .ret
    ; начать ввод
    mov [edit_buf], al
    mov byte [edit_buf+1], 0
    mov byte [edit_len], 1
    mov byte [editing], 1
    call redraw
    ret
.esc:   call ask_exit
ret
.ent:   call nav_down
call redraw
ret
.tab:   call nav_right
call redraw
ret
.ret:   ret
.spec:
    cmp ah, SK_UP   
    jne .sd
    call nav_up     
    call redraw
    ret
.sd:
    cmp ah, SK_DOWN 
    jne .sl
    call nav_down   
    call redraw
    ret
.sl:
    cmp ah, SK_LEFT 
    jne .sr
    call nav_left   
    call redraw
    ret
.sr:
    cmp ah, SK_RIGHT
    jne .sdel
    call nav_right  
    call redraw
    ret
.sdel:
    cmp ah, SK_DEL  
    jne .sf2
    call cell_del   
    call redraw
    ret
.sf2:
    cmp ah, SK_F2   
    jne .sf3
    call do_save    
    ret
.sf3:
    cmp ah, SK_F3   
    jne .sx
    call do_load    
    ret
.sx:    ret

edit_key:
    cmp al, CH_ENTER
    je .ced
    cmp al, CH_TAB  
    je .cet
    cmp al, CH_ESC  
    je .cesc
    cmp al, CH_BS   
    je .cbs
    cmp al, 0       
    je .ret
    cmp al, 0x20    
    jl .ret
    xor bh, bh
    mov bl, [edit_len]
    cmp bl, CELL_SZ-2
    jge .ret
    mov [edit_buf+bx], al
    inc byte [edit_len]
    mov bl, [edit_len]
    mov byte [edit_buf+bx], 0
    call redraw
    ret
.cbs:
    cmp byte [edit_len], 0
    je .ret
    dec byte [edit_len]
    xor bh, bh
    mov bl, [edit_len]
    mov byte [edit_buf+bx], 0
    cmp byte [edit_len], 0
    jne .r2
    mov byte [editing], 0
.r2:
    call redraw
    ret
.ced:
    call commit
    call nav_down
    call redraw
    ret
.cet:
    call commit
    call nav_right
    call redraw
    ret
.cesc:
    mov byte [editing], 0
    mov byte [edit_len], 0
    mov byte [edit_buf], 0
    call redraw
    ret
.ret:   ret

commit:
    mov al, [cur_r]
    mov [g_r], al
    mov al, [cur_c]
    mov [g_c], al
    call cp
    mov si, edit_buf
    mov di, bx
    mov cx, CELL_SZ
.lp:
    lodsb
    stosb
    cmp al, 0
    je .pad
    dec cx
    jnz .lp
    jmp .done
.pad:
    dec cx
    jz .done
    xor al, al
    rep stosb
.done:
    mov byte [editing], 0
    mov byte [edit_len], 0
    ret

cell_del:
    mov al, [cur_r]
    mov [g_r], al
    mov al, [cur_c]
    mov [g_c], al
    call cp
    mov di, bx
    mov cx, CELL_SZ
    xor al, al
    rep stosb
    ret

; ==================================================================
; НАВИГАЦИЯ
; ==================================================================
nav_up:
    cmp byte [cur_r], 0
    je .s
    dec byte [cur_r]
.s: ret
nav_down:
    mov al, [cur_r]
    cmp al, TABLE_ROWS-1
    je .s
    inc byte [cur_r]
.s: ret
nav_left:
    cmp byte [cur_c], 0
    je .s
    dec byte [cur_c]
.s: ret
nav_right:
    mov al, [cur_c]
    cmp al, TABLE_COLS-1
    je .s
    inc byte [cur_c]
.s: ret

; ==================================================================
; ОТРИСОВКА
; ==================================================================
redraw:
    call hide_cur
    call d_header
    call d_cols
    call d_grid
    call d_editbar
    call d_refbar
    ret

; --- Заголовок (строка 0) ---
d_header:
    mov dh, 0
    mov dl, 0
    mov bl, C_HEAD
    mov cx, 80
    call psp
    mov dh, 0
    mov dl, 2
    mov bl, C_HEAD
    mov si, s_title
    call ps
    ret

; --- Буквы столбцов (строка 1) ---
d_cols:
    mov dh, 1
    mov dl, 0
    mov bl, C_HEAD
    mov cx, 80
    call psp
    ; пробелы под номер строки
    mov dh, 1
    mov dl, 0
    mov bl, C_HEAD
    mov cx, ROW_W
    call psp
    ; A..G
    mov byte [d_ci], 0
    mov byte [d_cl], 'A'
    mov dl, ROW_W
.lp:
    cmp byte [d_ci], TABLE_COLS
    je .done
    push dx
    mov dh, 1
    ; разделитель
    mov al, '|'
    mov bl, C_HEAD
    call pc
    inc dl
    ; пробелы + буква + пробелы  (COL_W-1 = 9 символов)
    mov al, ' '
    mov cx, 3
    call pf   ; 3 пробела слева
    mov al, [d_cl]
    call pc
    inc dl
    mov al, ' '
    mov cx, 5
    call pf   ; 5 пробелов справа
    pop dx
    add dl, COL_W
    inc byte [d_cl]
    inc byte [d_ci]
    jmp .lp
.done:
    ret

; --- Сетка ---
d_grid:
    mov byte [g_r], 0
.rl:
    cmp byte [g_r], TABLE_ROWS
    je .done
    ; экранная строка
    mov al, [g_r]
    add al, 2
    mov dh, al
    ; очистить строку
    mov dl, 0
    mov bl, C_NORM
    mov cx, 80
    call psp
    ; номер строки
    mov dl, 0
    mov al, [g_r]
    inc al
    call draw_rnum

    mov byte [g_c], 0
    mov dl, ROW_W
.cl:
    cmp byte [g_c], TABLE_COLS
    je .nc
    ; атрибут
    mov al, [g_r]
    cmp al, [cur_r]
    jne .na
    mov al, [g_c]
    cmp al, [cur_c]
    jne .na
    mov byte [tmp_a], C_SEL
    jmp .ad
.na:
    mov byte [tmp_a], C_NORM
.ad:
    push dx
    ; разделитель
    mov bl, [tmp_a]
    mov al, '|'
    call pc
    inc dl
    ; содержимое ячейки
    call cp         ; -> BX (g_r, g_c уже установлены выше)
    mov si, bx
    mov bl, [tmp_a]
    mov cx, COL_W-1
.ch:
    mov al, [si]
    cmp al, 0
    je .pd
    call pc
    inc dl
    inc si
    dec cx
    jnz .ch
    jmp .ce
.pd:
    cmp cx, 0
    je .ce
    mov al, ' '
    call pc
    inc dl
    dec cx
    jmp .pd
.ce:
    pop dx
    add dl, COL_W
    inc byte [g_c]
    jmp .cl
.nc:
    inc byte [g_r]
    jmp .rl
.done:
    ret

; номер строки AL (1-based), DH=экр.строка, DL=0
draw_rnum:
    push ax
    push bx
    mov bl, C_HEAD
    ; формат: " %2d " (4 символа)
    mov byte [rn+0], ' '
    mov byte [rn+1], ' '
    mov byte [rn+2], ' '
    mov byte [rn+3], ' '
    mov byte [rn+4], 0
    cmp al, 10
    jl .one
    xor ah, ah
    mov cl, 10
    div cl
    add al, '0'
    mov [rn+1], al
    add ah, '0'
    mov [rn+2], ah
    jmp .pr
.one:
    add al, '0'
    mov [rn+2], al
.pr:
    mov si, rn
    call ps
    pop bx
    pop ax
    ret

; --- Строка ввода (строка TABLE_ROWS+2) ---
d_editbar:
    mov dh, TABLE_ROWS+2
    mov dl, 0
    cmp byte [editing], 1
    je .show

    ; подсказка
    mov bl, C_STAT
    mov cx, 80
    call psp
    mov dh, TABLE_ROWS+2
    mov dl, 0
    mov bl, C_STAT
    mov si, s_hint
    call ps
    ret
.show:
    mov bl, C_INP
    mov cx, 80
    call psp
    mov dh, TABLE_ROWS+2
    mov dl, 0
    mov bl, C_INP
    mov al, '>'
    call pc
    inc dl
    mov si, edit_buf
    call ps
    ; показать аппаратный курсор
    xor ah, ah
    mov al, [edit_len]
    inc al              ; после '>'
    mov dl, al
    mov dh, TABLE_ROWS+2
    call setpos
    call show_cur
    ret

; --- Строка ссылки (строка TABLE_ROWS+3) ---
d_refbar:
    mov al, TABLE_ROWS+3
    cmp al, 24
    jge .skip
    mov dh, TABLE_ROWS+3
    mov dl, 0
    mov bl, C_STAT
    mov cx, 80
    call psp
    mov dh, TABLE_ROWS+3
    mov dl, 0
    mov bl, C_REF
    ; буква столбца
    mov al, [cur_c]
    add al, 'A'
    call pc
    inc dl
    ; цифры строки
    mov al, [cur_r]
    inc al
    cmp al, 10
    jl .one
    xor ah, ah
    mov cl, 10
    div cl
    add al, '0'
    call pc
    inc dl
    add ah, '0'
    mov al, ah
    call pc
    inc dl
    jmp .col
.one:
    add al, '0'
    call pc
    inc dl
.col:
    mov al, ':'
    call pc
    inc dl
    mov al, ' '
    call pc
    inc dl
    ; значение ячейки
    mov al, [cur_r]
    mov [g_r], al
    mov al, [cur_c]
    mov [g_c], al
    call cp
    mov si, bx
    call ps
    ; имя файла справа
    mov dl, 52
    mov bl, C_STAT
    mov si, s_fl
    call ps
    mov si, fname
    cmp byte [si], 0
    jne .sf
    mov si, s_new
.sf:
    call ps
.skip:
    ret

; ==================================================================
; СОХРАНЕНИЕ / ЗАГРУЗКА
; ==================================================================
do_save:
    call hide_cur
    call ask_name
    cmp byte [ask_buf], 0
    je .done
    call add_ext
    call w_atpf
    jc .err
    call cp_name
    call msg_ok
    call redraw
    ret
.err:
    call msg_err
    call redraw
    ret
.done:
    call redraw
    ret

do_load:
    call hide_cur
    call ask_name
    cmp byte [ask_buf], 0
    je .done
    call add_ext
    call r_atpf
    jc .err
    call cp_name
    call msg_ok
    call redraw
    ret
.err:
    call msg_err
    call redraw
    ret
.done:
    call redraw
    ret

ask_name:
    mov dh, TABLE_ROWS+2
    mov dl, 0
    mov bl, C_INP
    mov cx, 80
    call psp
    mov dh, TABLE_ROWS+2
    mov dl, 0
    mov bl, C_INP
    mov si, s_fn
    call ps
    ; очистить буфер
    mov di, ask_buf
    mov cx, 16
    xor al, al
    rep stosb
    ; показать курсор ввода
    mov dl, 11
    mov dh, TABLE_ROWS+2
    call setpos
    call show_cur
    mov di, ask_buf
    mov byte [ac], 0
.lp:
    xor ax, ax
    int 16h
    cmp al, CH_ENTER
    je .done
    cmp al, CH_ESC
    je .cancel
    cmp al, CH_BS
    je .bs
    cmp al, 0
    je .lp
    cmp byte [ac], 12
    jge .lp
    stosb
    inc byte [ac]
    ; показать символ
    push ax
    mov bl, C_INP
    mov dl, 11
    add dl, [ac]
    dec dl
    mov dh, TABLE_ROWS+2
    call pc
    mov dl, 11
    add dl, [ac]
    mov dh, TABLE_ROWS+2
    call setpos
    pop ax
    jmp .lp
.bs:
    cmp byte [ac], 0
    je .lp
    dec di
    mov byte [di], 0
    dec byte [ac]
    push ax
    mov al, ' '
    mov bl, C_INP
    mov dl, 11
    add dl, [ac]
    mov dh, TABLE_ROWS+2
    call pc
    mov dl, 11
    add dl, [ac]
    mov dh, TABLE_ROWS+2
    call setpos
    pop ax
    jmp .lp
.cancel:
    mov byte [ask_buf], 0
.done:
    mov byte [di], 0
    call hide_cur
    ret

add_ext:
    push si
    mov si, ask_buf
.sc:
    lodsb
    cmp al, 0
    je .add
    cmp al, '.'
    je .has
    jmp .sc
.add:
    dec si
    mov byte [si+0], '.'
    mov byte [si+1], 'A'
    mov byte [si+2], 'T'
    mov byte [si+3], 'P'
    mov byte [si+4], 'F'
    mov byte [si+5], 0
.has:
    pop si
    ret

uc_buf:
    push si
    push ax
    mov si, ask_buf
.lp:
    lodsb
    cmp al, 0
    je .d
    cmp al, 'a'
    jl .n
    cmp al, 'z'
    jg .n
    sub al, 32
    mov [si-1], al
.n: jmp .lp
.d: pop ax
pop si
ret

w_atpf:
    push si
    push di
    push bx
    push cx
    mov di, fbuf
    mov byte [di], 'A'
    inc di
    mov byte [di], 'T'
    inc di
    mov byte [di], 'P'
    inc di
    mov byte [di], 'F'
    inc di
    mov byte [di], TABLE_ROWS
    inc di
    mov byte [di], TABLE_COLS
    inc di
    mov byte [di], CELL_SZ
    inc di
    mov byte [di], 0
    inc di
    mov si, cells
    mov cx, TABLE_ROWS * TABLE_COLS * CELL_SZ
.cp:
    lodsb
    stosb
    loop .cp
    mov cx, di
    sub cx, fbuf
    call uc_buf
    mov si, ask_buf
    mov bx, fbuf
    mov ah, 0x03
    int 22h
    pop cx
    pop bx
    pop di
    pop si
    ret

r_atpf:
    push si
    push di
    push bx
    push cx
    call uc_buf
    mov si, ask_buf
    mov cx, fbuf
    mov ah, 0x02
    int 22h
    jc .err
    mov si, fbuf
    cmp byte [si+0], 'A'
    jne .bad
    cmp byte [si+1], 'T'
    jne .bad
    cmp byte [si+2], 'P'
    jne .bad
    cmp byte [si+3], 'F'
    jne .bad
    call table_clear
    mov si, fbuf+8
    mov di, cells
    mov cx, TABLE_ROWS * TABLE_COLS * CELL_SZ
.cp:
    lodsb
    stosb
    loop .cp
    pop cx
    pop bx
    pop di
    pop si
    clc
    ret
.bad:
.err:
    pop cx
    pop bx
    pop di
    pop si
    stc
    ret

cp_name:
    push si
    push di
    push ax
    mov si, ask_buf
    mov di, fname
.cp:
    lodsb
    stosb
    cmp al, 0
    jne .cp
    pop ax
    pop di
    pop si
    ret

msg_ok:
    mov dh, TABLE_ROWS+2
    mov dl, 0
    mov bl, C_STAT
    mov cx, 80
    call psp
    mov dh, TABLE_ROWS+2
    mov dl, 1
    mov bl, C_STAT
    mov si, s_ok
    call ps
    xor ax, ax
    int 16h
    ret

msg_err:
    mov dh, TABLE_ROWS+2
    mov dl, 0
    mov bl, C_ERR
    mov cx, 80
    call psp
    mov dh, TABLE_ROWS+2
    mov dl, 1
    mov bl, C_ERR
    mov si, s_er
    call ps
    xor ax, ax
    int 16h
    ret

ask_exit:
    mov dh, TABLE_ROWS+2
    mov dl, 0
    mov bl, C_INP
    mov cx, 80
    call psp
    mov dh, TABLE_ROWS+2
    mov dl, 1
    mov bl, C_INP
    mov si, s_qt
    call ps
.w:
    xor ax, ax
    int 16h
    cmp al, 'y'
    je .yes
    cmp al, 'Y'
    je .yes
    cmp al, 'n'
    je .no
    cmp al, 'N'
    je .no
    cmp al, CH_ESC
    je .no
    jmp .w
.yes:
    call do_return
    ret             ; сюда не доходим
.no:
    call redraw
    ret

; ==================================================================
; ДАННЫЕ
; ==================================================================
s_title db 'Table Processor v1.0  |  F2=Save  F3=Load  ESC=Quit | by pip', 0
s_hint  db ' Arrows:Move  Type:Edit  Enter/Tab:OK  Del:Clear  F2:Save  F3:Load', 0
s_fn    db 'Filename:', 0
s_ok    db 'Saved! Press any key...', 0
s_er    db 'ERROR! Press any key...', 0
s_qt    db 'Quit? (Y/N)', 0
s_fl    db 'File:', 0
s_new   db '(new)', 0

saved_sp dw 0
saved_ss dw 0
cur_r   db 0
cur_c   db 0
editing db 0
edit_len db 0
tmp_a   db 0
d_ci    db 0
d_cl    db 0
ac      db 0
g_r     db 0
g_c     db 0

edit_buf times 16 db 0
ask_buf  times 16 db 0
fname    times 16 db 0
rn       times  6 db 0

cells:
    times TABLE_ROWS * TABLE_COLS * CELL_SZ db 0

fbuf:
    times TABLE_ROWS * TABLE_COLS * CELL_SZ + 64 db 0