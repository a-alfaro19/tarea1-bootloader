# Compiladores y herramientas
ASM = nasm
QEMU = qemu-system-x86_64

# Archivos de salida
BUILD_DIR = build
LEGACY_BIN = $(BUILD_DIR)/boot_legacy.bin
LEGACY_IMG = $(BUILD_DIR)/disk_legacy.img

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

# Crear imagen de disco virtual de 1.44MB o sector exacto con el MBR
$(LEGACY_IMG): $(LEGACY_BIN)
	dd if=/dev/zero of=$(LEGACY_IMG) bs=512 count=2880
	dd if=$(LEGACY_BIN) of=$(LEGACY_IMG) conv=notrunc bs=512 count=1

# ------------------------------------------------------------------------------
# 2. Reglas de Emulación (QEMU)
# ------------------------------------------------------------------------------

# Ejecutar en Modo Legacy
run-legacy: $(LEGACY_IMG)
	$(QEMU) -drive format=raw,file=$(LEGACY_IMG)

# Ejecutar en Modo UEFI (Requiere firmware OVMF instalado en el sistema)
run-uefi:
	@echo "Asegúrate de tener instalado el paquete de firmware UEFI (ej. ovmf o qemu-ovmf-x86_64)"
	$(QEMU) -bios /usr/share/ovmf/OVMF.fd -net none

# ------------------------------------------------------------------------------
# 3. Limpieza de archivos generados
# ------------------------------------------------------------------------------
clean:
	rm -rf $(BUILD_DIR)
	@echo "Limpieza completada."

.PHONY: all directories run-legacy run-uefi docker-build docker-run docker-all clean
