; ==============================================================================
; teclado.inc — Lectura de tecla sin bloqueo/bloqueante (int 0x16), traducción
; scancode/ASCII -> acción, captura de dígitos para HH:MM.
; ==============================================================================

; leer_tecla_bloqueante
; Bloquea hasta que el usuario presione una tecla.
; Salida: AL = código ASCII de la tecla (AH queda con el scancode del BIOS)
leer_tecla_bloqueante:
    mov ah, 0x00
    int 0x16
    ret

; leer_tecla_no_bloqueante
; Revisa si hay una tecla en el buffer sin detener la ejecución (necesario en
; el loop principal, que debe seguir refrescando reloj/cronómetro aunque no
; se presione nada).
; Salida: CF=1 y AL=ASCII si había una tecla disponible (se consume del buffer);
;         CF=0 si no había ninguna (AL queda indefinido).
leer_tecla_no_bloqueante:
    mov ah, 0x01
    int 0x16
    jz .sin_tecla        ; ZF=1: el BIOS reporta el buffer de teclado vacío
    mov ah, 0x00          ; había tecla: consumirla del buffer para no releerla
    int 0x16
    stc
    ret
.sin_tecla:
    clc
    ret
