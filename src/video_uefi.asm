; ==============================================================================
; video_uefi.asm — Helpers de pantalla sobre el protocolo ConOut
; (EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL). Se completa en la Fase UEFI-2 con
; set_atributo (parpadeo/color de la alarma, ver SPEC_UEFI.md §2).
;
; Convención de pila para las rutinas de una sola llamada (imprimir_string,
; limpiar_pantalla, set_cursor): a estas se entra siempre justo después de un
; "call" (RSP % 16 == 8), pero la convención x64 exige RSP % 16 == 0 y al
; menos 32 bytes de "shadow space" reservados en el punto donde ESTA rutina
; hace su propia llamada al protocolo EFI. Por eso cada una reserva
; "sub rsp, 40" (32 de shadow space + 8 para volver a alinear a 16) antes de
; llamar, y lo libera antes de retornar. No basta con heredar la reserva del
; llamador: cada nivel de "call" adicional desalinea la pila en 8 bytes.
; ==============================================================================

bits 64
default rel

section .text
global imprimir_string
global limpiar_pantalla
global set_cursor
global imprimir_en

; imprimir_string
; Entrada: RCX = puntero a ConOut (this), RDX = puntero a string UTF-16
;          terminado en 0
; Envuelve ConOut->OutputString (offset +8 del protocolo). Los registros de
; entrada ya coinciden con la firma de OutputString(this, string).
imprimir_string:
    sub rsp, 40
    call qword [rcx + 8]
    add rsp, 40
    ret

; limpiar_pantalla
; Entrada: RCX = puntero a ConOut (this)
; Envuelve ConOut->ClearScreen (offset +48). Limpia la pantalla y reposiciona
; el cursor en (0,0) como efecto propio del protocolo.
limpiar_pantalla:
    sub rsp, 40
    call qword [rcx + 48]
    add rsp, 40
    ret

; set_cursor
; Entrada: RCX = ConOut (this), RDX = columna (UINTN), R8 = fila (UINTN)
; Envuelve ConOut->SetCursorPosition (offset +56).
set_cursor:
    sub rsp, 40
    call qword [rcx + 56]
    add rsp, 40
    ret

; imprimir_en
; Entrada: RCX = ConOut (this), RDX = columna, R8 = fila,
;          R9 = puntero a string UTF-16 terminado en 0
; Posiciona el cursor y luego imprime el string. A diferencia de las rutinas
; de arriba, hace dos llamadas (a set_cursor y a imprimir_string), así que
; necesita conservar ConOut y el puntero al string en registros non-volatile
; (RBX, R15) a través de la primera llamada.
imprimir_en:
    push rbp
    mov rbp, rsp
    push rbx
    push r15
    sub rsp, 32          ; shadow space para nuestras propias llamadas

    mov rbx, rcx          ; conservar ConOut
    mov r15, r9             ; conservar el puntero al string

    call set_cursor        ; RCX/RDX/R8 ya traen (this, columna, fila)

    mov rcx, rbx
    mov rdx, r15
    call imprimir_string

    add rsp, 32
    pop r15
    pop rbx
    pop rbp
    ret
