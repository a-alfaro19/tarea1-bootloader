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

; imprimir_en_attr
; Entrada: DH = fila, DL = columna, SI = puntero a string terminado en 0,
;          BL = atributo de video (ej. 0x4F = blanco sobre rojo)
; El teletipo de la BIOS (imprimir_en) hereda el atributo ya presente en cada
; celda y no permite elegir color, así que para el aviso parpadeante de la
; alarma se escribe directo en la memoria de video (segmento 0xB800, 2 bytes
; por celda: carácter + atributo). No mueve el cursor de texto del BIOS.
imprimir_en_attr:
    push ax
    push cx
    push di
    push es

    xor ax, ax
    mov al, dh
    mov cx, 80
    mul cx              ; ax = fila*80 (cabe en ax para filas 0-24; mul cx exige
                         ; AX completo, no solo AL, de ahí el xor previo)
    xor ch, ch
    mov cl, dl
    add ax, cx          ; ax = índice de celda (fila*80+columna)
    shl ax, 1           ; ax = offset en bytes (2 bytes por celda)
    mov di, ax

    mov ax, 0xB800
    mov es, ax
.loop:
    lodsb
    or al, al
    jz .fin
    stosb
    mov al, bl
    stosb
    jmp .loop
.fin:
    pop es
    pop di
    pop cx
    pop ax
    ret
