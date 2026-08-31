; ==============================================================================
; video_uefi.asm — Helpers de pantalla sobre el protocolo ConOut
; (EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL). Se completa en la Fase UEFI-1 con
; limpiar_pantalla, set_cursor y set_atributo (ver SPEC_UEFI.md §2).
; ==============================================================================

bits 64
default rel

section .text
global imprimir_string

; imprimir_string
; Entrada: RCX = puntero a ConOut (this), RDX = puntero a string UTF-16
;          terminado en 0
; Envuelve ConOut->OutputString (offset +8 del protocolo). Los registros de
; entrada ya coinciden con la firma de OutputString(this, string), así que
; no hace falta reacomodar nada antes de llamar.
imprimir_string:
    call qword [rcx + 8]
    ret
