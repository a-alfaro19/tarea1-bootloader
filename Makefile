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

$(LEGACY_BIN): src/boot_legacy.asm
	$(ASM) -f bin src/boot_legacy.asm -o $(LEGACY_BIN)

$(LEGACY_APP): src/app_legacy.asm
	$(ASM) -f bin src/app_legacy.asm -o $(LEGACY_APP)

# Crear imagen de disco virtual concatenando el MBR (sector 0) y la App (sector 1)
$(LEGACY_IMG): $(LEGACY_BIN) $(LEGACY_APP)
	dd if=/dev/zero of=$(LEGACY_IMG) bs=512 count=2880
	dd if=$(LEGACY_BIN) of=$(LEGACY_IMG) conv=notrunc bs=512 count=1 seek=0
	dd if=$(LEGACY_APP) of=$(LEGACY_IMG) conv=notrunc bs=512 count=1 seek=1

# ------------------------------------------------------------------------------
# 2. Modo UEFI (Ejecutable PE32+ y Partición FAT32 ESP)
# ------------------------------------------------------------------------------

# Compilar UEFI usando formato ELF y enlazador (ld)
$(UEFI_BIN): src/boot_uefi.asm
	nasm -f elf64 src/boot_uefi.asm -o build/boot_uefi.o
	x86_64-w64-mingw32-ld -subsystem 10 -entry:efi_main build/boot_uefi.o -o $(UEFI_BIN)

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
run-legacy: $(LEGACY_IMG)
	$(QEMU) -drive format=raw,file=$(LEGACY_IMG)

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
