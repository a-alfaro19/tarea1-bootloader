; ==============================================================================
; Bootloader UEFI - x86_64 (punto de entrada: efi_main)
; ==============================================================================

bits 64              ; Configurar el ensamblador para trabajar en modo de 64 bits (x86_64)
default rel          ; Habilitar el direccionamiento relativo a RIP por defecto para variables

extern imprimir_string
extern leer_tecla_no_bloqueante

section .text
global efi_main

efi_main:
    ; --- Prólogo: shadow space + registros non-volatile ---
    ; Guardamos SystemTable/ConOut/ConIn en R12-R14 (non-volatile en la
    ; convención x64 de Windows/UEFI) porque necesitamos que sobrevivan a
    ; llamadas a protocolos EFI. Los preservamos explícitamente con
    ; push/pop porque efi_main es el punto de entrada que llama el firmware
    ; directamente — si no los restauramos antes de retornar, dejamos al
    ; firmware con esos registros alterados (ver SPEC_UEFI.md §4).
    push rbp
    mov rbp, rsp
    push r12
    push r13
    push r14
    sub rsp, 40      ; 32 bytes de shadow space (mínimo x64) + 8 de relleno
                      ; para mantener RSP alineado a 16 bytes antes de cada call

    ; --- Guardar parámetros de UEFI ---
    ; RCX contiene el ImageHandle, y RDX contiene el puntero a la SystemTable.
    mov r12, rdx     ; Guardar el puntero global 'SystemTable'

    ; ==========================================================================
    ; 1. Impresión del mensaje de bienvenida (Uso del protocolo ConOut)
    ; ==========================================================================
    mov r13, [r12 + 64]      ; SystemTable + 64 apunta a 'ConOut' (Consola de Salida de Texto)
    mov rcx, r13              ; Primer argumento: puntero al objeto ConOut (el 'this' de la interfaz)
    lea rdx, [rel hello_msg]  ; Segundo argumento: carga la dirección relativa de la cadena UTF-16
    call imprimir_string

    ; ==========================================================================
    ; 2. Espera de teclado (Uso del protocolo ConIn)
    ; ==========================================================================
    ; ReadKeyStroke ya es no bloqueante por naturaleza (devuelve
    ; EFI_NOT_READY de inmediato si no hay tecla), así que este loop hace
    ; polling hasta obtener EFI_SUCCESS (RAX=0) — no hace falta un evento
    ; de espera bloqueante.
    ;
    ; NOTA: el ConIn debe recargarse en RCX en cada vuelta desde un registro
    ; preservado (R14), no reutilizar RAX de la llamada anterior — RAX queda
    ; sobrescrito con el EFI_STATUS que devuelve la llamada (típicamente
    ; EFI_NOT_READY), y usarlo como puntero 'this' en la siguiente vuelta
    ; produciría una llamada a una dirección inválida.
    mov r14, [r12 + 48]      ; SystemTable + 48 apunta a 'ConIn' (Consola de Entrada de Texto)

espera_tecla:
    mov rcx, r14              ; Primer argumento: puntero al objeto ConIn ('this')
    lea rdx, [rel tecla_buffer] ; Segundo argumento: buffer para la tecla leída (EFI_INPUT_KEY)
    call leer_tecla_no_bloqueante

    cmp rax, 0                ; Comparar el resultado devuelto en RAX con 0 (EFI_SUCCESS)
    jne espera_tecla          ; Si no es cero (no hay tecla o falló), repite el bucle

    ; ==========================================================================
    ; 3. Salida limpia y retorno al firmware UEFI
    ; ==========================================================================
    xor rax, rax     ; Poner RAX en 0, lo que representa EFI_SUCCESS (éxito)
    add rsp, 40
    pop r14
    pop r13
    pop r12
    pop rbp          ; Recuperar el puntero base anterior
    ret              ; Retornar el control de ejecución al firmware UEFI

; ==============================================================================
; Sección de Datos Estáticos
; ==============================================================================
section .data
hello_msg:
    dw __utf16__("¡Hola Mundo desde UEFI con ensamblador!"), 13, 10
    dw __utf16__("Presiona cualquier tecla para salir..."), 13, 10, 0

section .bss
tecla_buffer: resb 4    ; EFI_INPUT_KEY: UINT16 ScanCode + CHAR16 UnicodeChar
