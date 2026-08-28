; ==============================================================================
; Cargador de Arranque en Modo Legacy (MBR - 512 bytes)
; ==============================================================================

[org 0x7C00]           ; 1. Punto de origen estándar donde la BIOS carga el MBR

start:
    ; 2. Configuración inicial de segmentos y pila por seguridad en modo real
    cli                ; Deshabilitar interrupciones temporalmente
    xor ax, ax         ; AX = 0
    mov ds, ax         ; Data Segment = 0
    mov es, ax         ; Extra Segment = 0
    mov ss, ax         ; Stack Segment = 0
    mov sp, 0x7C00     ; La pila crece hacia abajo desde la dirección de inicio
    sti                ; Rehabilitar interrupciones

    ; 3. Cargar la dirección del mensaje de bienvenida en el registro SI
    mov si, welcome_msg

print_loop:
    lodsb              ; Carga el byte en [SI] hacia AL e incrementa SI automáticamente
    or al, al          ; Comprueba si el byte es cero (fin de cadena)
    jz hang            ; Si es cero, termina el bucle de impresión

    ; 4. Configurar la interrupción de video del BIOS (int 10h) para modo teletipo
    mov ah, 0x0E       ; Función 0x0E: Escribir carácter en modo teletipo
    mov bh, 0x00       ; Número de página de video (0)
    int 0x10           ; Llamada a la BIOS para imprimir el carácter en AL
    jmp print_loop     ; Repetir para el siguiente carácter

hang:
    cli                ; Limpiar interrupciones
    hlt                ; Detener la CPU hasta la siguiente interrupción
    jmp hang           ; Bucle de seguridad infinito por si acaso

; --- Sección de Datos ---
welcome_msg db "=== Bootloader Legacy Iniciado Correctamente ===", 0x0D, 0x0A, 0

; ==============================================================================
; Restricciones del MBR
; ==============================================================================

; Rellenar con ceros (0) todo el espacio restante hasta completar exactamente 510 bytes
times 510-($-$$) db 0

; Firma de arranque obligatoria de 2 bytes exigida por la BIOS (0xAA55 en formato little-endian)
dw 0xAA55
