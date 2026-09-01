; ==============================================================================
; rtc_uefi.asm — Lectura de hora vía RuntimeServices->GetTime (SystemTable+88,
; GetTime en el offset +24 de RuntimeServices). Devuelve valores binarios
; (Hour/Minute/Second en EFI_TIME), a diferencia del BCD del RTC de BIOS.
; ==============================================================================

bits 64
default rel

section .text
global leer_hora
global formatear_hora
global bin_a_utf16

; leer_hora
; Entrada: RCX = puntero a SystemTable, RDX = puntero a buffer EFI_TIME
;          (16 bytes) donde escribir la hora leída
; Salida: RAX = EFI_STATUS
; GetTime no recibe un puntero "this" (no es un método de un protocolo con
; instancia, es una función suelta de la tabla de RuntimeServices) — sus
; argumentos son (Time, Capabilities), así que hay que reacomodar registros:
; nuestro RDX (destino) pasa a ser el RCX de la llamada.
leer_hora:
    sub rsp, 40
    mov rax, [rcx + 88]     ; SystemTable+88 = RuntimeServices
    mov rax, [rax + 24]      ; RuntimeServices+24 = GetTime
    mov rcx, rdx                ; 1er argumento de GetTime: Time (nuestro destino)
    xor rdx, rdx                  ; 2do argumento: Capabilities = NULL (opcional)
    call rax
    add rsp, 40
    ret

; bin_a_utf16
; Entrada: AL = valor binario (0-99, no BCD), RDI = destino
; Convierte un valor binario a dos dígitos, cada uno como CHAR16 (UTF-16),
; ya que ConOut->OutputString espera cadenas UTF-16, no ASCII de 1 byte
; como el teletipo de BIOS. Avanza RDI en 4 bytes (2 CHAR16).
bin_a_utf16:
    push bx
    push dx
    xor ah, ah
    mov bl, 10
    div bl              ; AL = decena, AH = unidad
    mov dl, ah           ; guardar la unidad aparte antes de pisar AH
    xor ah, ah
    add al, '0'
    stosw                 ; escribe la decena como CHAR16
    mov al, dl
    xor ah, ah
    add al, '0'
    stosw                   ; escribe la unidad como CHAR16
    pop dx
    pop bx
    ret

; formatear_hora
; Entrada: RSI = puntero a un EFI_TIME ya leído (Hour en +4, Minute en +5,
;          Second en +6, todos binarios), RDI = destino (buffer UTF-16,
;          mínimo 18 bytes: "HH:MM:SS" + terminador nulo CHAR16)
formatear_hora:
    push ax
    movzx eax, byte [rsi + 4]   ; Hour
    call bin_a_utf16
    mov ax, ':'
    stosw
    movzx eax, byte [rsi + 5]    ; Minute
    call bin_a_utf16
    mov ax, ':'
    stosw
    movzx eax, byte [rsi + 6]     ; Second
    call bin_a_utf16
    xor ax, ax
    stosw                          ; terminador nulo (CHAR16 = 0)
    pop ax
    ret
