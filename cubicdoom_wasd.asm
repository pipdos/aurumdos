;
; CubicDoom WASD (non-bootable program build)
; Original by Oscar Toledo G.
; Adapted for plain BIN program execution (AurumDOS style).
; Controls: W/A/S/D, arrows, Space shoot, Esc exit.
;

cpu 8086
[BITS 16]
[ORG 0x8000]

EMPTY:  equ 0x00        ; Code for empty space
WALL:   equ 0x80        ; Code for wall
ENEMY:  equ 0xc0        ; Code for enemy, includes shot count

down:   equ 0x000b      ; Enemies down
shot:   equ 0x000a      ; Shot made
rnd:    equ 0x0008      ; Random number
px:     equ 0x0006      ; Current X position (4.12)
py:     equ 0x0004      ; Current Y position (4.12)
pa:     equ 0x0002      ; Current screen angle
oldtim: equ 0x0000      ; Old time

maze:   equ 0xff00      ; Location of maze (16x16)

;
; Start of the game
;
start:
        mov ax,0x0013   ; Graphics mode 320x200x256 colors
        int 0x10
        mov ax,0xa000   ; Point to video memory.
        mov ds,ax
        mov es,ax

restart:
        cld
        xor cx,cx
        push cx         ; shot+down
        in ax,0x40
        push ax         ; rnd
        mov ah,0x18     ; Start point at maze
        push ax         ; px
        push ax         ; py
        mov cl,0x04
        push cx         ; pa
        push cx         ; oldtim
        mov bp,sp       ; Setup BP to access variables

        mov bx,maze     ; Point to maze
.0:     mov al,bl
        add al,0x11     ; Right and bottom borders at zero
        cmp al,0x22     ; Inside any border?
        jb .5
        and al,0x0e     ; Inside left/right border?
        mov al,EMPTY
        jne .4
.5:     mov al,WALL
.4:     mov [bx],al     ; Put into maze
        inc bx          ; Next square
        jne .0          ; If BX is zero, maze completed

        mov cl,12       ; 12 walls and enemies
        mov [bp+down],cl
        mov di,maze+34  ; Point to center of maze
        mov dl,12       ; Modulo 12 for random number
.2:
        call random
        mov byte [di+bx],WALL
        call random
        mov byte [di+bx],ENEMY
        add di,byte 16
        loop .2

game_loop:
        call wait_frame

        and dl,31       ; 32 frames have passed?
        jnz .16
        ;
        ; Move cubes
        ;
        call get_dir    ; Get player position, also SI=0
        call get_pos    ; Convert position to maze address
        mov cx,bx       ; Save into CX

        mov bl,0        ; BH already ready, start at corner

.17:    cmp byte [bx],ENEMY
        jb .18
        cmp bx,cx       ; Cube over player?
        jne .25
        ;
        ; Handle death
        ;
.22:
        mov byte [si],0x0c
        add si,byte 23
.23:
        je restart
        jnb .22
        push si
        call wait_frame
        pop si
        jmp .22

.25:
        mov di,bx
        mov al,bl
        mov ah,cl
        mov dx,0x0f0f
        and dx,ax
        xor ax,dx
        cmp ah,al
        je .19
        lea di,[bx+0x10]        ; Cube moves down
        jnb .19
        lea di,[bx-0x10]        ; Cube moves up
.19:    cmp dh,dl
        je .20
        dec di                  ; Cube goes left
        jb .20
        inc di                  ; Cube goes right
        inc di
.20:    cmp byte [di],0
        jne .18
        mov al,[bx]
        mov byte [bx],0
        stosb
.18:
        inc bx
        jne .17

.16:
        ;
        ; Draw 3D view
        ;
        mov di,39
.2:
        lea ax,[di-20]
        add ax,[bp+pa]
        call get_dir
.3:
        call read_maze
        jnc .3

.4:
        mov cx,0x1204   ; Add grayscale color set, CL=4
        jz .24          ; Jump if normal wall
        mov ch,32       ; Rainbow

        cmp di,byte 20
        jne .24
        cmp byte [bp+shot],1
        je .24
        call get_pos
        inc byte [bx]
        cmp byte [bx],ENEMY+3
        jne .24
        mov byte [bx],0
        dec byte [bp+down]
        je .23
.24:
        lea ax,[di+12]
        call get_sin
        mul si
        mov bl,ah
        mov bh,dl
        inc bx

        mov ax,0x0800
        cwd
        div bx
        cmp ax,198
        jb .14
        mov ax,198
.14:    mov si,ax

        shr ax,cl
        add al,ch
        xchg ax,bx

        push di
        dec cx          ; CL=3. Multiply column by 8 pixels
        shl di,cl

        mov ax,200
        sub ax,si
        shr ax,1

        push ax
        push si
        xchg ax,cx
        mov al,[bp+shot]
        call fill_column
        xchg ax,bx
        pop cx
        call fill_column
        mov al,0x03
        pop cx
        call fill_column
        pop di
        dec di
        jns .2

        ; WASD controls + Space shot, Esc exit.
        ; A / Left  = turn left
        ; D / Right = turn right
        ; W / Up    = move forward
        ; S / Down  = move backward
        ; Space     = shoot
        mov bx,[bp+pa]
        mov byte [bp+shot],1

.key_loop:
        mov ah,0x01
        int 0x16
        jz .store_angle

        mov ah,0x00
        int 0x16

        cmp al,0x1B
        je exit_game

        ; Rotate left
        cmp al,'a'
        je .turn_left
        cmp al,'A'
        je .turn_left
        cmp ah,0x4B            ; Left arrow
        je .turn_left

        ; Rotate right
        cmp al,'d'
        je .turn_right
        cmp al,'D'
        je .turn_right
        cmp ah,0x4D            ; Right arrow
        je .turn_right

        ; Move forward
        cmp al,'w'
        je .move_fwd
        cmp al,'W'
        je .move_fwd
        cmp ah,0x48            ; Up arrow
        je .move_fwd

        ; Move backward
        cmp al,'s'
        je .move_back
        cmp al,'S'
        je .move_back
        cmp ah,0x50            ; Down arrow
        je .move_back

        ; Shoot
        cmp al,' '
        je .do_shot

        jmp .key_loop

.turn_left:
        dec bx
        dec bx
        jmp .key_loop

.turn_right:
        inc bx
        inc bx
        jmp .key_loop

.move_fwd:
        push bx
        mov ax,bx
        call move_by_angle
        pop bx
        jmp .key_loop

.move_back:
        push bx
        mov ax,bx
        add al,128             ; opposite direction
        call move_by_angle
        pop bx
        jmp .key_loop

.do_shot:
        mov byte [bp+shot],7
        jmp .key_loop

.store_angle:
        mov [bp+pa],bx
        jmp game_loop

;
; Exit back to caller
;
exit_game:
        mov ax,0x0003   ; Restore text mode
        int 0x10
        ret

;
; Move player in direction AX (same scale as pa)
;
move_by_angle:
        call get_dir
.step:
        call read_maze
        jc .done
        cmp si,byte 4
        jne .step
        mov [bp+px],dx
        mov [bp+py],bx
.done:
        ret

;
; Get a direction vector
;
get_dir:
        xor si,si       ; Wall distance = 0
        mov dx,[bp+px]
        push ax
        call get_sin
        xchg ax,cx
        pop ax
        add al,32       ; +90 deg to get cosine

;
; Get sine
;
get_sin:
        test al,64      ; Angle >= 180?
        pushf
        test al,32      ; 90-179 or 270-359?
        je .2
        xor al,31
.2:
        and ax,31
        mov bx,sin_table
        cs xlat
        popf
        je .1
        neg ax
.1:
        mov bx,[bp+py]
        ret

;
; Read maze
;
read_maze:
        inc si
        add dx,cx
        add bx,ax
        push bx
        push cx
        call get_pos
        mov bl,[bx]
        shl bl,1        ; Carry=1 wall, Zero=wall 0/1
        pop cx
        pop bx
        ret

;
; Convert coordinates to position
;
get_pos:
        mov bl,dh
        mov cl,0x04
        shr bl,cl
        and bh,0xf0
        or bl,bh
        mov bh,maze>>8
        ret

;
; Fill a screen column
;
fill_column:
        mov ah,al
.1:
        stosw
        stosw
        stosw
        stosw
        add di,0x0138
        loop .1
        ret

;
; Generate a pseudo-random number
;
random:
        mov al,251
        mul byte [bp+rnd]
        add al,83
        mov [bp+rnd],al
        mov ah,0
        div dl
        mov bl,ah
        mov bh,0
        ret

;
; Wait a frame (18.2 Hz)
;
wait_frame:
.1:
        mov ah,0x00
        int 0x1a
        cmp dx,[bp+oldtim]
        je .1
        mov [bp+oldtim],dx
        ret

;
; Sine table (0.8 format), 32 bytes = 90 degrees
;
sin_table:
        db 0x00,0x09,0x16,0x24,0x31,0x3e,0x47,0x53
        db 0x60,0x6c,0x78,0x80,0x8b,0x96,0xa1,0xab
        db 0xb5,0xbb,0xc4,0xcc,0xd4,0xdb,0xe0,0xe6
        db 0xec,0xf1,0xf5,0xf7,0xfa,0xfd,0xff,0xff
