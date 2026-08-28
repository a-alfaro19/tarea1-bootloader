# Usamos una imagen base ligera de Ubuntu
FROM ubuntu:22.04

# Evitamos que el sistema solicite interacciones durante la instalación de paquetes
ENV DEBIAN_FRONTEND=noninteractive

# Actualizamos los repositorios e instalamos NASM, QEMU, Make y herramientas esenciales
RUN apt-get update && apt-get install -y \
    nasm \
    qemu-system-x86 \
    make \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Definimos el directorio de trabajo dentro del contenedor
WORKDIR /workspace

# Comando por defecto al iniciar el contenedor (abre una terminal bash)
CMD ["/bin/bash"]
