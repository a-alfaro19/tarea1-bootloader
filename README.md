# tarea1-bootloader

## 🛠️ Prerrequisitos del Entorno

Este proyecto está diseñado para ejecutarse en entornos **Linux** (o en **WSL - Windows Subsystem for Linux**), ya que requiere compatibilidad con el kernel de Linux y el servidor gráfico para las ventanas de emulación.

### 1. Instalación de Dependencias

Abre tu terminal de Linux / WSL e instala las herramientas necesarias de compilación, empaquetado y emulación ejecutando el siguiente comando:

```bash
sudo apt update && sudo apt install nasm qemu-system-x86 ovmf make build-essential
```

Este comando instalará los siguientes componentes clave:

- `nasm`: Ensamblador de x86 utilizado para compilar el código fuente de los bootloaders.

- `qemu-system-x86`: Emulador de hardware para la arquitectura x86/x86_64, indispensable para correr y probar las imágenes de disco.

- `ovmf`: Firmware de Open Virtual Machine Firmware para habilitar el soporte de arranque UEFI en QEMU.

- `make`: Herramienta de automatización para simplificar la compilación mediante el archivo Makefile.

- `build-essentia`l: Paquete que incluye herramientas de compilación esenciales (como el compilador de C y utilidades como dd).

## Instrucciones de Ejecución (Makefile)

El proyecto cuenta con un `Makefile` automatizado para compilar el código fuente y levantar las pruebas en QEMU.

### Pasos básicos:

#### 1. Compilar el proyecto:

Genera los binarios y la imagen de disco virtual ejecutando:

```bash
make
```

#### 2. Ejecutar en Modo Legacy (MBR):

Para probar el bootloader tradicional de 16 bits en QEMU:

```bash
make run-legacy
```

#### 3. Ejecutar en Modo UEFI:

Para levantar el entorno de pruebas moderno utilizando el firmware OVMF:

```bash
make run-uefi
```

#### 4. Limpiar archivos generados:

Si deseas borrar los binarios temporales y la carpeta build/ para reiniciar la compilación:

```bash
make clean
```
