; ==============================================================================
; Bootloader UEFI - x86_64 (punto de entrada: efi_main)
; ==============================================================================

bits 64              ; Configurar el ensamblador para trabajar en modo de 64 bits (x86_64)
default rel          ; Habilitar el direccionamiento relativo a RIP por defecto para variables

extern limpiar_pantalla
extern imprimir_en
extern esperar_enter

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
    ; 3. Confirmado: placeholder del modo interactivo. El modo Reloj llega en
    ; la Fase UEFI-2 y el resto en las siguientes (ver docs/plan.md).
    ; ==========================================================================
    ; Se vuelve a leer ConOut de SystemTable (en vez de confiar en que R13
    ; sobrevivió intacto el loop de espera de esperar_enter, que puede
    ; iterar muchísimas veces) — defensivo, de bajo costo.
    mov r13, [r12 + 64]
    mov rcx, r13
    call limpiar_pantalla

    mov rcx, r13
    mov rdx, 20
    mov r8, 10
    lea r9, [rel modo_interactivo_msg]
    call imprimir_en

    ; ==========================================================================
    ; 4. Salida limpia y retorno al firmware UEFI
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
modo_interactivo_msg dw __utf16__("Confirmado. (modo interactivo: pendiente)"), 0
