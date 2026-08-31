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

    ; Guardar el número de unidad (drive number) que la BIOS pasa en DL
    mov [boot_drive], dl

    ; 3. Cargar la dirección del mensaje de bienvenida en el registro SI
    mov si, welcome_msg

print_loop:
    lodsb                   ; Carga el byte en [SI] hacia AL e incrementa SI automáticamente
    or al, al               ; Comprueba si el byte es cero (fin de cadena)
    jz load_application     ; Si es cero, termina el bucle de impresión

    ; 4. Configurar la interrupción de video del BIOS (int 10h) para modo teletipo
    mov ah, 0x0E       ; Función 0x0E: Escribir carácter en modo teletipo
    mov bh, 0x00       ; Número de página de video (0)
    int 0x10           ; Llamada a la BIOS para imprimir el carácter en AL
    jmp print_loop     ; Repetir para el siguiente carácter

load_application:
    ; ==========================================================================
    ; Carga de la Aplicación desde el Disco usando int 0x13
    ; ==========================================================================
    xor ax, ax
    mov es, ax           ; Asegurar ES = 0 para la dirección de destino

    mov ah, 0x02         ; Función 0x02: Leer sectores del disco
    mov al, 0x03         ; Número de sectores a leer: 3 (1536 bytes). La app
                          ; ya no cabe en 1 solo sector (reloj+cronometro+alarma);
                          ; debe coincidir con el tamaño reservado al final de
                          ; app_legacy.asm y con el "count" del dd en el Makefile.
    mov ch, 0x00         ; Cilindro 0
    mov cl, 0x02         ; Sector 2 (el sector 1 es nuestro MBR)
    mov dh, 0x00         ; Cabezal (Head) 0
    mov dl, [boot_drive] ; Unidad de disco guardada al inicio
    mov bx, 0x7E00       ; Dirección de destino en memoria (justo después del MBR)
    
    int 0x13             ; Interrupción de la BIOS para leer el disco
    jc disk_error        ; Si hay error, el carry flag (CF) se activa

    ; ==========================================================================
    ; Salto de Ejecución hacia la Aplicación Cargada
    ; ==========================================================================
    jmp 0x0000:0x7E00    ; Ceder el control saltando a la dirección de la app

disk_error:
    ; Manejo básico de error de lectura
    mov si, error_msg
print_error:
    lodsb
    or al, al
    jz hang
    mov ah, 0x0E
    mov bh, 0x00
    int 0x10
    jmp print_error

hang:
    cli                ; Limpiar interrupciones
    hlt                ; Detener la CPU hasta la siguiente interrupción
    jmp hang           ; Bucle de seguridad infinito por si acaso

; --- Sección de Datos ---
welcome_msg db "=== Bootloader Legacy Iniciado Correctamente ===", 0x0D, 0x0A, 0
error_msg   db "Error: No se pudo leer la aplicacion del disco.", 0x0D, 0x0A, 0
boot_drive  db 0         ; Variable para almacenar el ID de la unidad de disco

; ==============================================================================
; Restricciones del MBR
; ==============================================================================

; Rellenar con ceros (0) todo el espacio restante hasta completar exactamente 510 bytes
times 510-($-$$) db 0

; Firma de arranque obligatoria de 2 bytes exigida por la BIOS (0xAA55 en formato little-endian)
dw 0xAA55
