# Compiladores y herramientas
ASM = nasm
QEMU = qemu-system-x86_64

# Archivos de salida
BUILD_DIR = build
LEGACY_BIN = $(BUILD_DIR)/boot_legacy.bin
LEGACY_APP = $(BUILD_DIR)/app_legacy.bin
LEGACY_IMG = $(BUILD_DIR)/disk_legacy.img
UEFI_BIN = $(BUILD_DIR)/BOOTX64.EFI
UEFI_IMG = $(BUILD_DIR)/disk_uefi.img
UEFI_SRCS = src/boot_uefi.asm src/video_uefi.asm src/teclado_uefi.asm src/rtc_uefi.asm src/cronometro_uefi.asm src/alarma_uefi.asm
UEFI_OBJS = $(UEFI_SRCS:src/%.asm=$(BUILD_DIR)/%.o)

# ==============================================================================
# Reglas Principales
# ==============================================================================

all: directories $(LEGACY_BIN) $(LEGACY_IMG)

# Crear directorio de compilación si no existe
directories:
	mkdir -p $(BUILD_DIR)

# ------------------------------------------------------------------------------
# 1. Modo Legacy (MBR - 512 bytes)
# ------------------------------------------------------------------------------

$(LEGACY_BIN): src/boot_legacy.asm | directories
	$(ASM) -f bin src/boot_legacy.asm -o $(LEGACY_BIN)

$(LEGACY_APP): src/app_legacy.asm src/video.inc src/teclado.inc src/rtc.inc src/cronometro.inc src/alarma.inc | directories
	$(ASM) -f bin -i src/ src/app_legacy.asm -o $(LEGACY_APP)

# Crear imagen de disco virtual concatenando el MBR (sector 0) y la App (sector 1)
$(LEGACY_IMG): $(LEGACY_BIN) $(LEGACY_APP)
	dd if=/dev/zero of=$(LEGACY_IMG) bs=512 count=2880
	dd if=$(LEGACY_BIN) of=$(LEGACY_IMG) conv=notrunc bs=512 count=1 seek=0
	dd if=$(LEGACY_APP) of=$(LEGACY_IMG) conv=notrunc bs=512 count=3 seek=1

# ------------------------------------------------------------------------------
# 2. Modo UEFI (Ejecutable PE32+ y Partición FAT32 ESP)
# ------------------------------------------------------------------------------

# Compilar cada módulo UEFI a objeto ELF64 por separado (regla patrón)
$(BUILD_DIR)/%.o: src/%.asm | directories
	nasm -f elf64 $< -o $@

# Enlazar todos los objetos UEFI en un único ejecutable PE32+
# --entry=efi_main (no "-entry:efi_main"): GNU ld no entiende la sintaxis de
# dos puntos de MSVC link.exe. Con "-entry:efi_main" el parser de opciones
# cortas de ld lo lee como "-e" + argumento "ntry:efi_main", así que buscaba
# un símbolo de entrada llamado literalmente "ntry:efi_main" y caía a un
# punto de entrada por defecto en vez de efi_main (bug preexistente, nunca
# se notó porque en el binario de un solo módulo el entry point por defecto
# coincidía por casualidad con el inicio real de efi_main).
$(UEFI_BIN): $(UEFI_OBJS) | directories
	x86_64-w64-mingw32-ld -subsystem 10 --entry=efi_main $(UEFI_OBJS) -o $(UEFI_BIN)

# Crear imagen de disco FAT32 (ESP) y empaquetar el binario en la estructura requerida
$(UEFI_IMG): $(UEFI_BIN)
	dd if=/dev/zero of=$(UEFI_IMG) bs=1M count=64
	mkfs.vfat -F 32 $(UEFI_IMG)
	mmd -i $(UEFI_IMG) ::/EFI
	mmd -i $(UEFI_IMG) ::/EFI/BOOT
	mcopy -i $(UEFI_IMG) $(UEFI_BIN) ::/EFI/BOOT/BOOTX64.EFI

# ------------------------------------------------------------------------------
# 2. Reglas de Emulación (QEMU)
# ------------------------------------------------------------------------------

# Ejecutar en Modo Legacy
# -rtc base=localtime: por defecto QEMU pone el RTC virtual en UTC, no en la
# hora local del host, lo que hace parecer incorrecta la hora que lee la app.
run-legacy: $(LEGACY_IMG)
	$(QEMU) -drive format=raw,file=$(LEGACY_IMG) -rtc base=localtime

# Ejecutar en Modo UEFI (Requiere firmware OVMF instalado en el sistema)
run-uefi: $(UEFI_IMG)
	$(QEMU) -bios /usr/share/ovmf/OVMF.fd \
	        -drive format=raw,file=$(UEFI_IMG) \
	        -net none

# ------------------------------------------------------------------------------
# 3. Limpieza de archivos generados
# ------------------------------------------------------------------------------
clean:
	rm -rf $(BUILD_DIR)
	@echo "Limpieza completada."

.PHONY: all directories run-legacy run-uefi docker-build docker-run docker-all clean
