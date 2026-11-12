# Orca Lite

**Orca Lite** es una versión no oficial de [Dolphin Emulator](https://dolphin-emu.org)
para Android, orientada a teléfonos de gama baja y media-baja.

> Orca Lite **no está afiliado ni respaldado** por el equipo de Dolphin ni por Nintendo.
> Está basado en el código de Dolphin y se distribuye bajo la misma licencia
> **GNU GPL v2 o posterior** (ver `COPYING`). El código fuente completo de esta
> versión está disponible en este repositorio.

## Objetivos

- Ajustes predeterminados pensados para gama baja (rendimiento antes que calidad).
- Perfil "gama baja" aplicable con un toque, y perfiles por juego.
- Menor consumo de memoria en equipos de 3–4 GB de RAM.
- Interfaz simplificada.

Orca Lite requiere un teléfono con **Android de 64 bits (arm64-v8a)**. Las versiones
de 32 bits (ARMv7) no son viables: Dolphin eliminó su recompilador ARMv7 y sin él
la emulación es demasiado lenta.

## Diferencias con Dolphin

| Cambio | Detalle |
|---|---|
| Nombre de la app | Orca Lite |
| ID de aplicación | `io.github.nelsonh612.orcalite` (se instala junto a Dolphin oficial) |
| Compilación | APK arm64 generada por GitHub Actions (`.github/workflows/orca-lite-android.yml`) |

Pendiente antes de cualquier publicación: reemplazar el ícono y los recursos
gráficos de Dolphin por los de Orca Lite.

## Probar una compilación

1. Abrir la pestaña **Actions** del repositorio → *Orca Lite Android APK*.
2. Abrir la última ejecución correcta y descargar el artefacto `orca-lite-debug-arm64`.
3. Descomprimirlo e instalar el `.apk` en el teléfono (permitir "orígenes desconocidos").

Los juegos no se incluyen: cada usuario debe usar copias propias de sus discos.
