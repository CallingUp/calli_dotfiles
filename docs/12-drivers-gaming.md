# Drivers gaming NVIDIA/Intel

## Hardware

- Intel UHD Graphics Comet Lake, driver `i915` y Mesa.
- NVIDIA GeForce GTX 1650 Mobile/Max-Q, arquitectura Turing.

## Estado validado

```text
NVIDIA kernel module: 610.57.04
nvidia-utils:         610.57.04
lib32-nvidia-utils:   610.57.04
Mesa Intel:           26.2.1
```

Ambos kernels instalados contienen el mismo módulo NVIDIA:

```bash
modinfo -k 7.2.2-1-cachyos -F version nvidia
modinfo -k 6.18.48-1-cachyos-lts -F version nvidia
```

## Comandos de diagnóstico

```bash
lspci -k | rg -i -A5 'vga|3d|display'
nvidia-smi
vulkaninfo --summary
prime-run vulkaninfo --summary
prime-run glxinfo -B
```

Resultados esperados:

- `nvidia-smi` muestra GTX 1650 y memoria.
- Vulkan enumera Intel y NVIDIA.
- Con `prime-run`, NVIDIA aparece primero.
- OpenGL indica `direct rendering: Yes`.

## Paquetes importantes para Proton

```text
nvidia-utils
lib32-nvidia-utils
vulkan-icd-loader
lib32-vulkan-icd-loader
vulkan-intel
lib32-vulkan-intel
```

Las bibliotecas `lib32` son necesarias para juegos o componentes de 32 bits.

## Qué evitar

- Instaladores `.run` de NVIDIA sobre paquetes de Arch.
- Mezclar versiones del módulo y `nvidia-utils`.
- Drivers beta para perseguir FPS sin un problema concreto.
- Copiar parámetros de kernel de otro equipo.

La GTX 1650 es Turing; el módulo abierto de NVIDIA es apropiado para esta generación.

