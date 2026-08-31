; ==============================================================================
; Bootloader UEFI - x86_64 (punto de entrada: efi_main)
; ==============================================================================

bits 64              ; Configurar el ensamblador para trabajar en modo de 64 bits (x86_64)
default rel          ; Habilitar el direccionamiento relativo a RIP por defecto para variables

extern limpiar_pantalla
extern imprimir_en
extern esperar_enter
extern leer_hora
extern formatear_hora

section .text
global efi_main

efi_main:
    ; --- Prólogo: shadow space + registros non-volatile ---
    ; Guardamos SystemTable/ConOut/ConIn en R12-R14 (non-volatile en la
    ; convención x64 de Windows/UEFI) porque necesitamos que sobrevivan a
    ; llamadas a protocolos EFI (ver SPEC_UEFI.md §4).
    push rbp
    mov rbp, rsp
    push r12
    push r13
    push r14
    sub rsp, 40      ; 32 bytes de shadow space (mínimo x64) + 8 de relleno
                      ; para mantener RSP alineado a 16 bytes antes de cada call
    cld              ; DF=0: la convención x64 ya lo exige al entrar a una
                      ; función, pero se deja explícito porque rtc_uefi.asm
                      ; usa "stosw" para formatear la hora.

    ; --- Guardar parámetros de UEFI ---
    ; RCX contiene el ImageHandle, y RDX contiene el puntero a la SystemTable.
    mov r12, rdx              ; SystemTable
    mov r13, [r12 + 64]        ; ConOut (SystemTable+64)
    mov r14, [r12 + 48]         ; ConIn (SystemTable+48)

    ; ==========================================================================
    ; 1. Pantalla de bienvenida (protocolo ConOut)
    ; ==========================================================================
    mov rcx, r13
    call limpiar_pantalla

    mov rcx, r13
    mov rdx, 21               ; columna
    mov r8, 8                  ; fila
    lea r9, [rel bienvenida_linea1]
    call imprimir_en

    mov rcx, r13
    mov rdx, 31
    mov r8, 9
    lea r9, [rel bienvenida_linea2]
    call imprimir_en

    mov rcx, r13
    mov rdx, 24
    mov r8, 11
    lea r9, [rel bienvenida_prompt]
    call imprimir_en

    ; ==========================================================================
    ; 2. Confirmación inicial (protocolo ConIn) — bloquea hasta Enter
    ; ==========================================================================
    mov rcx, r14
    call esperar_enter

    ; ==========================================================================
    ; 3. Confirmado: entra al modo Reloj. El cronómetro, cambio de modo y
    ; alarma llegan en las siguientes fases (ver docs/plan.md).
    ; ==========================================================================
    ; Se vuelve a leer ConOut de SystemTable (en vez de confiar en que R13
    ; sobrevivió intacto el loop de espera de esperar_enter, que puede
    ; iterar muchísimas veces) — defensivo, de bajo costo.
    mov r13, [r12 + 64]
    mov rcx, r13
    call limpiar_pantalla

    mov rcx, r13
    mov rdx, 31
    mov r8, 5
    lea r9, [rel reloj_titulo]
    call imprimir_en

    mov byte [rel ultimo_segundo], 0xFF   ; fuerza el primer dibujo

reloj_loop:
    mov rcx, r12
    lea rdx, [rel hora_efi_time]
    call leer_hora

    movzx eax, byte [rel hora_efi_time + 6]  ; Second recién leído
    cmp al, [rel ultimo_segundo]
    je reloj_loop                              ; mismo segundo, no redibujar (evita parpadeo)
    mov [rel ultimo_segundo], al

    lea rsi, [rel hora_efi_time]
    lea rdi, [rel hora_buffer]
    call formatear_hora

    mov rcx, r13
    mov rdx, 36
    mov r8, 7
    lea r9, [rel hora_buffer]
    call imprimir_en

    jmp reloj_loop

    ; ==========================================================================
    ; 4. Salida limpia y retorno al firmware UEFI (inalcanzable por ahora:
    ; reloj_loop es infinito hasta que la Fase UEFI-5 agregue la tecla Esc)
    ; ==========================================================================
    xor rax, rax     ; EFI_SUCCESS
    add rsp, 40
    pop r14
    pop r13
    pop r12
    pop rbp
    ret

; ==============================================================================
; Sección de Datos Estáticos
; ==============================================================================
section .data
bienvenida_linea1    dw __utf16__("=== Reloj / Cronometro con Alarma ==="), 0
bienvenida_linea2    dw __utf16__("Tarea 1 - CE 4303"), 0
bienvenida_prompt    dw __utf16__("Presione ENTER para continuar..."), 0
reloj_titulo         dw __utf16__("-- Modo Reloj --"), 0
ultimo_segundo       db 0xFF               ; Segundo ya dibujado; 0xFF fuerza el primer dibujo
hora_efi_time         times 16 db 0          ; EFI_TIME devuelto por GetTime (ver rtc_uefi.asm)
hora_buffer            times 18 db 0           ; "HH:MM:SS" + nulo, en UTF-16 (9 CHAR16 = 18 bytes)
