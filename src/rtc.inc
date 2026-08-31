; ==============================================================================
; rtc.inc — Lectura de hora del RTC (int 0x1A, ah=0x02), conversión BCD ->
; ASCII, formateo HH:MM:SS para impresión.
; ==============================================================================

; leer_hora_rtc
; Lee la hora actual del RTC vía la BIOS.
; Salida: CH = hora (BCD), CL = minutos (BCD), DH = segundos (BCD)
leer_hora_rtc:
    mov ah, 0x02
    int 0x1A
    ret

; bcd_a_ascii
; Entrada: AL = un byte BCD (0x00-0x99), ES:DI = destino
; El RTC devuelve cada campo empacado en BCD (nibble alto = decena,
; nibble bajo = unidad) — no es un binario normal, hay que separar nibbles.
; Escribe 2 caracteres ASCII en [ES:DI] y [ES:DI+1], avanza DI en 2.
bcd_a_ascii:
    push ax
    mov ah, al
    shr al, 4
    add al, '0'
    stosb
    mov al, ah
    and al, 0x0F
    add al, '0'
    stosb
    pop ax
    ret

; formatear_hora
; Entrada: CH = hora (BCD), CL = minutos (BCD), DH = segundos (BCD),
;          ES:DI = puntero al buffer destino (mínimo 9 bytes: "HH:MM:SS",0)
; Requiere ES = segmento donde vive el buffer (en esta app, ES=0 se hereda
; de la configuración de segmentos que hace boot_legacy.asm antes de saltar
; a 0x7E00). No modifica CH/CL/DH.
formatear_hora:
    push ax
    mov al, ch
    call bcd_a_ascii
    mov al, ':'
    stosb
    mov al, cl
    call bcd_a_ascii
    mov al, ':'
    stosb
    mov al, dh
    call bcd_a_ascii
    mov al, 0
    stosb
    pop ax
    ret
