; ==============================================================================
; alarma_uefi.asm — Configuración HH:MM, comparación contra GetTime(),
; notificación (SetAttribute para parpadeo/color + intento de beep por
; puertos I/O 0x61/0x42/0x43), cancelación. Se implementa en la Fase UEFI-4
; (ver SPEC_UEFI.md §2 — el beep es el mayor riesgo de portabilidad de todo
; el puerto, hay que probarlo en hardware real cuanto antes).
; ==============================================================================
