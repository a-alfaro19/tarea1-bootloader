; ==============================================================================
; Aplicación de Reloj/Cronómetro con Alarma (Modo Legacy, se ejecuta en 0x7E00)
; ==============================================================================

[org 0x7E00]

KEY_ENTER       equ 0x0D      ; Tecla que confirma la pantalla inicial
KEY_ESC         equ 0x1B      ; Tecla para salir de la aplicación
MODO_RELOJ      equ 0
MODO_CRONOMETRO equ 1

app_start:
    cld                   ; Asegura DF=0 para lodsb/stosb; el BIOS normalmente
                          ; ya lo deja así, pero no está garantizado en todo hardware.
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7B00
    mov [boot_drive_guard], dl   ; conserva el drive original del BIOS antes de
                                ; invocar BIOS/INTs que pueden reutilizar DL
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

    ; Confirmado: entra al modo interactivo (Reloj por defecto). El modo
    ; Alarma llega en la siguiente fase (docs/plan.md).
interactivo:
    call limpiar_pantalla
    mov byte [modo_actual], MODO_RELOJ
    mov byte [ultimo_segundo], 0xFF        ; fuerza el primer dibujo del reloj
    mov word [crono_ultimo_segundos], 0xFFFF ; fuerza el primer dibujo del cronómetro
    call dibujar_titulo_modo

    mov dh, 20
    mov dl, 10
    mov si, controles_msg
    call imprimir_en

    mov dh, 21
    mov dl, 10
    mov si, controles_msg2
    call imprimir_en

loop_principal:
    call leer_tecla_no_bloqueante
    jnc .revisar_modo

    cmp al, 'M'
    je .tecla_modo
    cmp al, 'm'
    je .tecla_modo
    cmp al, 'S'
    je .tecla_start
    cmp al, 's'
    je .tecla_start
    cmp al, 'R'
    je .tecla_reset
    cmp al, 'r'
    je .tecla_reset
    cmp al, 'A'
    je .tecla_alarma
    cmp al, 'a'
    je .tecla_alarma
    cmp al, 'C'
    je .tecla_cancelar_alarma
    cmp al, 'c'
    je .tecla_cancelar_alarma
    cmp al, KEY_ESC
    je .tecla_salir
    jmp .revisar_modo

.tecla_modo:
    xor byte [modo_actual], 1              ; alterna 0 <-> 1 (MODO_RELOJ/MODO_CRONOMETRO)
    call limpiar_pantalla
    mov byte [ultimo_segundo], 0xFF
    mov word [crono_ultimo_segundos], 0xFFFF
    call dibujar_titulo_modo
    mov dh, 20
    mov dl, 10
    mov si, controles_msg
    call imprimir_en
    mov dh, 21
    mov dl, 10
    mov si, controles_msg2
    call imprimir_en
    jmp loop_principal

.tecla_start:
    call crono_iniciar_pausar_reanudar
    jmp loop_principal

.tecla_reset:
    call crono_reiniciar
    mov word [crono_ultimo_segundos], 0xFFFF  ; fuerza redibujar a 00:00
    jmp loop_principal

.tecla_alarma:
    call alarma_configurar

    ; alarma_configurar dibuja su propia pantalla de captura; al volver hay
    ; que redibujar la pantalla principal (título + controles), mismo patrón
    ; que .tecla_modo.
    call limpiar_pantalla
    mov byte [ultimo_segundo], 0xFF
    mov word [crono_ultimo_segundos], 0xFFFF
    call dibujar_titulo_modo
    mov dh, 20
    mov dl, 10
    mov si, controles_msg
    call imprimir_en
    mov dh, 21
    mov dl, 10
    mov si, controles_msg2
    call imprimir_en
    jmp loop_principal

.tecla_cancelar_alarma:
    call alarma_cancelar
    jmp loop_principal

.tecla_salir:
    mov dh, 22
    mov dl, 31
    mov si, salida_msg
    call imprimir_en

    ; Reanudar el valor original del drive para que el MBR vuelva a cargar la
    ; app sin fallar por un DL ya contaminado.
    mov dl, [boot_drive_guard]

    ; Reiniciar el estado del modo real y limpiar la pantalla antes de volver al
    ; bootloader, para que el mensaje de bienvenida vuelva a mostrarse limpio.
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7B00
    mov ah, 0x00
    mov al, 0x03
    int 0x10
    jmp 0x0000:0x7C00

.revisar_modo:
    ; Se lee el RTC una vez por iteración, sin importar el modo: la alarma
    ; debe seguir comparando aunque el usuario esté viendo el Cronómetro.
    call leer_hora_rtc              ; CH=hora, CL=minutos, DH=segundos (BCD)
    call alarma_actualizar          ; usa CH/CL/DH ya leídos; no los modifica

    cmp byte [modo_actual], MODO_RELOJ
    je .actualizar_reloj
    jmp .actualizar_crono

.actualizar_reloj:
    cmp dh, [ultimo_segundo]
    je loop_principal                ; mismo segundo ya dibujado, no repetir (evita parpadeo)
    mov [ultimo_segundo], dh

    mov di, hora_buffer               ; ES:DI = destino (ES=0, heredado de boot_legacy.asm)
    call formatear_hora

    mov dh, 7
    mov dl, 36
    mov si, hora_buffer
    call imprimir_en
    jmp loop_principal

.actualizar_crono:
    call crono_ticks_transcurridos    ; DX = ticks acumulados (~18.2/seg)
    mov ax, dx
    xor dx, dx
    mov cx, 18
    div cx                              ; ax = segundos totales transcurridos (aprox.)

    cmp ax, [crono_ultimo_segundos]
    je loop_principal                    ; mismo segundo ya dibujado, no repetir
    mov [crono_ultimo_segundos], ax

    xor dx, dx
    mov cx, 60
    div cx                               ; ax = minutos, dx = segundos
    mov ah, dl                            ; empaquetar para formatear_cronometro: AL=min, AH=seg

    mov di, crono_buffer
    call formatear_cronometro

    mov dh, 7
    mov dl, 37
    mov si, crono_buffer
    call imprimir_en
    jmp loop_principal

; dibujar_titulo_modo
; Imprime el título correspondiente al modo actual en la fila 5.
dibujar_titulo_modo:
    cmp byte [modo_actual], MODO_RELOJ
    je .reloj
    mov dh, 5
    mov dl, 29
    mov si, crono_titulo
    call imprimir_en
    ret
.reloj:
    mov dh, 5
    mov dl, 31
    mov si, reloj_titulo
    call imprimir_en
    ret

; --- Datos de la Aplicación ---
bienvenida_linea1      db "=== Reloj / Cronometro con Alarma ===", 0
bienvenida_linea2      db "Tarea 1 - CE 4303", 0
bienvenida_prompt      db "Presione ENTER para continuar...", 0
reloj_titulo           db "-- Modo Reloj --", 0
crono_titulo           db "-- Modo Cronometro --", 0
controles_msg          db "M: modo | S: iniciar/pausar | R: reiniciar | Esc: salir", 0
controles_msg2         db "A: alarma | C: cancelar alarma", 0
salida_msg             db "Saliendo...", 0
modo_actual            db MODO_RELOJ
ultimo_segundo         db 0xFF          ; Segundo BCD ya dibujado; 0xFF fuerza el primer dibujo
crono_ultimo_segundos  dw 0xFFFF        ; Segundos ya dibujados del cronómetro; 0xFFFF fuerza el primero
hora_buffer            times 9 db 0     ; "HH:MM:SS", 0
crono_buffer           times 6 db 0     ; "MM:SS", 0
boot_drive_guard       db 0

; --- Módulos de la aplicación (reloj/cronómetro/alarma) ---
%include "video.inc"
%include "teclado.inc"
%include "rtc.inc"
%include "cronometro.inc"
%include "alarma.inc"

; Rellenar hasta ocupar exactamente 3 sectores (1536 bytes). Debe coincidir
; con "mov al, 0x03" en boot_legacy.asm y con el "count" del dd en el Makefile.
times (3*512-2)-($-$$) db 0
