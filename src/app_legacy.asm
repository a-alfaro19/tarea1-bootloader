; ==============================================================================
; Aplicación Dummy en Modo Legacy (Se ejecuta en 0x7E00)
; ==============================================================================

[org 0x7E00]

app_start:
    ; Cargar la dirección del mensaje de la aplicación en SI
    mov si, app_msg

app_print_loop:
    lodsb                ; Cargar byte de [SI] en AL
    or al, al            ; Verificar si es fin de cadena (0)
    jz app_hang          ; Si es cero, terminar bucle

    mov ah, 0x0E         ; Función teletipo de la BIOS
    mov bh, 0x00         ; Página de video 0
    int 0x10             ; Imprimir carácter
    jmp app_print_loop

app_hang:
    cli
    hlt
    jmp app_hang

; --- Datos de la Aplicación ---
app_msg db 0x0D, 0x0A, "=== Hola desde la aplicacion Dummy cargada con exito! ===", 0x0D, 0x0A, 0

; Rellenar el sector de la aplicación para que ocupe exactamente 512 bytes (1 sector)
times 510-($-$$) db 0
