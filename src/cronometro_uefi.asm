; ==============================================================================
; cronometro_uefi.asm — Cronómetro con estados detenido/corriendo/pausado,
; usando GetTime() como fuente de tiempo (no hay tick counter equivalente en
; UEFI). Mismo patrón que src/cronometro.inc (Legacy). Se implementa en la
; Fase UEFI-3 (ver SPEC_UEFI.md §2).
; ==============================================================================
