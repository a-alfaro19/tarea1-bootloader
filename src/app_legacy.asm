; ==============================================================================
; Aplicación de Reloj/Cronómetro con Alarma (Modo Legacy, se ejecuta en 0x7E00)
; ==============================================================================

[org 0x7E00]

KEY_ENTER equ 0x0D           ; Tecla que confirma la pantalla inicial

app_start:
    cld                   ; Asegura DF=0 para lodsb/stosb; el BIOS normalmente
                          ; ya lo deja así, pero no está garantizado en todo hardware.
    call limpiar_pantalla

    mov dh, 8
    mov dl, 21
    mov si, bienvenida_linea1
    call imprimir_en

    mov dh, 9
    mov dl, 31
    mov si, bienvenida_linea2
    call imprimir_en

    mov dh, 11
    mov dl, 24
    mov si, bienvenida_prompt
    call imprimir_en

esperar_confirmacion:
    call leer_tecla_bloqueante
    cmp al, KEY_ENTER
    jne esperar_confirmacion

    ; Confirmado: entra al modo Reloj. Los modos Cronómetro/Alarma y el
    ; cambio de modo con teclado llegan en las siguientes fases (docs/plan.md).
modo_reloj:
    call limpiar_pantalla
    mov dh, 5
    mov dl, 31
    mov si, reloj_titulo
    call imprimir_en

reloj_loop:
    call leer_hora_rtc          ; CH=hora, CL=minutos, DH=segundos (BCD)

    cmp dh, [ultimo_segundo]
    je reloj_loop                ; mismo segundo ya dibujado, no repetir (evita parpadeo)

    mov [ultimo_segundo], dh

    mov di, hora_buffer          ; ES:DI = destino (ES=0, heredado de boot_legacy.asm)
    call formatear_hora

    mov dh, 7
    mov dl, 36
    mov si, hora_buffer
    call imprimir_en

    jmp reloj_loop

; --- Datos de la Aplicación ---
bienvenida_linea1    db "=== Reloj / Cronometro con Alarma ===", 0
bienvenida_linea2    db "Tarea 1 - CE 4303", 0
bienvenida_prompt    db "Presione ENTER para continuar...", 0
reloj_titulo         db "-- Modo Reloj --", 0
ultimo_segundo       db 0xFF          ; Segundo BCD ya dibujado; 0xFF fuerza el primer dibujo
hora_buffer          times 9 db 0     ; "HH:MM:SS", 0

; --- Módulos de la aplicación (reloj/cronómetro/alarma) ---
%include "video.inc"
%include "teclado.inc"
%include "rtc.inc"
%include "cronometro.inc"
%include "alarma.inc"

; Rellenar el sector de la aplicación para que ocupe exactamente 512 bytes (1 sector)
times 510-($-$$) db 0
