; ==============================================================================
; Esqueleto UEFI - x86_64
; ==============================================================================

bits 64              ; Configurar el ensamblador para trabajar en modo de 64 bits (x86_64)
default rel          ; Habilitar el direccionamiento relativo a RIP por defecto para variables

section .text        
global efi_main      

efi_main:
    ; --- Prólogo de la función ---
    push rbp         ; Guardar el puntero base anterior en la pila
    mov rbp, rsp     ; Establecer el nuevo marco de pila (stack frame)
    sub rsp, 32      ; Reservar 32 bytes de "shadow space" obligatorio en la convención x64 de Windows/UEFI

    ; --- Guardar parámetros de UEFI ---
    ; RCX contiene el ImageHandle, y RDX contiene el puntero a la SystemTable.
    mov r12, rdx     ; Guardar el puntero global 'SystemTable' en el registro r12

    ; ==========================================================================
    ; 1. Impresión del mensaje de bienvenida (Uso del protocolo ConOut)
    ; ==========================================================================
    mov rax, [r12 + 64]      ; SystemTable + 64 apunta a 'ConOut' (Consola de Salida de Texto)
    mov rcx, rax             ; Primer argumento: puntero al objeto ConOut (el 'this' de la interfaz)
    lea rdx, [rel hello_msg] ; Segundo argumento: carga la dirección relativa de la cadena UTF-16
    call qword [rax + 8]     ; Llamar a la función 'OutputString', ubicada en el desplazamiento 8 de ConOut

    ; ==========================================================================
    ; 2. Bucle de espera de teclado (Uso del protocolo ConIn)
    ; ==========================================================================
    mov rax, [r12 + 48]      ; SystemTable + 48 apunta a 'ConIn' (Consola de Entrada de Texto)

wait_key:
    mov rcx, rax             ; Primer argumento: puntero al objeto ConIn ('this')
    lea rdx, [rsp]           ; Segundo argumento: un búfer temporal en la pila para guardar la tecla leída
    call qword [rax + 8]     ; Llamar a la función 'ReadKeyStroke' (desplazamiento 8 de ConIn)
    
    cmp rax, 0               ; Comparar el resultado devuelto en RAX con 0 (EFI_SUCCESS)
    jne wait_key             ; Si no es cero (significa que no hay tecla o falló), repite el bucle

    ; ==========================================================================
    ; 3. Salida limpia y retorno al firmware UEFI
    ; ==========================================================================
    xor rax, rax     ; Poner RAX en 0, lo que representa EFI_SUCCESS (éxito)
    mov rsp, rbp     ; Restaurar el puntero de la pila
    pop rbp          ; Recuperar el puntero base anterior
    ret              ; Retornar el control de ejecución al firmware UEFI

; ==============================================================================
; Sección de Datos Estáticos
; ==============================================================================
section .data
hello_msg:
    dw __utf16__("¡Hola Mundo desde UEFI con ensamblador!"), 13, 10 
    dw __utf16__("Presiona cualquier tecla para salir..."), 13, 10, 0   
