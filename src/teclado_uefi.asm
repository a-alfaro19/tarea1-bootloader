; ==============================================================================
; teclado_uefi.asm — Helpers de teclado sobre el protocolo ConIn
; (EFI_SIMPLE_TEXT_INPUT_PROTOCOL).
; ==============================================================================

bits 64
default rel

section .text
global leer_tecla_no_bloqueante
global esperar_enter

KEY_ENTER equ 0x0D          ; UnicodeChar de Enter en un EFI_INPUT_KEY

; leer_tecla_no_bloqueante
; Entrada: RCX = puntero a ConIn (this), RDX = puntero a un EFI_INPUT_KEY
;          (4 bytes: UINT16 ScanCode + CHAR16 UnicodeChar) donde se escribe
;          la tecla leída
; Salida: RAX = EFI_STATUS — 0 (EFI_SUCCESS) si había una tecla disponible
;         (ya queda en [RDX]); distinto de 0 (típicamente EFI_NOT_READY) si
;         no había ninguna. A diferencia del BIOS, ReadKeyStroke ya es no
;         bloqueante por naturaleza — no hace falta una llamada de "peek"
;         separada (ver SPEC_UEFI.md §2).
; Reserva su propio shadow space + alineación de 16 bytes (ver comentario de
; cabecera en video_uefi.asm) porque a esta rutina se entra justo después de
; un "call" (RSP % 16 == 8).
leer_tecla_no_bloqueante:
    sub rsp, 40
    call qword [rcx + 8]
    add rsp, 40
    ret

; esperar_enter
; Entrada: RCX = puntero a ConIn (this)
; Bloquea haciendo polling hasta que se presione Enter (UnicodeChar = 0x0D);
; cualquier otra tecla se ignora y se sigue esperando. Usa un buffer propio
; en .bss para no depender de un puntero que pase el llamador.
esperar_enter:
    push rbx
    mov rbx, rcx          ; conservar ConIn a través del loop

.loop:
    mov rcx, rbx
    lea rdx, [rel tecla_espera_buffer]
    call leer_tecla_no_bloqueante
    cmp rax, 0
    jne .loop                            ; no había tecla, seguir esperando

    movzx eax, word [rel tecla_espera_buffer + 2]  ; UnicodeChar (offset 2 del EFI_INPUT_KEY)
    cmp eax, KEY_ENTER
    jne .loop

    pop rbx
    ret

section .data
; En .data (no .bss) con ceros explícitos: este toolchain enlaza objetos ELF64
; como PE64 sin runtime de C que garantice el llenado a cero de .bss para una
; app EFI "cruda" — mejor no depender de eso para un buffer que si queda
; corrupto podría hacer parecer una tecla presionada cuando no la hubo.
tecla_espera_buffer: dw 0, 0
