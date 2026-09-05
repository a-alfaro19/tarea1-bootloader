; ==============================================================================
; cronometro.inc — Conteo independiente basado en el tick counter del BIOS
; (int 0x1A, ah=0x00, ~18.2 ticks/seg), con estados detenido/corriendo/pausado
; y reinicio.
;
; NOTA: solo se usa la palabra baja del contador de ticks (16 bits), que
; alcanza para ~3600 segundos (~60 minutos) antes de dar la vuelta. Es más
; que suficiente para cualquier demo/defensa de esta tarea y evita la
; aritmética de 32 bits que no aportaría nada dentro de ese alcance.
; ==============================================================================

CRONO_DETENIDO  equ 0
CRONO_CORRIENDO equ 1
CRONO_PAUSADO   equ 2

crono_estado            db CRONO_DETENIDO
crono_ticks_inicio      dw 0    ; valor del contador cuando arrancó/reanudó
crono_ticks_acumulados  dw 0    ; ticks acumulados de tramos "corriendo" anteriores

; leer_tick_counter
; Salida: DX = palabra baja del contador de ticks del BIOS (~18.2/seg)
leer_tick_counter:
    mov ah, 0x00
    int 0x1A
    ret

; crono_iniciar_pausar_reanudar
; Alterna el cronómetro según su estado actual (tecla S):
;   detenido/pausado -> corriendo (guarda el tick de arranque/reanudación)
;   corriendo         -> pausado (acumula el tramo transcurrido)
crono_iniciar_pausar_reanudar:
    push ax
    push dx
    cmp byte [crono_estado], CRONO_CORRIENDO
    je .pausar

    call leer_tick_counter
    mov [crono_ticks_inicio], dx
    mov byte [crono_estado], CRONO_CORRIENDO
    jmp .fin

.pausar:
    call leer_tick_counter
    sub dx, [crono_ticks_inicio]
    add [crono_ticks_acumulados], dx
    mov byte [crono_estado], CRONO_PAUSADO

.fin:
    pop dx
    pop ax
    ret

; crono_reiniciar
; Vuelve el cronómetro a 0 y lo detiene (tecla R), sin importar el estado actual.
crono_reiniciar:
    mov byte [crono_estado], CRONO_DETENIDO
    mov word [crono_ticks_acumulados], 0
    mov word [crono_ticks_inicio], 0
    ret

; crono_ticks_transcurridos
; Salida: DX = ticks transcurridos totales (acumulados + tramo actual si corre)
crono_ticks_transcurridos:
    push ax
    mov dx, [crono_ticks_acumulados]
    cmp byte [crono_estado], CRONO_CORRIENDO
    jne .fin
    push dx
    call leer_tick_counter
    sub dx, [crono_ticks_inicio]
    pop ax
    add dx, ax
.fin:
    pop ax
    ret

; bin_a_ascii
; Entrada: AL = valor binario (0-99, no BCD), ES:DI = destino
; Convierte un valor binario a dos dígitos ASCII decimales (división entre 10).
bin_a_ascii:
    push ax
    push bx
    xor ah, ah
    mov bl, 10
    div bl              ; AL = decena, AH = unidad
    add al, '0'
    stosb
    mov al, ah
    add al, '0'
    stosb
    pop bx
    pop ax
    ret

; formatear_cronometro
; Entrada: AL = minutos (0-99), AH = segundos (0-59), ES:DI = buffer destino
;          (mínimo 6 bytes: "MM:SS",0)
formatear_cronometro:
    call bin_a_ascii      ; imprime minutos; preserva AX completo (push/pop interno)
    push ax                ; guardar AH=segundos antes de pisar AL con ':'
    mov al, ':'
    stosb
    pop ax
    mov al, ah              ; segundos -> AL para reusar bin_a_ascii
    call bin_a_ascii
    mov al, 0
    stosb
    ret
