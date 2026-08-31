; ==============================================================================
; teclado_uefi.asm — Helpers de teclado sobre el protocolo ConIn
; (EFI_SIMPLE_TEXT_INPUT_PROTOCOL). Se completa en la Fase UEFI-1 con
; variantes de alto nivel (esperar Enter, capturar dígitos, etc.).
; ==============================================================================

bits 64
default rel

section .text
global leer_tecla_no_bloqueante

; leer_tecla_no_bloqueante
; Entrada: RCX = puntero a ConIn (this), RDX = puntero a un EFI_INPUT_KEY
;          (4 bytes: UINT16 ScanCode + CHAR16 UnicodeChar) donde se escribe
;          la tecla leída
; Salida: RAX = EFI_STATUS — 0 (EFI_SUCCESS) si había una tecla disponible
;         (ya queda en [RDX]); distinto de 0 (típicamente EFI_NOT_READY) si
;         no había ninguna. A diferencia del BIOS, ReadKeyStroke ya es no
;         bloqueante por naturaleza — no hace falta una llamada de "peek"
;         separada (ver SPEC_UEFI.md §2).
leer_tecla_no_bloqueante:
    call qword [rcx + 8]
    ret
