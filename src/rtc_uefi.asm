; ==============================================================================
; rtc_uefi.asm — Lectura de hora vía RuntimeServices->GetTime (SystemTable+88,
; GetTime en el offset +24 de RuntimeServices). Devuelve valores binarios
; (Hour/Minute/Second en EFI_TIME), a diferencia del BCD del RTC de BIOS.
; Se implementa en la Fase UEFI-2 (ver SPEC_UEFI.md §2).
; ==============================================================================
