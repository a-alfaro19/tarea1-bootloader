; ==============================================================================
; Bootloader UEFI - x86_64 (punto de entrada: efi_main)
; ==============================================================================

bits 64              ; Configurar el ensamblador para trabajar en modo de 64 bits (x86_64)
default rel          ; Habilitar el direccionamiento relativo a RIP por defecto para variables

extern limpiar_pantalla
extern imprimir_en
extern esperar_enter
extern leer_tecla_no_bloqueante
extern leer_hora
extern formatear_hora
extern crono_iniciar_pausar_reanudar
extern crono_reiniciar
extern crono_segundos_transcurridos
extern formatear_cronometro
extern alarma_configurar
extern alarma_actualizar
extern alarma_cancelar

KEY_ESC         equ 0x1B      ; UnicodeChar de Escape (si viene como texto)
SCAN_ESC        equ 0x17      ; EFI_SCAN_CODE_ESC: el teclado UEFI puede reportarlo
MODO_RELOJ      equ 0
MODO_CRONOMETRO equ 1

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

    ; --- Forzar Modo de Texto Estándar (80x25 / Modo 0) ---
    ; Evita que las laptops con UEFI en alta resolución compriman el texto en una esquina.
    sub rsp, 32
    mov rcx, r13              ; this (ConOut)
    xor rdx, rdx              ; Modo 0 (el estándar universal 80x25)
    call qword [r13 + 32]     ; SetMode está en el offset +32 de ConOut
    add rsp, 32

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
    ; 3. Confirmado: entra al modo interactivo (Reloj por defecto). La
    ; alarma llega en la siguiente fase (ver docs/plan.md).
    ; ==========================================================================
    ; Se vuelve a leer ConOut de SystemTable (en vez de confiar en que R13
    ; sobrevivió intacto el loop de espera de esperar_enter, que puede
    ; iterar muchísimas veces) — defensivo, de bajo costo.
    mov r13, [r12 + 64]
    mov rcx, r13
    call limpiar_pantalla

    mov byte [rel modo_actual], MODO_RELOJ
    mov byte [rel ultimo_segundo], 0xFF
    mov dword [rel crono_ultimo_segundos], 0xFFFFFFFF
    call dibujar_titulo_modo

    mov rcx, r13
    mov rdx, 10
    mov r8, 20
    lea r9, [rel controles_msg]
    call imprimir_en

    mov rcx, r13
    mov rdx, 10
    mov r8, 21
    lea r9, [rel controles_msg2]
    call imprimir_en

loop_principal:
    mov rcx, r14
    lea rdx, [rel tecla_loop_buffer]
    call leer_tecla_no_bloqueante
    cmp rax, 0
    jne .revisar_modo                ; no había tecla

    ; EFI_INPUT_KEY usa dos campos: ScanCode + UnicodeChar. Escape suele venir
    ; como scan code (0x17) y no siempre como UnicodeChar (0x1B), por eso se
    ; comprobam ambos para que el atajo funcione en firmware UEFI real.
    movzx eax, word [rel tecla_loop_buffer]       ; ScanCode
    cmp eax, SCAN_ESC
    je .tecla_salir

    movzx eax, word [rel tecla_loop_buffer + 2]  ; UnicodeChar
    cmp eax, 'M'
    je .tecla_modo
    cmp eax, 'm'
    je .tecla_modo
    cmp eax, 'S'
    je .tecla_start
    cmp eax, 's'
    je .tecla_start
    cmp eax, 'R'
    je .tecla_reset
    cmp eax, 'r'
    je .tecla_reset
    cmp eax, 'A'
    je .tecla_alarma
    cmp eax, 'a'
    je .tecla_alarma
    cmp eax, 'C'
    je .tecla_cancelar_alarma
    cmp eax, 'c'
    je .tecla_cancelar_alarma
    cmp eax, KEY_ESC
    je .tecla_salir
    jmp .revisar_modo

.tecla_modo:
    xor byte [rel modo_actual], 1     ; alterna 0 <-> 1 (MODO_RELOJ/MODO_CRONOMETRO)
    mov rcx, r13
    call limpiar_pantalla
    mov byte [rel ultimo_segundo], 0xFF
    mov dword [rel crono_ultimo_segundos], 0xFFFFFFFF
    call dibujar_titulo_modo
    mov rcx, r13
    mov rdx, 10
    mov r8, 20
    lea r9, [rel controles_msg]
    call imprimir_en
    mov rcx, r13
    mov rdx, 10
    mov r8, 21
    lea r9, [rel controles_msg2]
    call imprimir_en
    jmp loop_principal

.tecla_start:
    mov rcx, r12
    call crono_iniciar_pausar_reanudar
    jmp loop_principal

.tecla_reset:
    call crono_reiniciar
    mov dword [rel crono_ultimo_segundos], 0xFFFFFFFF  ; fuerza redibujar a 00:00
    jmp loop_principal

.tecla_alarma:
    mov rcx, r12
    call alarma_configurar

    ; alarma_configurar dibuja su propia pantalla de captura; redibujar la
    ; pantalla principal (título + controles) al volver, mismo patrón que
    ; .tecla_modo. Se vuelve a leer ConOut de SystemTable por si acaso, igual
    ; que tras esperar_enter en la confirmación inicial.
    mov r13, [r12 + 64]
    mov rcx, r13
    call limpiar_pantalla
    mov byte [rel ultimo_segundo], 0xFF
    mov dword [rel crono_ultimo_segundos], 0xFFFFFFFF
    call dibujar_titulo_modo
    mov rcx, r13
    mov rdx, 10
    mov r8, 20
    lea r9, [rel controles_msg]
    call imprimir_en
    mov rcx, r13
    mov rdx, 10
    mov r8, 21
    lea r9, [rel controles_msg2]
    call imprimir_en
    jmp loop_principal

.tecla_cancelar_alarma:
    mov rcx, r13
    call alarma_cancelar
    jmp loop_principal

.tecla_salir:
    mov rcx, r13
    mov rdx, 31
    mov r8, 22
    lea r9, [rel salida_msg]
    call imprimir_en

    xor rax, rax
    add rsp, 40
    pop r14
    pop r13
    pop r12
    pop rbp
    ret

.revisar_modo:
    ; Se lee GetTime() una vez por iteración, sin importar el modo: la alarma
    ; debe seguir comparando contra la hora aunque el usuario esté viendo el
    ; Cronómetro (ver docs/plan.md, Fase UEFI-4).
    mov rcx, r12
    lea rdx, [rel hora_efi_time]
    call leer_hora

    mov rcx, r13
    lea rdx, [rel hora_efi_time]
    call alarma_actualizar

    cmp byte [rel modo_actual], MODO_RELOJ
    je .actualizar_reloj
    jmp .actualizar_crono

.actualizar_reloj:
    movzx eax, byte [rel hora_efi_time + 6]  ; Second ya leído arriba
    cmp al, [rel ultimo_segundo]
    je loop_principal                          ; mismo segundo, no redibujar (evita parpadeo)
    mov [rel ultimo_segundo], al

    lea rsi, [rel hora_efi_time]
    lea rdi, [rel hora_buffer]
    call formatear_hora

    mov rcx, r13
    mov rdx, 36
    mov r8, 7
    lea r9, [rel hora_buffer]
    call imprimir_en
    jmp loop_principal

.actualizar_crono:
    mov rcx, r12
    call crono_segundos_transcurridos    ; eax = segundos totales

    cmp eax, [rel crono_ultimo_segundos]
    je loop_principal                      ; mismo segundo, no redibujar
    mov [rel crono_ultimo_segundos], eax

    xor edx, edx
    mov ecx, 60
    div ecx                                  ; eax = minutos, edx = segundos

    lea rdi, [rel crono_buffer]
    call formatear_cronometro

    mov rcx, r13
    mov rdx, 37
    mov r8, 7
    lea r9, [rel crono_buffer]
    call imprimir_en
    jmp loop_principal

; dibujar_titulo_modo
; Imprime el título correspondiente al modo actual en la fila 5. Local a
; este archivo (usa R13 ya cargado en efi_main, no un puntero propio).
dibujar_titulo_modo:
    cmp byte [rel modo_actual], MODO_RELOJ
    je .reloj
    mov rcx, r13
    mov rdx, 29
    mov r8, 5
    lea r9, [rel crono_titulo]
    call imprimir_en
    ret
.reloj:
    mov rcx, r13
    mov rdx, 31
    mov r8, 5
    lea r9, [rel reloj_titulo]
    call imprimir_en
    ret

    ; ==========================================================================
    ; 4. Salida limpia y retorno al firmware UEFI (inalcanzable por ahora:
    ; loop_principal es infinito hasta que la Fase UEFI-5 agregue la tecla Esc)
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
bienvenida_linea1     dw __utf16__("=== Reloj / Cronometro con Alarma ==="), 0
bienvenida_linea2     dw __utf16__("Tarea 1 - CE 4303"), 0
bienvenida_prompt     dw __utf16__("Presione ENTER para continuar..."), 0
reloj_titulo          dw __utf16__("-- Modo Reloj --"), 0
crono_titulo          dw __utf16__("-- Modo Cronometro --"), 0
controles_msg         dw __utf16__("M: modo | S: iniciar/pausar | R: reiniciar | Esc: salir"), 0
controles_msg2        dw __utf16__("A: alarma | C: cancelar alarma"), 0
salida_msg            dw __utf16__("Saliendo..."), 0
modo_actual           db MODO_RELOJ
ultimo_segundo        db 0xFF               ; Segundo ya dibujado; 0xFF fuerza el primer dibujo
crono_ultimo_segundos  dd 0xFFFFFFFF          ; Segundos ya dibujados del cronómetro; fuerza el primero
hora_efi_time           times 16 db 0           ; EFI_TIME devuelto por GetTime (ver rtc_uefi.asm)
hora_buffer              times 18 db 0            ; "HH:MM:SS" + nulo, UTF-16 (9 CHAR16 = 18 bytes)
crono_buffer              times 12 db 0             ; "MM:SS" + nulo, UTF-16 (6 CHAR16 = 12 bytes)
tecla_loop_buffer          times 4 db 0               ; EFI_INPUT_KEY del loop principal (no bloqueante)
