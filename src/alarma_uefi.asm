; ==============================================================================
; alarma_uefi.asm — Configuración HH:MM, comparación contra GetTime(),
; notificación (SetAttribute para parpadeo/color + beep por puertos I/O
; 0x61/0x42/0x43), cancelación. Fase UEFI-4 (ver SPEC_UEFI.md §2 — el beep es
; el mayor riesgo de portabilidad de todo el puerto, hay que probarlo en
; hardware real cuanto antes).
; ==============================================================================

bits 64
default rel

extern limpiar_pantalla
extern imprimir_en
extern leer_tecla_no_bloqueante
extern esperar_enter
extern set_atributo

section .text
global alarma_configurar
global alarma_actualizar
global alarma_cancelar

ALARMA_NINGUNA     equ 0
ALARMA_CONFIGURADA equ 1
ALARMA_DISPARADA   equ 2

KEY_ENTER equ 0x0D
KEY_ESC   equ 0x1B
SCAN_ESC  equ 0x17

ALARMA_ATRIBUTO_NORMAL equ 0x07   ; gris claro sobre negro (atributo de texto por defecto)
ALARMA_ATRIBUTO_ALERTA equ 0x4F   ; blanco sobre fondo rojo (parpadeo llamativo)

ALARMA_CAPTURA_COL equ 20         ; columna base donde se ecoan los 4 dígitos HHMM
ALARMA_CAPTURA_FILA equ 12
ALARMA_MENSAJE_FILA equ 14        ; fila donde se muestra confirmación/error/cancelación

ALARMA_BANNER_COL  equ 20         ; posición del aviso parpadeante "*** ALARMA ***"
ALARMA_BANNER_FILA equ 15

; Canal 2 del PIT (Programmable Interval Timer) + altavoz del PC: misma
; técnica que Legacy (I/O directo en vez de interrupción, ver SPEC.md §4).
; Divisor para ~1kHz: 1193182 Hz (frecuencia base del PIT) / 1000.
PIT_CANAL2   equ 0x42
PIT_COMANDO  equ 0x43
SPEAKER_PORT equ 0x61
BEEP_DIVISOR equ 1193

; ==============================================================================
; alarma_configurar
; Entrada: RCX = SystemTable
; Limpia pantalla, muestra el prompt y captura 4 dígitos (HHMM) tecleados uno
; por uno, ecoando cada uno en pantalla. Enter confirma (solo cuando ya hay 4
; dígitos), Esc cancela en cualquier momento sin tocar la alarma previa.
; No hay borrar-un-dígito (backspace): limitación aceptada, fuera del alcance
; de esta tarea (igual que el límite de ~60 min documentado en
; cronometro_uefi.asm).
; ==============================================================================
alarma_configurar:
    push rbp
    mov rbp, rsp
    push rbx
    push r13
    push r14
    push r15
    sub rsp, 32

    mov r14, [rcx + 64]      ; ConOut
    mov r13, [rcx + 48]      ; ConIn

    mov rcx, r14
    call limpiar_pantalla

    mov rcx, r14
    mov rdx, 10
    mov r8, 10
    lea r9, [rel alarma_prompt_msg]
    call imprimir_en

    mov byte [rel alarma_captura_contador], 0
    lea r15, [rel alarma_digitos]   ; puntero base para indexar con rbx (RIP-relative
                                     ; no admite sumar un registro índice en la misma
                                     ; instrucción, así que se resuelve la dirección una vez aquí)

.loop:
    mov rcx, r13
    lea rdx, [rel alarma_captura_tecla]
    call leer_tecla_no_bloqueante
    cmp rax, 0
    jne .loop                                        ; no había tecla

    movzx eax, word [rel alarma_captura_tecla]        ; ScanCode
    cmp eax, SCAN_ESC
    je .cancelado

    movzx eax, word [rel alarma_captura_tecla + 2]    ; UnicodeChar
    cmp eax, KEY_ESC
    je .cancelado

    movzx ebx, byte [rel alarma_captura_contador]
    cmp ebx, 4
    jge .revisar_enter          ; ya hay 4 dígitos, solo Enter (Esc ya se revisó arriba)

    cmp eax, '0'
    jl .loop
    cmp eax, '9'
    jg .loop

    mov ecx, eax                    ; conservar el carácter ASCII original para el eco
    sub eax, '0'                      ; eax = dígito binario 0-9
    mov [r15 + rbx], al

    mov [rel alarma_digito_echo], cx        ; dígitos ASCII == su valor UTF-16 (rango 0x30-0x39)
    mov word [rel alarma_digito_echo + 2], 0

    mov rcx, r14
    mov rdx, ALARMA_CAPTURA_COL
    add rdx, rbx                       ; columna = base + índice del dígito
    mov r8, ALARMA_CAPTURA_FILA
    lea r9, [rel alarma_digito_echo]
    call imprimir_en

    inc byte [rel alarma_captura_contador]
    jmp .loop

.revisar_enter:
    cmp eax, KEY_ENTER
    jne .loop
    jmp .validar

.validar:
    ; HH = dígitos 0,1 — MM = dígitos 2,3
    movzx eax, byte [rel alarma_digitos]
    imul eax, eax, 10
    movzx ecx, byte [rel alarma_digitos + 1]
    add eax, ecx                             ; eax = HH (0-99)
    cmp eax, 23
    ja .invalido
    mov [rel alarma_hora_tmp], al

    movzx eax, byte [rel alarma_digitos + 2]
    imul eax, eax, 10
    movzx ecx, byte [rel alarma_digitos + 3]
    add eax, ecx                               ; eax = MM (0-99)
    cmp eax, 59
    ja .invalido
    mov [rel alarma_minuto_tmp], al

    mov al, [rel alarma_hora_tmp]
    mov [rel alarma_hora], al
    mov al, [rel alarma_minuto_tmp]
    mov [rel alarma_minuto], al
    mov byte [rel alarma_estado], ALARMA_CONFIGURADA
    lea r9, [rel alarma_configurada_msg]
    jmp .mostrar_mensaje_final

.invalido:
    lea r9, [rel alarma_invalida_msg]
    jmp .mostrar_mensaje_final

.cancelado:
    lea r9, [rel alarma_cancelada_msg]

.mostrar_mensaje_final:
    mov rcx, r14
    mov rdx, 10
    mov r8, ALARMA_MENSAJE_FILA
    call imprimir_en

    mov rcx, r13
    call esperar_enter

    add rsp, 32
    pop r15
    pop r14
    pop r13
    pop rbx
    pop rbp
    ret

; ==============================================================================
; alarma_actualizar
; Entrada: RCX = ConOut (this), RDX = puntero a un EFI_TIME ya leído (Hour en
;          +4, Minute en +5, Second en +6)
; Se llama una vez por iteración del loop principal, en cualquier modo (Reloj
; o Cronómetro) — la alarma debe seguir funcionando en paralelo. Si está
; CONFIGURADA y coincide HH:MM, dispara (enciende el beep). Si ya está
; DISPARADA, hace parpadear un aviso en pantalla a ~1Hz (misma cadencia que
; el segundo del RTC, sin necesitar temporizador propio) hasta que se cancele.
; ==============================================================================
alarma_actualizar:
    push rbp
    mov rbp, rsp
    push rbx
    push r15
    sub rsp, 32

    mov rbx, rcx      ; conservar ConOut
    mov r15, rdx        ; conservar puntero a EFI_TIME

    cmp byte [rel alarma_estado], ALARMA_CONFIGURADA
    jne .revisar_disparada

    movzx eax, byte [r15 + 4]     ; Hour
    cmp al, [rel alarma_hora]
    jne .fin
    movzx eax, byte [r15 + 5]      ; Minute
    cmp al, [rel alarma_minuto]
    jne .fin

    mov byte [rel alarma_estado], ALARMA_DISPARADA
    mov byte [rel alarma_ultimo_segundo], 0xFF   ; fuerza el primer dibujo del aviso
    call alarma_beep_on
    jmp .fin

.revisar_disparada:
    cmp byte [rel alarma_estado], ALARMA_DISPARADA
    jne .fin

    movzx eax, byte [r15 + 6]        ; Second
    cmp al, [rel alarma_ultimo_segundo]
    je .fin                            ; mismo segundo ya dibujado, no repetir (evita parpadeo falso)
    mov [rel alarma_ultimo_segundo], al

    and eax, 1
    jz .mostrar_alerta

    mov rcx, rbx
    mov rdx, ALARMA_ATRIBUTO_NORMAL
    call set_atributo
    mov rcx, rbx
    mov rdx, ALARMA_BANNER_COL
    mov r8, ALARMA_BANNER_FILA
    lea r9, [rel alarma_alerta_blank]
    call imprimir_en
    jmp .fin

.mostrar_alerta:
    mov rcx, rbx
    mov rdx, ALARMA_ATRIBUTO_ALERTA
    call set_atributo
    mov rcx, rbx
    mov rdx, ALARMA_BANNER_COL
    mov r8, ALARMA_BANNER_FILA
    lea r9, [rel alarma_alerta_msg]
    call imprimir_en

    ; SetAttribute es un estado global de ConOut: queda vigente para todo el
    ; texto que se imprima después, no solo para el banner. Hay que devolverlo
    ; a NORMAL de inmediato o el próximo redibujo del reloj/cronómetro
    ; (fuera de esta rutina) hereda el atributo rojo de la alarma.
    mov rcx, rbx
    mov rdx, ALARMA_ATRIBUTO_NORMAL
    call set_atributo

.fin:
    add rsp, 32
    pop r15
    pop rbx
    pop rbp
    ret

; ==============================================================================
; alarma_cancelar
; Entrada: RCX = ConOut (this)
; Cancela la alarma, tanto antes como después de dispararse (tecla C): apaga
; el beep, restaura el atributo normal, borra el aviso parpadeante si estaba
; visible, y vuelve el estado a NINGUNA. Llamarla sin alarma activa es un
; no-op seguro.
; ==============================================================================
alarma_cancelar:
    push rbp
    mov rbp, rsp
    push rbx
    sub rsp, 40

    mov rbx, rcx

    call alarma_beep_off

    mov rcx, rbx
    mov rdx, ALARMA_ATRIBUTO_NORMAL
    call set_atributo

    mov rcx, rbx
    mov rdx, ALARMA_BANNER_COL
    mov r8, ALARMA_BANNER_FILA
    lea r9, [rel alarma_alerta_blank]
    call imprimir_en

    mov byte [rel alarma_estado], ALARMA_NINGUNA

    add rsp, 40
    pop rbx
    pop rbp
    ret

; alarma_beep_on / alarma_beep_off
; Sin argumentos. Locales a este archivo (solo las llama alarma_actualizar/
; alarma_cancelar). No hacen ninguna llamada propia, así que no necesitan
; shadow space adicional más allá del que ya reservó el llamador.
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
    or al, 0x03                   ; bits 0/1: gate del canal 2 + datos del altavoz
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

; ==============================================================================
; Sección de Datos Estáticos
; ==============================================================================
section .data
alarma_estado  db ALARMA_NINGUNA
alarma_hora    db 0
alarma_minuto  db 0

alarma_ultimo_segundo db 0xFF

alarma_prompt_msg      dw __utf16__("Configurar alarma HH:MM (Enter=ok, Esc=cancela):"), 0
alarma_invalida_msg    dw __utf16__("Hora invalida (00-23:00-59). Alarma no configurada."), 0
alarma_cancelada_msg   dw __utf16__("Captura de alarma cancelada."), 0
alarma_configurada_msg dw __utf16__("Alarma configurada."), 0

alarma_alerta_msg    dw __utf16__("*** ALARMA *** (C: cancelar)"), 0
alarma_alerta_blank  dw __utf16__("                             "), 0

alarma_captura_contador db 0
alarma_digitos           times 4 db 0     ; valores binarios 0-9 tecleados (HHMM)
alarma_digito_echo        dw 0, 0           ; buffer UTF-16 de un carácter para ecoar cada dígito
alarma_captura_tecla        times 4 db 0     ; EFI_INPUT_KEY del loop de captura

alarma_hora_tmp   db 0
alarma_minuto_tmp db 0
