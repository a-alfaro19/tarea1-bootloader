; ==============================================================================
; alarma.inc — Estado de alarma (config/activa/ninguna), comparación HH:MM
; contra RTC, notificación (parpadeo de atributo de pantalla + beep vía
; puertos 0x61/0x42/0x43), cancelación. Puerto de src/alarma_uefi.asm (Fase
; UEFI-4) a modo real: mismo diseño, pero comparando en BCD directo contra
; leer_hora_rtc (rtc.inc) en vez de convertir a binario, y usando ASCII de un
; byte en vez de UTF-16.
; ==============================================================================

ALARMA_NINGUNA     equ 0
ALARMA_CONFIGURADA equ 1
ALARMA_DISPARADA   equ 2

ALARMA_ATRIBUTO_NORMAL equ 0x07   ; gris claro sobre negro (atributo por defecto del modo texto)
ALARMA_ATRIBUTO_ALERTA equ 0x4F   ; blanco sobre fondo rojo (parpadeo llamativo)

ALARMA_PROMPT_FILA  equ 10   ; fila del prompt "Configurar alarma..." (distinta de la
                              ; fila de eco de dígitos, para no pisarse entre sí)
ALARMA_PROMPT_COL   equ 10
ALARMA_CAPTURA_FILA equ 12
ALARMA_CAPTURA_COL  equ 20
ALARMA_MENSAJE_FILA equ 14
ALARMA_MENSAJE_COL  equ 10
ALARMA_BANNER_FILA  equ 15
ALARMA_BANNER_COL   equ 20

; Canal 2 del PIT (Programmable Interval Timer) + altavoz del PC: I/O directo
; a los puertos, sin pasar por una interrupción (misma técnica documentada en
; SPEC.md §4 y reusada tal cual en el puerto UEFI). Divisor para ~1kHz:
; 1193182 Hz (frecuencia base del PIT) / 1000.
PIT_CANAL2   equ 0x42
PIT_COMANDO  equ 0x43
SPEAKER_PORT equ 0x61
BEEP_DIVISOR equ 1193

alarma_estado          db ALARMA_NINGUNA
alarma_hora             db 0     ; BCD, mismo formato que CH de leer_hora_rtc
alarma_minuto           db 0     ; BCD, mismo formato que CL de leer_hora_rtc
alarma_ultimo_segundo   db 0xFF  ; fuerza el primer dibujo/borrado del aviso

alarma_captura_contador db 0
alarma_digitos          times 4 db 0   ; dígitos binarios 0-9 tecleados (HHMM)
alarma_digito_echo      db 0, 0        ; 1 carácter + terminador, para ecoar cada dígito

alarma_prompt_msg      db "Configurar alarma HH:MM (Enter=ok, Esc=cancela):", 0
alarma_invalida_msg    db "Hora invalida (00-23:00-59). Alarma no configurada.", 0
alarma_cancelada_msg   db "Captura de alarma cancelada.", 0
alarma_configurada_msg db "Alarma configurada.", 0
alarma_alerta_msg      db "*** ALARMA *** (C: cancelar)", 0
alarma_alerta_blank    db "                             ", 0

; alarma_configurar
; Limpia pantalla, pide HH:MM dígito por dígito (0-9, sin backspace — mismo
; límite aceptado que en el puerto UEFI), Enter confirma una vez hay 4
; dígitos, Esc cancela en cualquier momento sin tocar una alarma previamente
; configurada. Al terminar espera un Enter para que el usuario alcance a leer
; el mensaje de resultado antes de volver a la pantalla principal.
alarma_configurar:
    call limpiar_pantalla

    mov dh, ALARMA_PROMPT_FILA
    mov dl, ALARMA_PROMPT_COL
    mov si, alarma_prompt_msg
    call imprimir_en

    mov byte [alarma_captura_contador], 0

.loop:
    call leer_tecla_no_bloqueante
    jnc .loop                    ; sin tecla todavía, seguir esperando

    cmp al, KEY_ESC
    je .cancelado

    mov bl, [alarma_captura_contador]
    cmp bl, 4
    jae .revisar_enter           ; ya hay 4 dígitos, solo Enter avanza (Esc ya se revisó arriba)

    cmp al, '0'
    jb .loop
    cmp al, '9'
    ja .loop

    mov ah, al                   ; conservar el ASCII original para el eco
    sub al, '0'                  ; al = dígito binario 0-9
    xor bh, bh                   ; bx = índice del dígito (bl ya tiene el contador)
    mov [alarma_digitos + bx], al

    mov [alarma_digito_echo], ah

    mov dh, ALARMA_CAPTURA_FILA
    mov dl, ALARMA_CAPTURA_COL
    add dl, bl
    mov si, alarma_digito_echo
    call imprimir_en

    inc byte [alarma_captura_contador]
    jmp .loop

.revisar_enter:
    cmp al, KEY_ENTER
    jne .loop

.validar:
    ; HH = dígitos 0,1 (decena/unidad) — MM = dígitos 2,3
    mov al, [alarma_digitos]
    mov cl, 10
    mul cl                       ; ax = dígito0 * 10 (0-90)
    add al, [alarma_digitos+1]   ; al = dígito0*10+dígito1 (0-99, cabe en al)
    cmp al, 23
    ja .invalido

    mov cl, [alarma_digitos]
    shl cl, 4
    or cl, [alarma_digitos+1]
    mov [alarma_hora], cl        ; empaqueta directo a BCD: nibble alto=decena, bajo=unidad

    mov al, [alarma_digitos+2]
    mov cl, 10
    mul cl
    add al, [alarma_digitos+3]
    cmp al, 59
    ja .invalido

    mov cl, [alarma_digitos+2]
    shl cl, 4
    or cl, [alarma_digitos+3]
    mov [alarma_minuto], cl

    mov byte [alarma_estado], ALARMA_CONFIGURADA
    mov si, alarma_configurada_msg
    jmp .mensaje_final

.invalido:
    mov si, alarma_invalida_msg
    jmp .mensaje_final

.cancelado:
    mov si, alarma_cancelada_msg

.mensaje_final:
    mov dh, ALARMA_MENSAJE_FILA
    mov dl, ALARMA_MENSAJE_COL
    call imprimir_en

.espera_enter:
    call leer_tecla_bloqueante
    cmp al, KEY_ENTER
    jne .espera_enter
    ret

; alarma_actualizar
; Entrada: CH=hora, CL=minutos, DH=segundos (BCD, ya leídos por leer_hora_rtc
; en el loop principal — se llama una vez por iteración, sin importar el modo
; visible, para que la alarma siga comparando aunque el usuario esté en modo
; Cronómetro). No modifica CH/CL/DH: el llamador los sigue necesitando para
; redibujar el reloj.
; Si está CONFIGURADA y coincide HH:MM, dispara (enciende el beep). Si ya
; está DISPARADA, hace parpadear un aviso en pantalla a ~1Hz (misma cadencia
; que el segundo del RTC, sin necesitar temporizador propio) hasta cancelarse.
alarma_actualizar:
    push ax
    push bx
    push cx
    push dx
    push si

    cmp byte [alarma_estado], ALARMA_CONFIGURADA
    jne .revisar_disparada

    cmp ch, [alarma_hora]
    jne .fin
    cmp cl, [alarma_minuto]
    jne .fin

    mov byte [alarma_estado], ALARMA_DISPARADA
    mov byte [alarma_ultimo_segundo], 0xFF   ; fuerza el primer dibujo del aviso
    call alarma_beep_on
    jmp .fin

.revisar_disparada:
    cmp byte [alarma_estado], ALARMA_DISPARADA
    jne .fin

    cmp dh, [alarma_ultimo_segundo]
    je .fin                       ; mismo segundo ya dibujado, no repetir (evita parpadeo falso)
    mov [alarma_ultimo_segundo], dh

    ; DH es BCD (nibble alto=decena, bajo=unidad de los segundos). El bit 0
    ; del byte completo es el bit 0 del nibble bajo, es decir, el bit 0 del
    ; dígito de unidad — y la paridad de cualquier número decimal depende
    ; solo de su dígito de unidad (las decenas son siempre múltiplo de 10,
    ; par). Por eso "test dh,1" da la paridad real del segundo sin convertir
    ; de BCD a binario.
    test dh, 1
    jz .mostrar_alerta

    mov si, alarma_alerta_blank
    mov bl, ALARMA_ATRIBUTO_NORMAL
    jmp .dibujar_banner

.mostrar_alerta:
    mov si, alarma_alerta_msg
    mov bl, ALARMA_ATRIBUTO_ALERTA

.dibujar_banner:
    mov dh, ALARMA_BANNER_FILA
    mov dl, ALARMA_BANNER_COL
    call imprimir_en_attr

.fin:
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; alarma_cancelar
; Cancela la alarma, tanto antes como después de dispararse (tecla C): apaga
; el beep, borra el aviso parpadeante si estaba visible, y vuelve el estado a
; NINGUNA. Llamarla sin alarma activa es un no-op seguro.
alarma_cancelar:
    push ax
    push bx
    push dx
    push si

    call alarma_beep_off

    mov dh, ALARMA_BANNER_FILA
    mov dl, ALARMA_BANNER_COL
    mov si, alarma_alerta_blank
    mov bl, ALARMA_ATRIBUTO_NORMAL
    call imprimir_en_attr

    mov byte [alarma_estado], ALARMA_NINGUNA

    pop si
    pop dx
    pop bx
    pop ax
    ret

; alarma_beep_on / alarma_beep_off
; Sin argumentos, sin valor de retorno. Programan el canal 2 del PIT a
; ~1kHz (onda cuadrada) y abren/cierran el gate del altavoz del puerto 0x61.
alarma_beep_on:
    push ax
    push dx

    mov al, 0xB6                ; canal 2, modo 3 (onda cuadrada), lobyte/hibyte, binario
    out PIT_COMANDO, al
    mov ax, BEEP_DIVISOR
    out PIT_CANAL2, al
    mov al, ah
    out PIT_CANAL2, al

    in al, SPEAKER_PORT
    or al, 0x03                  ; bits 0/1: gate del canal 2 + datos del altavoz
    out SPEAKER_PORT, al

    pop dx
    pop ax
    ret

alarma_beep_off:
    push ax
    in al, SPEAKER_PORT
    and al, 0xFC
    out SPEAKER_PORT, al
    pop ax
    ret
