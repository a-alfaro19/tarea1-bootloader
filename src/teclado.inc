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
