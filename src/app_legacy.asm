; ==============================================================================
; Aplicación de Reloj/Cronómetro con Alarma (Modo Legacy, se ejecuta en 0x7E00)
; ==============================================================================

[org 0x7E00]

KEY_ENTER equ 0x0D           ; Tecla que confirma la pantalla inicial

app_start:
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

    ; Confirmado. Placeholder del modo interactivo: los modos Reloj y
    ; Cronómetro se integran en las siguientes fases del plan (docs/plan.md).
    call limpiar_pantalla
    mov dh, 10
    mov dl, 20
    mov si, modo_interactivo_msg
    call imprimir_en

app_hang:
    cli
    hlt
    jmp app_hang

; --- Datos de la Aplicación ---
bienvenida_linea1    db "=== Reloj / Cronometro con Alarma ===", 0
bienvenida_linea2    db "Tarea 1 - CE 4303", 0
bienvenida_prompt    db "Presione ENTER para continuar...", 0
modo_interactivo_msg db "Confirmado. (modo interactivo: pendiente)", 0

; --- Módulos de la aplicación (reloj/cronómetro/alarma) ---
%include "video.inc"
%include "teclado.inc"
%include "rtc.inc"
%include "cronometro.inc"
%include "alarma.inc"

; Rellenar el sector de la aplicación para que ocupe exactamente 512 bytes (1 sector)
times 510-($-$$) db 0
