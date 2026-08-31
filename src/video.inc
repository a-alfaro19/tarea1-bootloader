; ==============================================================================
; video.inc — Helpers de pantalla: limpiar pantalla, posicionar cursor
; (int 0x10 ah=0x02), imprimir string en posición fija, cambiar atributo/color
; de una celda o de la pantalla (parpadeo alarma).
; ==============================================================================

VIDEO_PAGINA equ 0x00        ; Única página de video que usa la app

; limpiar_pantalla
; Restablece el modo de video 03h (texto 80x25 color). El BIOS limpia la
; pantalla y reposiciona el cursor en (0,0) como efecto del cambio de modo,
; sin necesidad de int 0x10 ah=0x06 (scroll) para lograr lo mismo.
limpiar_pantalla:
    push ax
    mov ah, 0x00
    mov al, 0x03
    int 0x10
    pop ax
    ret

; set_cursor
; Entrada: DH = fila, DL = columna (ambas 0-based)
; Posiciona el cursor de texto en VIDEO_PAGINA.
set_cursor:
    push ax
    push bx
    mov ah, 0x02
    mov bh, VIDEO_PAGINA
    int 0x10
    pop bx
    pop ax
    ret

; imprimir_en
; Entrada: DH = fila, DL = columna, SI = puntero a string terminado en 0
; Posiciona el cursor y luego imprime el string en modo teletipo
; (int 0x10 ah=0x0E avanza el cursor solo, carácter por carácter).
imprimir_en:
    call set_cursor
.loop:
    lodsb
    or al, al
    jz .fin
    mov ah, 0x0E
    mov bh, VIDEO_PAGINA
    int 0x10
    jmp .loop
.fin:
    ret
