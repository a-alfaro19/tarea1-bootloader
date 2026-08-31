# tarea1-bootloader

## 🛠️ Prerrequisitos del Entorno

Este proyecto está diseñado para ejecutarse en entornos **Linux** (o en **WSL - Windows Subsystem for Linux**), ya que requiere compatibilidad con el kernel de Linux y el servidor gráfico para las ventanas de emulación.

### 1. Instalación de Dependencias

Abre tu terminal de Linux / WSL e instala las herramientas necesarias de compilación, empaquetado y emulación ejecutando el siguiente comando:

```bash
sudo apt update && sudo apt install nasm qemu-system-x86 ovmf make build-essential binutils-mingw-w64-x86-64 mtools
```

Este comando instalará los siguientes componentes clave:

- `nasm`: Ensamblador de x86 utilizado para compilar el código fuente de los bootloaders.

- `qemu-system-x86`: Emulador de hardware para la arquitectura x86/x86_64, indispensable para correr y probar las imágenes de disco.

- `ovmf`: Firmware de Open Virtual Machine Firmware para habilitar el soporte de arranque UEFI en QEMU.

- `make`: Herramienta de automatización para simplificar la compilación mediante el archivo Makefile.

- `build-essential`: Paquete que incluye herramientas de compilación esenciales (como el compilador de C y utilidades como dd).

- `binutils-mingw-w64-x86-64`: Proveedor del enlazador cruzado (x86_64-w64-mingw32-ld) indispensable para generar el formato de archivo PE/COFF requerido por las aplicaciones UEFI.

- `mtools`: Utilidades para manipular sistemas de archivos FAT sin necesidad de permisos de superusuario (sudo), utilizadas en el Makefile para generar la partición EFI.

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

### Carga y Salto hacia la Aplicación

Una vez inicializado el entorno, el MBR se encarga de leer el segundo sector del disco (donde se aloja la aplicación) utilizando las interrupciones de la BIOS y transfiere el control de ejecución:

- **Resguardo de la unidad de origen**: Al arrancar, la BIOS pasa el identificador del disco en el registro dl, el cual se almacena en memoria para su uso posterior.

  ```asm
  mov [boot_drive], dl
  ```

- **Lectura del disco (`int 0x13`)**: Se configura la función `0x02` de la interrupción para leer unicamente un solo sector (`al = 0x01`) desde el sector 2 (`cl = 0x02`), utilizando la unidad guardada y cargando los datos en la dirección de memoria `0x7E00`.

  ```asm
  mov ah, 0x02         ; Función de lectura de sectores
  mov al, 0x01         ; Cantidad de sectores (1)
  mov ch, 0x00         ; Cilindro 0
  mov cl, 0x02         ; Sector 2 (después del MBR)
  mov dh, 0x00         ; Cabezal 0
  mov dl, [boot_drive] ; Unidad de disco
  mov bx, 0x7E00       ; Dirección de destino en RAM
  int 0x13             ; Llamada a la BIOS para leer el disco
  ```

- **Salto de ejecución**: Tras una lectura exitosa, se ejecuta un salto intersegmento para ceder el control del procesador directamente al código de la aplicación cargada en memoria.

  ```asm
  jmp 0x0000:0x7E00
  ```

## UEFI Boot

A diferencia del modo tradicional, **UEFI (Unified Extensible Firmware Interface)** opera en un entorno de 64 bits protegido y utiliza un paradigma basado en **protocolos y llamadas a interfaces orientadas a objetos** a través de la `SystemTable`, eliminando por completo el uso de interrupciones de la BIOS.

Para que el firmware UEFI detecte y ejecute correctamente el cargador de arranque, el proceso requiere cumplir con ciertos estándares de empaquetado y organización:

- **Estructura de Directorios Específica**: El hardware y el firmware no buscan un sector de arranque en el bloque cero (como MBR), sino que montan una partición de sistema EFI (ESP - _EFI System Partition_). Dentro de ella, esperan encontrar obligatoriamente el binario ejecutable en una ruta y nombre predeterminados según la arquitectura:

  ```text
  EFI/BOOT/BOOTX64.EFI
  ```

  Para cumplir esta condición, se especificó en el Makefile la creación de la jerarquía de carpetas necesaria:

  ```Makefile
  $(UEFI_IMAGE):$(UEFI_BIN)
      mkdir -p build/efi/EFI/BOOT
      cp $(UEFI_BIN) build/efi/EFI/BOOT/BOOTX64.EFI
  ```

- **Formato PE/COFF**: El archivo compilado debe respetar la estructura de un ejecutable de Windows/UEFI (formato PE32+) para que el gestor de arranque del firmware pueda cargarlo, leer sus secciones de código e invocar su punto de entrada (`efi_main`). Esto se logra compilando el código como un objeto ELF y dejando que el enlazador del sistema genere automáticamente los encabezados PE/COFF mediante el Makefile:

  ```Makefile
  $(UEFI_BIN): src/boot_uefi.asm
      nasm -f elf64 src/boot_uefi.asm -o build/boot_uefi.o
      x86_64-w64-mingw32-ld -subsystem 10 -entry:efi_main build/boot_uefi.o -o $(UEFI_BIN)
  ```

## Interrupciones y Servicios del BIOS

El bootloader utiliza los servicios de bajo nivel proporcionados por la BIOS a través de interrupciones de software para interactuar con el hardware.

| Interrupción | Registro `AH` | Registro `AL`               | Registros Extra                                                                                                                                      | Descripción / Propósito                                                                                                                                           |
| :----------- | :------------ | :-------------------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------- | :---------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `int 0x10`   | `0x0E`        | Carácter ASCII              | **`BH`** = Número de página de video                                                                                                                 | **Modo Teletipo (TTY):** Imprime en pantalla el carácter almacenado en `AL`, avanza el cursor automáticamente y maneja saltos de línea en la página de video `0`. |
| `int 0x10`   | `0x02`        | —                            | **`BH`** = Página de video<br>**`DH`** = Fila<br>**`DL`** = Columna                                                                                   | **Posicionar cursor:** ubica el cursor de texto en la fila/columna indicadas antes de imprimir con modo teletipo.                                                 |
| `int 0x10`   | `0x00`        | `0x03`                       | —                                                                                                                                                       | **Set video mode:** reinicia el modo de video 03h (texto 80x25 color). Efecto colateral: limpia la pantalla y regresa el cursor a (0,0).                          |
| `int 0x13`   | `0x02`        | Cantidad de sectores a leer | **`CH`** = Cilindro<br>**`CL`** = Sector de inicio<br>**`DH`** = Cabezal / Head<br>**`DL`** = Unidad de disco<br>**`BX`** = Offset de destino en RAM | **Lectura de Disco:** Lee sectores físicos desde el almacenamiento secundario y los carga en la dirección de memoria especificada por `ES:BX`.                    |
| `int 0x16`   | `0x00`        | —                            | Salida: **`AH`** = scancode, **`AL`** = ASCII                                                                                                          | **Lectura de teclado (bloqueante):** espera hasta que el usuario presione una tecla.                                                                                |
| `int 0x1A`   | `0x02`        | —                            | Salida: **`CH`** = hora, **`CL`** = minutos, **`DH`** = segundos, todos en **BCD** (no binario)                                                       | **Leer hora del RTC:** consulta el reloj de tiempo real del CMOS a través de la BIOS.                                                                              |

> ⚠️ **RTC y zona horaria en QEMU:** el reloj CMOS que expone `int 0x1A` guarda la hora tal como está configurada en el hardware — no sabe de zonas horarias. QEMU por defecto arranca ese reloj virtual en **UTC** (`-rtc base=utc`), así que la hora que muestra la app puede verse desfasada respecto a la hora local del que la prueba (en Costa Rica, UTC-6). El Makefile ya pasa `-rtc base=localtime` en `run-legacy` para que coincida con la hora del sistema anfitrión durante las pruebas. En hardware real esto no debería pasar: el CMOS normalmente está configurado en hora local por el usuario/BIOS, pero es bueno verificarlo antes de la defensa.

## Servicios de la SystemTable (UEFI)

En UEFI, la interacción con el hardware se realiza llamando a métodos dentro de estructuras de protocolos obtenidas desde la SystemTable (pasada en rdx), utilizando la convención de llamadas x64 (argumento this en rcx).

| Protocolo / Puntero | Desplazamiento (`SystemTable`) | Método / Función | Desplazamiento (en el Protocolo) | Descripción / Propósito                                                |
| :------------------ | :----------------------------- | :--------------- | :------------------------------- | :--------------------------------------------------------------------- |
| `ConOut`            | `+64` (`0x40`)                 | `OutputString`   | `+8` (`0x08`)                    | Imprime una cadena de texto en formato UTF-16 en la consola de salida. |
| `ConIn`             | `+48` (`0x30`)                 | `ReadKeyStroke`  | `+8` (`0x08`)                    | Lee un evento de teclado desde la consola de entrada.                  |

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
