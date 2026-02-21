; ==================================================================
; AurumDOS -- The AurumDOS Operating System kernel
; Copyright (C) 2025 PRoX2011
; ==================================================================

[BITS 16]
[ORG 0x0000]

disk_buffer equ 24576

section .text

start:
    cli
    mov ax, 0
    mov ss, ax
    mov sp, 0x0FFFF

    xor ax, ax
    mov es, ax
    mov word [es:0x80], int20_handler
    mov word [es:0x82], cs

    sti

    jmp kernel_init

int20_handler:
    iret

kernel_init:
    cld

    call set_video_mode
    call InitMouse

    mov ax, 2000h
    mov ds, ax
    mov es, ax

    call api_output_init
    call api_fs_init

    ; Строим промпт
    mov di, final_prompt
    mov al, '['
    stosb
    mov si, user
.user_copy:
    lodsb
    cmp al, 0
    je .user_done
    stosb
    jmp .user_copy
.user_done:
    mov si, .suffix
.suffix_copy:
    lodsb
    stosb
    cmp al, 0
    jne .suffix_copy

    call EnableMouse
    call string_clear_screen
    call print_interface
    call shell
    jmp $

.suffix db '@AurumDOS] > ', 0

; ===================== Видеорежим =====================

set_video_mode:
    mov ax, 0x0003
    int 0x10
    ret

; ===================== Вывод строк =====================

print_string:
    mov ah, 0x0E
    mov bl, 0x0F
.print_char:
    lodsb
    cmp al, 0
    je .done
    cmp al, 0x0A
    je .handle_newline
    int 0x10
    jmp .print_char
.handle_newline:
    mov al, 0x0D
    int 0x10
    mov al, 0x0A
    int 0x10
    jmp .print_char
.done:
    ret

print_newline:
    mov ah, 0x0E
    mov al, 0x0D
    int 0x10
    mov al, 0x0A
    int 0x10
    ret

print_string_green:
    mov ah, 0x0E
    mov bl, 0x0A
.print_char:
    lodsb
    cmp al, 0
    je .done
    int 0x10
    jmp .print_char
.done:
    ret

print_string_cyan:
    mov ah, 0x0E
    mov bl, 0x0B
.print_char:
    lodsb
    cmp al, 0
    je .done
    int 0x10
    jmp .print_char
.done:
    ret

print_string_red:
    mov ah, 0x0E
    mov bl, 0x0C
.print_char:
    lodsb
    cmp al, 0
    je .done
    int 0x10
    jmp .print_char
.done:
    ret

print_string_yellow:
    mov ah, 0x0E
    mov bl, 0x0E
.print_char:
    lodsb
    cmp al, 0
    je .done
    int 0x10
    jmp .print_char
.done:
    ret

print_decimal:
    mov cx, 0
    mov dx, 0
.setup:
    cmp ax, 0
    je .check_0
    mov bx, 10
    div bx
    push dx
    inc cx
    xor dx, dx
    jmp .setup
.check_0:
    cmp cx, 0
    jne .print_number
    push dx
    inc cx
.print_number:
    mov ah, 0x0E
.print_char:
    cmp cx, 0
    je .return
    pop dx
    add dx, 48
    mov al, dl
    int 0x10
    dec cx
    jmp .print_char
.return:
    ret

print_interface:
    mov si, header
    call print_string

    call print_newline
    call print_newline

    mov si, .aurumdos_logo
    call print_string

    call print_newline

    mov si, .copyright
    call print_string

    mov si, .shell
    call print_string

    mov si, version_msg
    call print_string

    call print_newline

    mov si, .tip
    call print_string_cyan

    call print_newline

    mov cx, 15
    mov bl, 0
.color_blocks:
    push cx
    mov ah, 0x0E
    mov al, 0xDB
    int 0x10
    inc bl
    cmp bl, 15
    jbe .next_block
    mov bl, 0
.next_block:
    pop cx
    loop .color_blocks

    call print_newline
    call print_newline
    ret

.aurumdos_logo  db '    _                         ____   ____  _____ ', 10, 13
                db '   / \  _   _ _ __ _   _ _ __ |  _ \ / __ \/ ____|', 10, 13
                db '  / _ \| | | |  __| | | | |  \| | | | |  | |___  ', 10, 13
                db ' / ___ \ |_| | |  | |_| | | | | |_| | |__| |____)', 10, 13
                db '/_/   \_\__,_|_|   \__,_|_| |_|____/ \____/|_____/', 10, 13, 0
.copyright      db '* Copyright (C) 2026', 10, 13, 0
.shell          db '* Shell: ', 0
.tip            db 'Type HELP to get list of the commands', 10, 13, 0

print_help:
    pusha
    call print_newline
    mov si, kshell_comands
    call print_string
    call print_newline
    popa
    jmp get_cmd

print_info:
    mov si, info
    call print_string_green
    call print_newline
    jmp get_cmd

; ===================== Командная строка =====================

shell:
get_cmd:
    mov si, final_prompt
    call print_string

    mov di, input
    mov al, 0
    mov cx, 256
    rep stosb

    mov di, command
    mov al, 0
    mov cx, 32
    rep stosb

    mov ax, input
    call string_input_string
    call print_newline

    mov ax, input
    call string_string_chomp

    mov si, input
    cmp byte [si], 0
    je get_cmd

    mov si, input
    mov al, ' '
    call string_string_tokenize
    mov word [param_list], di

    mov si, input
    mov di, command
    call string_string_copy

    mov ax, command
    call string_string_uppercase

    mov si, command

    mov di, exit_string
    call string_string_compare
    jc near exit

    mov di, help_string
    call string_string_compare
    jc near print_help

    mov di, info_string
    call string_string_compare
    jc near print_info

    mov di, cls_string
    call string_string_compare
    jc near clear_screen

    mov di, dir_string
    call string_string_compare
    jc near list_directory

    mov di, ver_string
    call string_string_compare
    jc near print_ver

    mov di, time_string
    call string_string_compare
    jc near print_time

    mov di, date_string
    call string_string_compare
    jc near print_date

    mov di, cat_string
    call string_string_compare
    jc near cat_file

    mov di, del_string
    call string_string_compare
    jc near del_file

    mov di, copy_string
    call string_string_compare
    jc near copy_file

    mov di, ren_string
    call string_string_compare
    jc near ren_file

    mov di, size_string
    call string_string_compare
    jc near size_file

    mov di, shut_string
    call string_string_compare
    jc near do_shutdown

    mov di, reboot_string
    call string_string_compare
    jc near do_reboot

    mov di, cpu_string
    call string_string_compare
    jc near do_CPUinfo

    mov di, touch_string
    call string_string_compare
    jc near touch_file

    mov di, write_string
    call string_string_compare
    jc near write_file

    mov di, view_string
    call string_string_compare
    jc near view_bmp

    mov di, head_string
    call string_string_compare
    jc near head_file

    mov di, tail_string
    call string_string_compare
    jc near tail_file

    mov di, mkdir_string
    call string_string_compare
    jc near mkdir_command

    mov di, deldir_string
    call string_string_compare
    jc near deldir_command

    mov di, cd_string
    call string_string_compare
    jc near cd_command

    mov si, command
    mov di, kernel_file
    call string_string_compare
    jc no_kernel_allowed

    mov ax, command
    call string_string_length
    cmp ax, 4
    jl .try_append_bin

    mov si, command
    add si, ax
    sub si, 4
    mov di, bin_extension
    call string_string_compare
    jc .load_bin_program

.try_append_bin:
    mov ax, command
    call string_string_length
    mov si, command
    add si, ax
    mov byte [si], '.'
    mov byte [si+1], 'B'
    mov byte [si+2], 'I'
    mov byte [si+3], 'N'
    mov byte [si+4], 0

.load_bin_program:
    mov si, command
    mov di, kernel_file
    call string_string_compare
    jc no_kernel_allowed

    mov ax, command
    mov bx, 0
    mov cx, 32768
    call fs_load_file
    jnc execute_bin
    jmp total_fail

execute_bin:
    mov ax, 0
    mov bx, 0
    mov cx, 0
    mov dx, 0
    mov word si, [param_list]
    mov di, 0

    call DisableMouse
    call 32768

    mov ax, 0x2000
    mov ds, ax
    mov es, ax

    call EnableMouse
    jmp get_cmd

total_fail:
    mov si, invalid_msg
    call print_string_red
    call print_newline
    jmp get_cmd

no_kernel_allowed:
    mov si, kern_warn_msg
    call print_string_red
    call print_newline
    jmp get_cmd

clear_screen:
    call string_clear_screen
    jmp get_cmd

print_ver:
    call print_newline
    mov si, version_msg
    call print_string
    call print_newline
    jmp get_cmd

exit:
    int 0x19
    ret

; ===================== CPU Info =====================

print_edx:
    mov ah, 0x0E
    mov bx, 4
.loop4r:
    mov al, dl
    int 0x10
    ror edx, 8
    dec bx
    jnz .loop4r
    ret

print_full_name_part:
    cpuid
    push edx
    push ecx
    push ebx
    push eax
    mov cx, 4
.loop4n:
    pop edx
    call print_edx
    loop .loop4n
    ret

print_cores:
    mov si, cores
    call print_string
    mov eax, 1
    cpuid
    ror ebx, 16
    mov al, bl
    call print_al
    ret

print_cache_line:
    mov si, cache_line
    call print_string
    mov eax, 1
    cpuid
    ror ebx, 8
    mov al, bl
    mov bl, 8
    mul bl
    call print_al
    ret

print_stepping:
    mov si, stepping
    call print_string
    mov eax, 1
    cpuid
    and al, 15
    call print_al
    ret

print_al:
    mov ah, 0
    mov dl, 10
    div dl
    add ax, '00'
    mov dx, ax
    mov ah, 0x0E
    mov al, dl
    cmp dl, '0'
    jz skip_fn
    mov bl, 0x0F
    int 0x10
skip_fn:
    mov al, dh
    mov bl, 0x0F
    int 0x10
    ret

do_CPUinfo:
    call print_newline
    pusha

    mov si, flags_str
    call print_string
    xor ax, ax
    lahf
    call print_decimal
    mov si, mt
    call print_string

    mov si, control_reg
    call print_string
    mov eax, cr0
    call print_decimal
    mov si, mt
    call print_string

    mov si, code_segment
    call print_string
    mov ax, cs
    call print_decimal
    mov si, mt
    call print_string

    mov si, data_segment
    call print_string
    mov ax, ds
    call print_decimal
    mov si, mt
    call print_string

    mov si, extra_segment
    call print_string
    mov ax, es
    call print_decimal
    mov si, mt
    call print_string

    mov si, stack_segment
    call print_string
    mov ax, ss
    call print_decimal
    mov si, mt
    call print_string

    mov si, base_pointer
    call print_string
    mov ax, bp
    call print_decimal
    mov si, mt
    call print_string

    mov si, stack_pointer
    call print_string
    mov ax, sp
    call print_decimal
    mov si, mt
    call print_string

    call print_newline
    popa

    pusha

    mov si, family_str
    call print_string
    mov eax, 1
    cpuid
    mov ebx, eax
    shr eax, 8
    and eax, 0x0F
    mov ecx, ebx
    shr ecx, 20
    and ecx, 0xFF
    add eax, ecx

    mov si, family_table
.lookup_loop:
    cmp word [si], 0
    je .unknown_family
    cmp ax, word [si]
    je .found_family
    add si, 4
    jmp .lookup_loop
.found_family:
    mov si, word [si + 2]
    call print_string_cyan
    jmp .family_done
.unknown_family:
    mov si, unknown_family_str
    call print_string_cyan
.family_done:
    mov si, mt
    call print_string

    mov si, cpu_name
    call print_string
    mov eax, 80000002h
    call print_full_name_part
    mov eax, 80000003h
    call print_full_name_part
    mov eax, 80000004h
    call print_full_name_part
    mov si, mt
    call print_string
    call print_cores
    mov si, mt
    call print_string
    call print_cache_line
    mov si, mt
    call print_string
    call print_stepping
    mov si, mt
    call print_string
    popa
    call print_newline
    jmp get_cmd

; ===================== Дата и время =====================

print_date:
    mov si, date_msg
    call print_string
    mov bx, tmp_string
    call string_get_date_string
    mov si, bx
    call print_string_cyan
    call print_newline
    jmp get_cmd

print_time:
    mov si, time_msg
    call print_string
    mov bx, tmp_string
    call string_get_time_string
    mov si, bx
    call print_string_cyan
    call print_newline
    jmp get_cmd

delay_ms:
    pusha
    mov ax, dx
    mov cx, 1000
    mul cx
    mov cx, dx
    mov dx, ax
    mov ah, 0x86
    int 0x15
    popa
    ret

do_shutdown:
    pusha
    mov ax, 5300h
    xor bx, bx
    int 15h
    jc APM_error
    mov ax, 5301h
    xor bx, bx
    int 15h
    mov ax, 530Eh
    mov cx, 0102h
    xor bx, bx
    int 15h
    mov ax, 5307h
    mov bx, 0001h
    mov cx, 0003h
    int 15h
    hlt

APM_error:
    mov si, APM_error_msg
    call print_string_red
    call print_newline
    popa
    jmp get_cmd

do_reboot:
    int 0x19
    ret

; ===================== Файловые операции =====================

list_directory:
    call print_newline
    cmp byte [current_directory], 0
    je .show_root
    mov si, .subdir_prefix
    call print_string
    mov si, current_directory
    call print_string
    jmp .show_path_done
.show_root:
    mov si, root
    call print_string
.show_path_done:
    call print_newline
    call print_newline
    mov cx, 0
    mov ax, dirlist
    call fs_get_file_list
    mov word [file_count], dx
    mov si, dirlist
    mov ah, 0x0E
.repeat:
    lodsb
    cmp al, 0
    je .done
    cmp al, ','
    jne .nonewline
    pusha
    call print_newline
    popa
    jmp .repeat
.nonewline:
    mov bl, 0x0F
    int 0x10
    jmp .repeat
.done:
    call print_newline
    mov ax, [file_count]
    call string_int_to_string
    mov si, ax
    call print_string_cyan
    mov si, files_msg
    call print_string
    mov si, .sep
    call print_string
    call fs_free_space
    shr ax, 1
    mov [.freespace], ax
    mov bx, 1440
    sub bx, ax
    mov ax, bx
    call string_int_to_string
    mov si, ax
    call print_string_green
    mov si, .kb_msg
    call print_string
    call print_newline
    call print_newline
    mov ax, [.freespace]
    call string_int_to_string
    mov si, ax
    call print_string_green
    mov si, .free_msg
    call print_string
    call print_newline
    call print_newline
    jmp get_cmd

.free_msg      db ' KB free', 0
.kb_msg        db ' KB', 0
.sep           db '   ', 0
.subdir_prefix db 'A:/', 0
.freespace     dw 0

cat_file:
    call print_newline
    pusha
    mov word si, [param_list]
    call string_string_parse
    cmp ax, 0
    jne .filename_provided
    mov si, nofilename_msg
    call print_string
    call print_newline
    jmp .exit_cat
.filename_provided:
    push ax
    call fs_file_exists
    pop ax
    jc .not_found
    mov cx, 32768
    mov dx, ds
    call fs_load_huge_file
    jc .load_fail
    mov word [.rem_size], ax
    mov word [.rem_size+2], dx
    mov cx, ax
    or cx, dx
    jz .empty_file
    mov word [.curr_seg], ds
    mov word [.curr_off], 32768
    mov word [.line_count], 0
.print_loop:
    cmp dword [.rem_size], 0
    je .end_cat
    mov es, [.curr_seg]
    mov si, [.curr_off]
    mov al, [es:si]
    inc word [.curr_off]
    jnz .no_wrap
    add word [.curr_seg], 0x1000
.no_wrap:
    sub dword [.rem_size], 1
    cmp al, 0
    je .end_cat
    cmp al, 0x0A
    je .handle_newline
    mov ah, 0x0E
    mov bl, 0x0F
    int 0x10
    jmp .print_loop
.handle_newline:
    mov al, 0x0D
    int 0x10
    mov al, 0x0A
    int 0x10
    inc word [.line_count]
    cmp word [.line_count], 23
    jne .print_loop
    push si
    push es
    mov si, .continue_msg
    call print_string_cyan
    mov ah, 0
    int 16h
    mov si, .clear_msg
    call print_string
    mov word [.line_count], 0
    pop es
    pop si
    jmp .print_loop
.end_cat:
    call print_newline
    call print_newline
    jmp .exit_cat
.empty_file:
    mov si, .empty_msg
    call print_string_red
    call print_newline
    jmp .exit_cat
.not_found:
    mov si, notfound_msg
    call print_string_red
    call print_newline
    jmp .exit_cat
.load_fail:
    mov si, .load_err_msg
    call print_string_red
    call print_newline
.exit_cat:
    popa
    call print_newline
    jmp get_cmd

.line_count   dw 0
.curr_seg     dw 0
.curr_off     dw 0
.rem_size     dd 0
.continue_msg db 13, ' -- Press key -- ', 0
.clear_msg    db 13, '                 ', 13, 0
.empty_msg    db 'File is empty', 0
.load_err_msg db 'Error loading file', 0

del_file:
    mov word si, [param_list]
    call string_string_parse
    cmp ax, 0
    jne .filename_provided
    mov si, nofilename_msg
    call print_string_red
    call print_newline
    jmp get_cmd
.filename_provided:
    mov si, ax
    mov di, kernel_file
    call string_string_compare
    jc .kernel_protected
    mov si, ax
    mov di, .kernel_file_lowc
    call string_string_compare
    jc .kernel_protected
    call fs_remove_file
    jc .failure
    mov si, .success_msg
    call print_string_green
    call print_newline
    jmp get_cmd
.kernel_protected:
    mov si, kern_warn2_msg
    call print_string_red
    call print_newline
    jmp get_cmd
.failure:
    mov si, .failure_msg
    call print_string_red
    call print_newline
    jmp get_cmd
.success_msg      db 'Deleted file.', 0
.kernel_file_lowc db 'kernel.bin', 0
.failure_msg      db 'Could not delete file - does not exist or write protected', 0

size_file:
    mov word si, [param_list]
    call string_string_parse
    cmp ax, 0
    jne .filename_provided
    mov si, nofilename_msg
    call print_string_red
    call print_newline
    jmp get_cmd
.filename_provided:
    call fs_get_file_size
    jc .failure
    mov si, .size_msg
    call print_string
    mov ax, bx
    call string_int_to_string
    mov si, ax
    call print_string_cyan
    mov si, .bytes_msg
    call print_string
    call print_newline
    jmp get_cmd
.failure:
    mov si, notfound_msg
    call print_string_red
    call print_newline
    jmp get_cmd
.size_msg  db 'Size: ', 0
.bytes_msg db ' bytes', 0

copy_file:
    mov word si, [param_list]
    call string_string_parse
    mov word [.tmp], bx
    cmp bx, 0
    jne .filename_provided
    mov si, nofilename_msg
    call print_string_red
    call print_newline
    jmp get_cmd
.filename_provided:
    mov dx, ax
    mov ax, bx
    call fs_file_exists
    jnc .already_exists
    mov ax, dx
    mov cx, 32768
    mov dx, 0x2000
    call fs_load_huge_file
    jc .load_fail
    mov cx, bx
    mov bx, 32768
    mov word ax, [.tmp]
    call fs_write_file
    jc .write_fail
    mov si, .success_msg
    call print_string_green
    call print_newline
    jmp get_cmd
.load_fail:
    mov si, notfound_msg
    call print_string_red
    call print_newline
    jmp get_cmd
.write_fail:
    mov si, writefail_msg
    call print_string_red
    call print_newline
    jmp get_cmd
.already_exists:
    mov si, exists_msg
    call print_string_red
    call print_newline
    jmp get_cmd
.tmp dw 0
.success_msg db 'File copied successfully', 0

ren_file:
    mov word si, [param_list]
    call string_string_parse
    cmp bx, 0
    jne .filename_provided
    mov si, nofilename_msg
    call print_string_red
    call print_newline
    jmp get_cmd
.filename_provided:
    mov cx, ax
    mov ax, bx
    call fs_file_exists
    jnc .already_exists
    mov ax, cx
    call fs_rename_file
    jc .failure
    mov si, .success_msg
    call print_string_green
    call print_newline
    jmp get_cmd
.already_exists:
    mov si, exists_msg
    call print_string_red
    call print_newline
    jmp get_cmd
.failure:
    mov si, .failure_msg
    call print_string_red
    call print_newline
    jmp get_cmd
.success_msg db 'File renamed successfully', 0
.failure_msg db 'Operation failed - file not found or invalid filename', 0

touch_file:
    mov word si, [param_list]
    call string_string_parse
    cmp ax, 0
    jne .filename_provided
    mov si, nofilename_msg
    call print_string_red
    call print_newline
    jmp get_cmd
.filename_provided:
    call fs_file_exists
    jnc .already_exists
    call fs_create_file
    jc .failure
    mov si, .success_msg
    call print_string_green
    call print_newline
    jmp get_cmd
.already_exists:
    mov si, exists_msg
    call print_string_red
    call print_newline
    jmp get_cmd
.failure:
    mov si, .failure_msg
    call print_string_red
    call print_newline
    jmp get_cmd
.success_msg db 'File created successfully', 0
.failure_msg db 'Could not create file - invalid filename or disk error', 0

write_file:
    mov word si, [param_list]
    call string_string_parse
    cmp ax, 0
    jne .filename_provided
    mov si, nofilename_msg
    call print_string_red
    call print_newline
    jmp get_cmd
.filename_provided:
    cmp bx, 0
    jne .text_provided
    mov si, notext_msg
    call print_string_red
    call print_newline
    jmp get_cmd
.text_provided:
    mov word [.filename], ax
    mov si, bx
    mov di, file_buffer
    call string_string_copy
    mov ax, file_buffer
    call string_string_length
    mov cx, ax
    mov word ax, [.filename]
    mov bx, file_buffer
    call fs_write_file
    jc .failure
    mov si, .success_msg
    call print_string_green
    call print_newline
    jmp get_cmd
.failure:
    mov si, writefail_msg
    call print_string_red
    call print_newline
    jmp get_cmd
.filename    dw 0
.success_msg db 'File written successfully', 0

string_get_cursor_pos:
    pusha
    mov ah, 0x03
    mov bh, 0
    int 0x10
    mov [.tmp_dl], dl
    mov [.tmp_dh], dh
    popa
    mov dl, [.tmp_dl]
    mov dh, [.tmp_dh]
    ret
.tmp_dl db 0
.tmp_dh db 0

string_move_cursor:
    pusha
    mov ah, 0x02
    mov bh, 0
    int 0x10
    popa
    ret

string_string_parse:
    push si
    mov ax, si
    mov bx, 0
    mov cx, 0
    mov dx, 0
    push ax
.loop1:
    lodsb
    cmp al, 0
    je .finish
    cmp al, ' '
    jne .loop1
    dec si
    mov byte [si], 0
    inc si
    mov bx, si
.loop2:
    lodsb
    cmp al, 0
    je .finish
    cmp al, ' '
    jne .loop2
    dec si
    mov byte [si], 0
    inc si
    mov cx, si
.loop3:
    lodsb
    cmp al, 0
    je .finish
    cmp al, ' '
    jne .loop3
    dec si
    mov byte [si], 0
    inc si
    mov dx, si
.finish:
    pop ax
    pop si
    ret

set_background_color:
    pusha
    mov ah, 0x0B
    mov bh, 0
    mov bl, al
    int 0x10
    popa
    ret

wait_for_key:
    pusha
    mov ax, 0
    mov ah, 0x10
    int 16h
    mov [.tmp_buf], ax
    popa
    mov ax, [.tmp_buf]
    ret
.tmp_buf dw 0

head_file:
    call print_newline
    pusha
    mov word si, [param_list]
    call string_string_parse
    cmp ax, 0
    je .show_help
    mov [.filename], ax
    mov ax, [.filename]
    call fs_file_exists
    jc .file_not_found
    mov ax, [.filename]
    mov cx, 32768
    call fs_load_file
    jc .load_error
    cmp bx, 0
    je .empty_file
    mov word [.file_ptr], 32768
    mov word [.file_size], bx
    mov word [.lines_printed], 0
.print_loop:
    cmp word [.lines_printed], 10
    jge .done
    cmp word [.file_size], 0
    je .done
    mov si, [.file_ptr]
    mov al, [si]
    cmp al, 10
    je .print_newline
    cmp al, 13
    je .skip_char
    cmp al, 32
    jb .skip_char
    cmp al, 126
    ja .skip_char
    mov ah, 0x0E
    mov bl, 0x07
    int 0x10
    jmp .next_char
.print_newline:
    inc word [.lines_printed]
    call print_newline
    jmp .next_char
.skip_char:
.next_char:
    inc word [.file_ptr]
    dec word [.file_size]
    jmp .print_loop
.done:
    call print_newline
    popa
    jmp get_cmd
.show_help:
    mov si, .help_msg
    call print_string
    call print_newline
    popa
    jmp get_cmd
.file_not_found:
    mov si, notfound_msg
    call print_string_red
    call print_newline
    popa
    jmp get_cmd
.load_error:
    mov si, .load_error_msg
    call print_string_red
    call print_newline
    popa
    jmp get_cmd
.empty_file:
    mov si, .empty_file_msg
    call print_string_red
    call print_newline
    popa
    jmp get_cmd
.filename      dw 0
.file_ptr      dw 0
.file_size     dw 0
.lines_printed dw 0
.help_msg          db 'Usage: head <filename>', 10, 13, 0
.load_error_msg    db 'Error loading file', 0
.empty_file_msg    db 'File is empty', 0

tail_file:
    call print_newline
    pusha
    mov word si, [param_list]
    call string_string_parse
    cmp ax, 0
    je .show_help
    mov [.filename], ax
    mov ax, [.filename]
    call fs_file_exists
    jc .file_not_found
    mov ax, [.filename]
    mov cx, 32768
    call fs_load_file
    jc .load_error
    cmp bx, 0
    je .empty_file
    mov word [.file_start], 32768
    mov word [.file_size], bx
    mov word [.file_end], 32768
    add [.file_end], bx
    mov word [.lines_to_show], 10
    mov word [.lines_found], 0
    mov si, [.file_end]
    dec si
.find_lines:
    mov ax, [.lines_found]
    cmp ax, [.lines_to_show]
    jge .found_all_lines
    cmp si, [.file_start]
    jb .found_all_lines
    mov al, [si]
    cmp al, 10
    jne .continue_search
    inc word [.lines_found]
.continue_search:
    dec si
    jmp .find_lines
.found_all_lines:
    inc si
    mov [.print_start], si
    mov si, [.print_start]
.print_loop:
    cmp si, [.file_end]
    jge .done
    mov al, [si]
    cmp al, 10
    je .print_newline
    cmp al, 13
    je .skip_char
    cmp al, 32
    jb .skip_char
    cmp al, 126
    ja .skip_char
    mov ah, 0x0E
    mov bl, 0x07
    int 0x10
    jmp .next_char
.print_newline:
    call print_newline
    jmp .next_char
.skip_char:
.next_char:
    inc si
    jmp .print_loop
.done:
    call print_newline
    popa
    jmp get_cmd
.show_help:
    mov si, .help_msg
    call print_string
    call print_newline
    popa
    jmp get_cmd
.file_not_found:
    mov si, notfound_msg
    call print_string_red
    call print_newline
    popa
    jmp get_cmd
.load_error:
    mov si, .load_error_msg
    call print_string_red
    call print_newline
    popa
    jmp get_cmd
.empty_file:
    mov si, .empty_file_msg
    call print_string_red
    call print_newline
    popa
    jmp get_cmd
.filename      dw 0
.file_start    dw 0
.file_end      dw 0
.file_size     dw 0
.print_start   dw 0
.lines_to_show dw 10
.lines_found   dw 0
.help_msg          db 'Usage: tail <filename>', 10, 13, 0
.load_error_msg    db 'Error loading file', 0
.empty_file_msg    db 'File is empty', 0

mkdir_command:
    call print_newline
    pusha
    mov word si, [param_list]
    call string_string_parse
    cmp ax, 0
    je .no_dirname
    mov si, ax
    push ax
    call string_string_length
    cmp ax, 8
    jg .name_too_long
    pop ax
    mov [.dirname], ax
    mov ax, [.dirname]
    call fs_file_exists
    jnc .already_exists
    mov ax, [.dirname]
    call fs_create_directory
    jc .failure
    mov si, .success_msg
    call print_string_green
    call print_newline
    popa
    call print_newline
    jmp get_cmd
.no_dirname:
    mov si, .no_dirname_msg
    call print_string_red
    call print_newline
    popa
    call print_newline
    jmp get_cmd
.name_too_long:
    pop ax
    mov si, .name_too_long_msg
    call print_string_red
    call print_newline
    popa
    call print_newline
    jmp get_cmd
.already_exists:
    mov si, .already_exists_msg
    call print_string_red
    call print_newline
    popa
    call print_newline
    jmp get_cmd
.failure:
    mov si, .failure_msg
    call print_string_red
    call print_newline
    popa
    call print_newline
    jmp get_cmd
.dirname            dw 0
.success_msg        db 'Directory created successfully', 0
.no_dirname_msg     db 'No directory name provided', 0
.name_too_long_msg  db 'Directory name too long (max 8 characters)', 0
.already_exists_msg db 'File or directory already exists', 0
.failure_msg        db 'Could not create directory - disk error', 0

deldir_command:
    call print_newline
    pusha
    mov word si, [param_list]
    call string_string_parse
    cmp ax, 0
    je .no_dirname
    mov si, ax
    mov di, .dirname_buffer
    call string_string_copy
    mov ax, .dirname_buffer
    call string_string_length
    cmp ax, 8
    jg .name_too_long
    mov si, .dirname_buffer
    mov cx, 0
.check_dot:
    lodsb
    cmp al, 0
    je .no_extension
    cmp al, '.'
    je .has_extension
    inc cx
    jmp .check_dot
.no_extension:
    mov si, .dirname_buffer
    add si, cx
    mov byte [si], '.'
    inc si
    mov byte [si], 'D'
    inc si
    mov byte [si], 'I'
    inc si
    mov byte [si], 'R'
    inc si
    mov byte [si], 0
.has_extension:
    mov ax, .dirname_buffer
    mov [.dirname], ax
    mov ax, [.dirname]
    call fs_file_exists
    jc .not_found
    mov ax, [.dirname]
    call fs_is_directory
    jc .not_directory
    mov ax, [.dirname]
    call fs_remove_directory
    jc .failure
    mov si, .success_msg
    call print_string_green
    call print_newline
    popa
    call print_newline
    jmp get_cmd
.no_dirname:
    mov si, .no_dirname_msg
    call print_string_red
    call print_newline
    popa
    call print_newline
    jmp get_cmd
.name_too_long:
    mov si, .name_too_long_msg
    call print_string_red
    call print_newline
    popa
    call print_newline
    jmp get_cmd
.not_found:
    mov si, notfound_msg
    call print_string_red
    call print_newline
    popa
    call print_newline
    jmp get_cmd
.not_directory:
    mov si, .not_directory_msg
    call print_string_red
    call print_newline
    popa
    call print_newline
    jmp get_cmd
.failure:
    mov si, .failure_msg
    call print_string_red
    call print_newline
    popa
    call print_newline
    jmp get_cmd
.dirname            dw 0
.dirname_buffer     times 16 db 0
.success_msg        db 'Directory deleted successfully', 0
.no_dirname_msg     db 'No directory name provided', 0
.name_too_long_msg  db 'Directory name too long (max 8 characters)', 0
.not_directory_msg  db 'Not a directory', 0
.failure_msg        db 'Could not delete directory - not empty or disk error', 0

cd_command:
    call print_newline
    pusha
    mov word si, [param_list]
    call string_string_parse
    cmp ax, 0
    je .show_current
    mov si, ax
    mov di, .dotdot_str
    call string_string_compare
    jc .go_parent
    mov si, ax
    cmp byte [si], '/'
    je .go_root
    cmp byte [si], '\'
    je .go_root
    mov si, ax
    mov di, .dirname_buffer
    call string_string_copy
    mov si, .dirname_buffer
    mov cx, 0
.check_dot:
    lodsb
    cmp al, 0
    je .no_extension
    cmp al, '.'
    je .has_extension
    inc cx
    jmp .check_dot
.no_extension:
    mov si, .dirname_buffer
    add si, cx
    mov byte [si], '.'
    inc si
    mov byte [si], 'D'
    inc si
    mov byte [si], 'I'
    inc si
    mov byte [si], 'R'
    inc si
    mov byte [si], 0
.has_extension:
    mov ax, .dirname_buffer
    call fs_change_directory
    jc .failure
    mov si, .success_msg
    call print_string_green
    call print_newline
    popa
    call print_newline
    jmp get_cmd
.show_current:
    mov si, .current_msg
    call print_string
    cmp byte [current_directory], 0
    jne .show_path
    mov si, root
    call print_string_cyan
    jmp .show_done
.show_path:
    mov si, current_directory
    call print_string_cyan
.show_done:
    call print_newline
    popa
    call print_newline
    jmp get_cmd
.go_parent:
    call fs_parent_directory
    jc .already_root
    mov si, .success_msg
    call print_string_green
    call print_newline
    popa
    call print_newline
    jmp get_cmd
.already_root:
    mov si, .already_root_msg
    call print_string_yellow
    call print_newline
    popa
    call print_newline
    jmp get_cmd
.go_root:
    mov di, current_directory
    mov byte [di], 0
    mov si, .success_msg
    call print_string_green
    call print_newline
    popa
    call print_newline
    jmp get_cmd
.failure:
    mov si, .failure_msg
    call print_string_red
    call print_newline
    popa
    call print_newline
    jmp get_cmd
.dotdot_str       db '..', 0
.dirname_buffer   times 16 db 0
.current_msg      db 'Current directory: ', 0
.success_msg      db 'Directory changed', 0
.already_root_msg db 'Already in root directory', 0
.failure_msg      db 'Directory not found or invalid', 0

; ===================== Подключаем файлы =====================

%INCLUDE "fs.asm"
%INCLUDE "string.asm"
%INCLUDE "bmp_rendering.asm"
%INCLUDE "themes.asm"
%INCLUDE "ps2_mouse.asm"
%INCLUDE "api_output.asm"
%INCLUDE "api_fs.asm"

; ===================== Данные =====================

header db 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB1, 0xB1, 0xB1, 0xB1, 0xB1, 0xB1, 0xB1, 0xB1, 0xB2, 0xB2, 0xB2, 0xB2, 0xB2, 0xB2, 0xDB, 0xDB, ' ', 'AurumDOS v0.6', ' ', 0xDB, 0xDB, 0xB2, 0xB2, 0xB2, 0xB2, 0xB2, 0xB2, 0xB1, 0xB1, 0xB1, 0xB1, 0xB1, 0xB1, 0xB1, 0xB1, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0

kshell_comands db 'HELP               - get list of commands', 10, 13
               db 'INFO               - system information', 10, 13
               db 'VER                - terminal version', 10, 13
               db 'CLS                - clear screen', 10, 13
               db 'SHUT               - shutdown', 10, 13
               db 'REBOOT             - restart', 10, 13
               db 'DATE               - current date (DD/MM/YY)', 10, 13
               db 'TIME               - current time (HH:MM:SS)', 10, 13
               db 'CPU                - CPU info', 10, 13
               db 'DIR                - list files', 10, 13
               db 'SIZE   <f>         - file size', 10, 13
               db 'CAT    <f>         - show file', 10, 13
               db 'DEL    <f>         - delete file', 10, 13
               db 'COPY   <f1> <f2>   - copy file', 10, 13
               db 'REN    <f1> <f2>   - rename file', 10, 13
               db 'TOUCH  <f>         - create empty file', 10, 13
               db 'WRITE  <f> <text>  - write to file', 10, 13
               db 'VIEW   <f> <flags> - view BMP image', 10, 13
               db 'HEAD   <f>         - first 10 lines of TXT', 10, 13
               db 'TAIL   <f>         - last 10 lines of TXT', 10, 13
               db 'CD     <dir>       - change directory', 10, 13
               db 'MKDIR  <dir>       - create directory', 10, 13
               db 'DELDIR <dir>       - delete directory', 10, 13, 0

info db 10, 13
     db 20 dup(0xC4), ' INFO ', 21 dup(0xC4), 10, 13
     db '  AurumDOS is a lightweight 16-bit operating', 10, 13
     db '  system written in NASM for x86 PCs.', 10, 13
     db '  Built for simplicity, speed and control.', 10, 13
     db 47 dup(0xC4), 10, 13
     db '  Disk size: 1.44 MB', 10, 13
     db '  Video mode: text 80x25', 10, 13
     db '  File system: FAT12', 10, 13
     db '  License: MIT', 10, 13
     db '  OS version: 0.6.5', 10, 13
     db 0

version_msg db 'AurumDOS Terminal v0.2', 10, 13, 0

exit_string       db 'EXIT', 0
help_string       db 'HELP', 0
info_string       db 'INFO', 0
cls_string        db 'CLS', 0
dir_string        db 'DIR', 0
ver_string        db 'VER', 0
time_string       db 'TIME', 0
date_string       db 'DATE', 0
cat_string        db 'CAT', 0
del_string        db 'DEL', 0
copy_string       db 'COPY', 0
ren_string        db 'REN', 0
size_string       db 'SIZE', 0
shut_string       db 'SHUT', 0
reboot_string     db 'REBOOT', 0
cpu_string        db 'CPU', 0
touch_string      db 'TOUCH', 0
write_string      db 'WRITE', 0
view_string       db 'VIEW', 0
head_string       db 'HEAD', 0
tail_string       db 'TAIL', 0
mkdir_string      db 'MKDIR', 0
deldir_string     db 'DELDIR', 0
cd_string         db 'CD', 0

invalid_msg    db 'No such command or program', 0
nofilename_msg db 'No filename or not enough filenames', 0
notfound_msg   db 'File not found', 0
writefail_msg  db 'Could not write file. Write protected or invalid filename?', 0
exists_msg     db 'Target file already exists!', 0
kern_warn_msg  db 'Cannot execute kernel file!', 0
kern_warn2_msg db 'Cannot delete kernel file!', 0
notext_msg     db 'No text provided for writing', 0
APM_error_msg  db 'APM error or APM not available', 0

error_message  db '[ ERROR ] ', 0
okay_message   db '[ OKAY ]  ', 0
warn_message   db '[ WARN ]  ', 0

flags_str          db '  FLAGS: ', 0
control_reg        db '  Control Reg   (CR) : ', 0
stack_segment      db '  Stack Seg     (SS) : ', 0
code_segment       db '  Code Seg      (CS) : ', 0
data_segment       db '  Data Seg      (DS) : ', 0
extra_segment      db '  Extra Seg     (ES) : ', 0
base_pointer       db '  Base Pointer  (BP) : ', 0
stack_pointer      db '  Stack Pointer (SP) : ', 0
family_str         db '  CPU Family         : ', 0
unknown_family_str db 'Unknown', 0
intel_core_str     db 'Intel', 0
intel_pentium_str  db 'Intel Pentium', 0
amd_ryzen_str      db 'AMD Ryzen', 0
amd_athlon_str     db 'AMD Athlon', 0

family_table:
    dw 6,  intel_core_str
    dw 5,  intel_pentium_str
    dw 15, amd_athlon_str
    dw 21, amd_ryzen_str
    dw 0,  0

cpu_name   db '  CPU name           : ', 0
cores      db '  CPU cores          : ', 0
stepping   db '  Stepping ID        : ', 0
cache_line db '  Cache line         : ', 0

time_msg  db 'Current time: ', 0
date_msg  db 'Current date: ', 0
files_msg db ' files', 0
root      db 'A:/', 0

file_size       dw 0
param_list      dw 0
x_offset        dw 0
y_offset        dw 0
bin_extension   db '.BIN', 0
total_file_size dd 0
file_count      dw 0
timezone_offset dw 0
program_seg     equ 0x3000
kernel_file     db 'KERNEL.BIN', 0
cfg_logo_stretch db 0
mt              db '', 10, 13, 0
Sides           dw 2
SecsPerTrack    dw 18
bootdev         db 0
fmt_date        dw 1


current_logo_file times 13    db 0
tmp_string        times 15    db 0
command           times 32    db 0

user db 'user', 0
     times 27 db 0

saved_directory   times 32    db 0
final_prompt      times 64    db 0
temp_prompt       times 64    db 0
input             times 256   db 0
current_directory times 256   db 0
dirlist           times 1024  db 0
file_buffer       times 32768 db 0