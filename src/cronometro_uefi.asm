; ==============================================================================
; cronometro_uefi.asm — Cronómetro con estados detenido/corriendo/pausado,
; usando GetTime() como fuente de tiempo (UEFI no tiene un "tick counter"
; equivalente al de BIOS). Guarda un EFI_TIME de referencia al iniciar o
; reanudar y calcula la diferencia en segundos contra la lectura actual —
; mismo patrón que src/cronometro.inc (Legacy).
;
; NOTA: la diferencia se calcula como "segundos desde medianoche"
; (Hour*3600+Minute*60+Second). Si el cronómetro queda corriendo justo
; cuando el reloj cruza medianoche, el cálculo daría un valor negativo/
; incorrecto para ese tramo — limitación aceptada y documentada, análoga a
; la del tick counter de 16 bits en Legacy (~60 min), fuera de cualquier
; escenario real de demo o defensa.
; ==============================================================================

bits 64
default rel

extern leer_hora
extern bin_a_utf16

section .text
global crono_iniciar_pausar_reanudar
global crono_reiniciar
global crono_segundos_transcurridos
global formatear_cronometro

CRONO_DETENIDO  equ 0
CRONO_CORRIENDO equ 1
CRONO_PAUSADO   equ 2

; segundos_del_dia
; Entrada: RSI = puntero a EFI_TIME (Hour en +4, Minute en +5, Second en +6)
; Salida: EAX = Hour*3600 + Minute*60 + Second
; No hace ninguna llamada propia (no necesita shadow space) ni modifica RSI.
segundos_del_dia:
    movzx eax, byte [rsi + 4]
    imul eax, eax, 3600
    movzx ecx, byte [rsi + 5]
    imul ecx, ecx, 60
    add eax, ecx
    movzx ecx, byte [rsi + 6]
    add eax, ecx
    ret

; crono_iniciar_pausar_reanudar
; Entrada: RCX = puntero a SystemTable
; Alterna el cronómetro según su estado actual (tecla S):
;   detenido/pausado -> corriendo (guarda un EFI_TIME de referencia)
;   corriendo         -> pausado (acumula el tramo transcurrido)
crono_iniciar_pausar_reanudar:
    push rbp
    mov rbp, rsp
    push rbx
    sub rsp, 40          ; 2 pushes (par, RSP%16 vuelve a 8) + 40 (8 mod16) -> alinea a 0

    cmp byte [rel crono_estado], CRONO_CORRIENDO
    je .pausar

    lea rdx, [rel crono_inicio_efi_time]
    call leer_hora                          ; RCX ya trae SystemTable
    mov byte [rel crono_estado], CRONO_CORRIENDO
    jmp .fin

.pausar:
    lea rdx, [rel crono_ahora_tmp]
    call leer_hora                            ; RCX ya trae SystemTable

    lea rsi, [rel crono_ahora_tmp]
    call segundos_del_dia                       ; eax = segundos de ahora
    mov ebx, eax

    lea rsi, [rel crono_inicio_efi_time]
    call segundos_del_dia                          ; eax = segundos de cuando inició/reanudó
    sub ebx, eax                                     ; ebx = elapsed de este tramo
    add [rel crono_acumulado_segundos], ebx
    mov byte [rel crono_estado], CRONO_PAUSADO

.fin:
    add rsp, 40
    pop rbx
    pop rbp
    ret

; crono_reiniciar
; Vuelve el cronómetro a 0 y lo detiene (tecla R), sin importar el estado actual.
crono_reiniciar:
    mov byte [rel crono_estado], CRONO_DETENIDO
    mov dword [rel crono_acumulado_segundos], 0
    ret

; crono_segundos_transcurridos
; Entrada: RCX = puntero a SystemTable
; Salida: EAX = segundos transcurridos totales (acumulados + tramo actual si corre)
crono_segundos_transcurridos:
    push rbp
    mov rbp, rsp
    push rbx
    push r15
    sub rsp, 32           ; 3 pushes (impar, RSP%16 vuelve a 0) + 32 (0 mod16) -> sigue en 0

    mov ebx, [rel crono_acumulado_segundos]
    cmp byte [rel crono_estado], CRONO_CORRIENDO
    jne .fin

    lea rdx, [rel crono_ahora_tmp]
    call leer_hora                    ; RCX ya trae SystemTable

    lea rsi, [rel crono_ahora_tmp]
    call segundos_del_dia               ; eax = segundos de ahora
    mov r15d, eax                        ; guardar en registro non-volatile (no en pila,
                                          ; para no desalinear la siguiente llamada)

    lea rsi, [rel crono_inicio_efi_time]
    call segundos_del_dia                  ; eax = segundos de cuando inició/reanudó

    sub r15d, eax                            ; r15d = elapsed del tramo actual
    add ebx, r15d

.fin:
    mov eax, ebx
    add rsp, 32
    pop r15
    pop rbx
    pop rbp
    ret

; formatear_cronometro
; Entrada: EAX = minutos (0-99), EDX = segundos (0-59), RDI = destino
;          (UTF-16, mínimo 12 bytes: "MM:SS" + nulo)
; bin_a_utf16 preserva RDX internamente (solo usa DL como escritorio y lo
; restaura), así que EDX=segundos sobrevive a la primera llamada sin
; necesidad de guardarlo aparte.
formatear_cronometro:
    call bin_a_utf16        ; AL ya trae minutos
    mov ax, ':'
    stosw
    mov eax, edx              ; segundos -> eax para reusar bin_a_utf16
    call bin_a_utf16
    xor ax, ax
    stosw                       ; terminador nulo
    ret

; ==============================================================================
; Estado y buffers del cronómetro
; ==============================================================================
section .data
crono_estado           db CRONO_DETENIDO
crono_acumulado_segundos dd 0
crono_inicio_efi_time     times 16 db 0    ; EFI_TIME de cuando inició/reanudó
crono_ahora_tmp             times 16 db 0    ; buffer temporal para la lectura "ahora"
