# Plan — App Reloj/Cronómetro con Alarma (Legacy)

> No se auto-carga. Abrir este archivo al empezar una sesión nueva para saber en qué quedó el desarrollo antes de asumir nada o repetir trabajo.
>
> Diseño de referencia: `SPEC.md` (raíz del repo) — **temporal**, se borra una vez que todo lo de este plan quede commiteado.

## Estado actual

- **Fase:** 0 completada (scaffolding). Siguiente: Fase 1 (pantalla base + confirmación inicial).
- **Hecho:** boot loader legacy (`boot_legacy.asm`) completo y funcional. `src/video.inc`, `teclado.inc`, `rtc.inc`, `cronometro.inc`, `alarma.inc` creados (vacíos, solo cabecera) e incluidos desde `app_legacy.asm` vía `%include`; Makefile actualizado (`-i src/` para que nasm resuelva los includes, y los `.inc` como prerequisitos de `$(LEGACY_APP)`). Verificado: build sin errores y binario `app_legacy.bin` byte-idéntico al de antes de esta fase (los includes vacíos no cambiaron comportamiento). `src/app_legacy.asm` sigue mostrando el mensaje *dummy* — aún no se integran los módulos.
- **Pendiente de verificar:** no hay `qemu-system-x86_64` instalado en el WSL usado para compilar — la Fase 0 se validó por build + comparación de hash del binario, no visualmente en QEMU. Antes de dar por buena cualquier fase que cambie comportamiento visible (Fase 1 en adelante), hace falta correr `make run-legacy` de verdad en un entorno con QEMU.
- **Falta:** todo lo funcional de reloj/cronómetro/alarma (fases 1–5 abajo).
- **Branches:** `development` estaba desactualizada (solo el commit inicial, sin el trabajo de bootloader) — se sincronizó por fast-forward con `main` y se pusheó (2026-08-31). Este trabajo vive en `feature/app-scaffolding-modulos`, creada desde `development`.
- **Working tree:** cambios de Fase 0 sin commitear todavía (`src/*.inc`, `src/app_legacy.asm`, `Makefile`), más `SPEC.md` (temporal) y este `docs/plan.md`.

## Grafo de dependencias

```
Fase 0 (scaffolding módulos)
  └─▶ Fase 1 (video + teclado + confirmación inicial)
        └─▶ Fase 2 (rtc.inc + modo Reloj)
              └─▶ Fase 3 (cronometro.inc + cambio de modo M)
                    └─▶ Fase 4 (alarma.inc — reusa rtc.inc de Fase 2 y teclado.inc de Fase 1)
                          └─▶ Fase 5 (salida Esc, ajuste a 512 bytes, checklist, hardware real)
```

Cada fase es una **rebanada vertical completa**: se prueba en QEMU de punta a punta (bootea, se ve, se interactúa) antes de pasar a la siguiente. No se escriben todos los `.inc` en paralelo sin integrar.

## Checkpoint entre fases

Después de cada fase: `make clean && make && make run-legacy`, verificar los criterios de aceptación de esa fase en QEMU, hacer commit, **y solo entonces** empezar la siguiente fase. Si algo no compila o no bootea, no se avanza.

---

## Fase 0 — Scaffolding de módulos

**Objetivo:** dejar la estructura de archivos lista sin romper el boot actual.

- [x] Crear `src/video.inc`, `src/teclado.inc`, `src/rtc.inc`, `src/cronometro.inc`, `src/alarma.inc` vacíos (solo el comentario de cabecera descrito en `SPEC.md` §3).
- [x] En `app_legacy.asm`, agregar los `%include` de los 5 archivos (aún sin uso), manteniendo el mensaje *dummy* actual como placeholder.
- [x] Actualizar la regla `$(LEGACY_APP)` del Makefile para listar los `.inc` como prerequisitos, de forma que `make` reensamble cuando cambien. También se agregó `-i src/` a la invocación de `nasm`: `%include "video.inc"` se resuelve relativo al cwd de `make` (raíz del repo), no al directorio del archivo fuente, así que sin `-i src/` nasm no encontraba los `.inc`:
  ```makefile
  $(LEGACY_APP): src/app_legacy.asm src/video.inc src/teclado.inc src/rtc.inc src/cronometro.inc src/alarma.inc
      $(ASM) -f bin -i src/ src/app_legacy.asm -o $(LEGACY_APP)
  ```

**Criterio de aceptación:** `make` compila sin errores de `nasm` por los `%include` vacíos — **verificado** (`make clean && make` limpio, y `app_legacy.bin` resultó byte-idéntico al binario previo a esta fase, mismo sha256). **No verificado en QEMU** (no disponible en el entorno de compilación usado) — pendiente correr `make run-legacy` para confirmar el boot visual antes de avanzar a Fase 1.

---

## Fase 1 — Pantalla base + confirmación inicial

**Objetivo:** el usuario ve una pantalla de bienvenida y debe presionar Enter para continuar.

- [ ] `video.inc`: `limpiar_pantalla`, `set_cursor(fila, col)` (`int 0x10, ah=0x02`), `imprimir_en(fila, col, ptr_string)`.
- [ ] `teclado.inc`: `leer_tecla_bloqueante` (`int 0x16, ah=0x00`) — devuelve scancode/ASCII.
- [ ] `app_legacy.asm`: pantalla de confirmación — limpia pantalla, imprime mensaje de bienvenida centrado, espera Enter (`leer_tecla_bloqueante` en loop hasta ASCII `0x0D`).

**Criterio de aceptación:** en QEMU, la app limpia pantalla, muestra bienvenida, y **no avanza** hasta presionar Enter. Cualquier otra tecla no hace nada todavía.

---

## Fase 2 — Modo Reloj (RTC)

**Objetivo:** tras confirmar, se muestra la hora del sistema actualizándose cada segundo.

- [ ] `rtc.inc`: `leer_hora_rtc` (`int 0x1A, ah=0x02` → `CH`=hora, `CL`=min, `DH`=seg en BCD), rutina BCD→ASCII, `formatear_hora(buffer, h, m, s)` → `"HH:MM:SS"`.
- [ ] `app_legacy.asm`: loop principal en modo Reloj — lee hora cada iteración, **redibuja solo si el segundo cambió** (evitar parpadeo), usando `set_cursor` + `imprimir_en` de Fase 1.

**Criterio de aceptación:** la hora en pantalla coincide con la hora del RTC de QEMU (`info rtc` en el monitor de QEMU, o comparar contra la hora real si QEMU usa `-rtc base=localtime`) y avanza un segundo por segundo sin parpadeo perceptible ni texto duplicado.

---

## Fase 3 — Modo Cronómetro + cambio de modo

**Objetivo:** tecla `M` alterna Reloj/Cronómetro; el cronómetro cuenta independiente del RTC y soporta start/pause/resume/reset.

- [ ] `cronometro.inc`: `leer_tick_counter` (`int 0x1A, ah=0x00` → `CX:DX`, ~18.2 ticks/seg), estado (`detenido`/`corriendo`/`pausado`), `iniciar_pausar_reanudar`, `reiniciar`, conversión de ticks acumulados → `HH:MM:SS`.
- [ ] `app_legacy.asm`: despacho de teclas en el loop principal — `M` alterna modo (sin perder estado de cronómetro/alarma), `S` inicia/pausa/reanuda, `R` reinicia. Cambiar `leer_tecla_bloqueante` de Fase 1 a una variante **no bloqueante** (`int 0x16, ah=0x01` para *peek*, `ah=0x00` para consumir) — el loop ya no puede bloquearse esperando tecla porque tiene que seguir refrescando reloj/cronómetro.

**Criterio de aceptación:** cronómetro cuenta correctamente al iniciar, se detiene al pausar, continúa desde donde iba al reanudar, vuelve a cero al reiniciar; cambiar a modo Reloj con `M` y volver a Cronómetro preserva el conteo exacto (no se resetea ni se pierde tiempo).

---

## Fase 4 — Alarma

**Objetivo:** configurar HH:MM, comparar contra RTC, notificar visual + sonido, permitir cancelar.

- [ ] `teclado.inc`: extender con captura de dígitos (`0-9`, `Enter` confirma, `Esc` cancela) para un campo `HH:MM`.
- [ ] `alarma.inc`: estado (`ninguna`/`configurada`/`disparada`), `comparar_con_rtc` (reusa `leer_hora_rtc` de Fase 2, sin duplicar lógica BCD), `notificar` (parpadeo/cambio de atributo de pantalla vía `video.inc` + beep por I/O directo a puertos `0x61`/`0x42`/`0x43`), `cancelar_alarma`.
- [ ] `app_legacy.asm`: tecla `A` entra a captura de HH:MM (usa el campo de `teclado.inc`), `C` cancela alarma activa; el loop principal llama `comparar_con_rtc` cada vez que refresca la hora.

**Criterio de aceptación:** se configura una alarma con `A`, al llegar la hora configurada se dispara parpadeo + beep simultáneos, `C` cancela tanto antes como después de que se dispare, y el reloj/cronómetro siguen funcionando con la alarma activa en paralelo.

---

## Fase 5 — Salida, ajuste de tamaño y verificación final

- [ ] Tecla `Esc` finaliza el programa desde cualquier pantalla (excepto durante captura de HH:MM, donde cancela la captura — ya cubierto en Fase 4) — reusa el patrón `cli`/`hlt`/`jmp $` del dummy actual.
- [ ] Revisar que no quede código de debug (prints de diagnóstico, saltos comentados).
- [ ] Verificar tamaño final del binario: si `app_legacy.asm` excede 512 bytes, **no** meter un linker — coordinar cambio en `boot_legacy.asm` para leer 2+ sectores (cambiar `al` en la lectura de disco) y documentarlo.
- [ ] Correr el checklist manual completo de `SPEC.md` §6 en QEMU.
- [ ] Repetir el mismo checklist en **hardware real** antes del 07/09/2026 23:59 (requisito estricto de la tarea).
- [ ] Borrar `SPEC.md` una vez que todas las fases de este plan estén commiteadas (es temporal, según lo acordado).

**Criterio de aceptación:** los 6 puntos del checklist de `SPEC.md` pasan en QEMU y en hardware real; el binario sigue cargando correctamente desde `boot_legacy.asm` sin cambios no documentados.
