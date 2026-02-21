; ============================================================
; AurumDOS Bootloader
; Читает ядро в 2000:0000 и прыгает туда
; ============================================================
[BITS 16]
[ORG 0x7C00]
    jmp short main
    nop
    times 59 db 0

main:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    sti

    mov [bootDrive], dl

    mov si, msgLoad
    call Print

    ; Сбрасываем дисковый контроллер
    xor ax, ax
    mov dl, [bootDrive]
    int 0x13

    ; Ядро в FAT12 начинается с LBA сектора 33
    ; Конвертируем LBA 33 в CHS:
    ; LBA 33 / 18 = 1 остаток 15
    ; голова = 1 % 2 = 1, трек = 1 / 2 = 0
    ; CHS: трек=0, голова=1, сектор=16 (CHS нумерация с 1)
    mov byte [curTrack],  0
    mov byte [curHead],   1
    mov byte [curSector], 16

    mov ax, 0x2000
    mov es, ax
    xor bx, bx

    mov cx, SECTORS_TO_LOAD

.read_loop:
    push cx

    ; Читаем 1 сектор
    mov ah, 0x02
    mov al, 1
    mov ch, [curTrack]
    mov cl, [curSector]
    mov dh, [curHead]
    mov dl, [bootDrive]
    int 0x13
    jc .err

    ; Двигаем буфер
    add bx, 512
    jnc .no_seg_fix
    mov ax, es
    add ax, 0x1000
    mov es, ax
.no_seg_fix:

    ; Следующий сектор
    inc byte [curSector]
    cmp byte [curSector], 19
    jl .next

    mov byte [curSector], 1
    inc byte [curHead]
    cmp byte [curHead], 2
    jl .next

    mov byte [curHead], 0
    inc byte [curTrack]

.next:
    pop cx
    loop .read_loop

    mov si, msgOK
    call Print

    push word 0x2000
    push word 0x0000
    retf

.err:
    pop cx
    mov si, msgErr
    call Print
    xor ah, ah
    int 0x16
    int 0x19

Print:
    pusha
.lp:
    lodsb
    or al, al
    jz .dn
    mov ah, 0x0E
    mov bh, 0
    int 0x10
    jmp .lp
.dn:
    popa
    ret

SECTORS_TO_LOAD equ 200

bootDrive  db 0
curTrack   db 0
curHead    db 0
curSector  db 0

msgLoad db "AurumDOS loading...", 13, 10, 0
msgOK   db "OK!", 13, 10, 0
msgErr  db "Disk error! Press any key...", 13, 10, 0

times 510 - ($ - $$) db 0
dw 0xAA55