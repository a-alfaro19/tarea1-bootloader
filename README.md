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

- `build-essential`: Paquete que incluye herramientas de compilación esenciales (como el compilador de C y utilidades como dd).

## Legacy Mode Boot

Para que el BIOS reconozca y ejecute correctamente el cargador de arranque en modo tradicional (MBR), la estructura del binario debe cumplir estrictamente con dos reglas físicas:

- **Relleno de tamaño exacto (512 bytes)**: El sector de arranque MBR mide obligatoriamente 512 bytes. Se utiliza la directiva de relleno para completar con ceros el espacio restante que no ocupe nuestro código.

```asm
times 510-($-$$) db 0
```

- **Firma de arranque (0xAA55)**: Los últimos 2 bytes del sector deben contener la firma mágica (0xAA55). Sin este sello, el BIOS descarta el disco por considerarlo no arrancable.

```asm
dw 0xAA55
```

## Interrupciones y Servicios del BIOS

El bootloader utiliza los servicios de bajo nivel proporcionados por la BIOS a través de interrupciones de software para interactuar con el hardware.

| Interrupción | Registro `AH` | Registro `BH` | Registro `AL`  | Descripción / Propósito                                                                                                                                           |
| :----------- | :------------ | :------------ | :------------- | :---------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `int 0x10`   | `0x0E`        | `0x00`        | Carácter ASCII | **Modo Teletipo (TTY):** Imprime en pantalla el carácter almacenado en `AL`, avanza el cursor automáticamente y maneja saltos de línea en la página de video `0`. |

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
