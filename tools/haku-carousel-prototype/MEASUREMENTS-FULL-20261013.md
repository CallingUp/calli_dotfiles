# Comparación del carrusel completo — 2026-10-13

Medianas de tres rondas por interfaz, alternando QML/Rust y Rust/QML.
Galería local real completa; 40 pasos hacia delante cada 250 ms por ronda.
No se aplican fondos ni se envían archivos a la Papelera. Modo Rust conservado.

Se cuenta el proceso compartido de la barra Quickshell, el frontend Rust cuando
existe y sus descendientes vivos. RAM = PSS residente, no RSS duplicada.
CPU = porcentaje de un núcleo lógico, no porcentaje de toda la laptop.

| Estado | QML RAM MiB | Rust RAM MiB | QML CPU % | Rust CPU % |
|---|---:|---:|---:|---:|
| Base cerrado | 71.63 | 72.23 | 0.96 | 0.67 |
| Abierto quieto | 82.77 | 105.14 | 1.01 | 1.25 |
| Navegación | 83.31 | 107.49 | 17.22 | 56.11 |
| Quieto después de navegar | 82.87 | 107.53 | 1.33 | 1.33 |
| Cerrado después de prueba | 72.61 | 71.68 | 1.00 | 0.98 |

La swap proporcional ronda 93 MiB en ambos conjuntos (principalmente shell
compartida). Por ello la RAM residente no es toda la huella de memoria.
Rust añade unos 22–25 MiB residentes frente a QML mientras está abierto y
consume 3.26 veces su CPU durante esta navegación sostenida. No supone un ahorro
en esta implementación. Cerrado, el frontend Rust sale por completo.

Limitaciones: medición corta en una sesión real con otras aplicaciones abiertas;
no incluye toda la memoria GPU, el trabajo del compositor ni hijos que nacen y
mueren entre muestras. No es una medición de energía ni temperatura. La primera
ronda QML trae páginas de swap a RAM; el orden alternado y las medianas reducen,
pero no eliminan, los efectos de caché y presión de memoria.

Repetir: `python3 -B tools/haku-carousel-prototype/measure_full.py`.
Salida detallada de esta ejecución: `/tmp/haku-carousel-full-comparison-20261013.json`.

## Segunda medición tras optimización

Cambios: omitir tarjetas fuera del viewport antes de preparar geometrías y
texto; evitar recalcular prioridades/caché en cada frame; cadencia nominal de
60 Hz para animaciones, manteniendo duración y curva. Sin quitar funciones.
18 pruebas y smoke de abrir/filtrar/navegar/cerrar pasan nuevamente.

Mismo protocolo, tres rondas alternadas, 40 pasos de 250 ms por ronda:

| Estado | QML RAM MiB | Rust RAM MiB | QML CPU % | Rust CPU % |
|---|---:|---:|---:|---:|
| Abierto quieto | 77.31 | 98.81 | 1.25 | 0.99 |
| Navegación | 77.78 | 101.00 | 16.55 | 27.81 |
| Quieto tras navegar | 77.00 | 101.53 | 1.00 | 1.35 |
| Cerrado | 67.04 | 66.55 | 1.00 | 1.00 |

Swap proporcional ~95.7–95.8 MiB en ambos. La sesión paginó memoria entre
ejecuciones: no atribuir el descenso absoluto de RAM a esta optimización.
La diferencia residente Rust–QML durante navegación sigue siendo ~23 MiB.
CPU Rust baja de 56.11 a 27.81 % de un núcleo (~50 %), mientras la referencia
QML baja de 17.22 a 16.55 %. Rust sigue gastando ~1.68 veces su CPU al girar.
No se midieron temperatura/energía ni se separó cuánto aporta cada cambio.
Rust permanece seleccionado; no se aplicaron/borraron fondos.

Detalle: `/tmp/haku-carousel-full-comparison-20261013-154200.json`.

## Tercera medición: reutilización de geometría

Se cachea el fondo y se reutiliza el almacenamiento gráfico de siete slots de
tarjeta. Invalidación por revisión visual, índice, posición y entrada/cierre;
redimensionar también invalida la caché. Sin cambios de cadencia o funciones.
18 pruebas, smoke completo y comprobación visual de una captura del panel pasan.

Medianas de tres rondas alternadas, mismo protocolo:

| Estado | QML RAM MiB | Rust RAM MiB | QML CPU % | Rust CPU % |
|---|---:|---:|---:|---:|
| Abierto quieto | 76.15 | 97.68 | 1.00 | 1.25 |
| Navegación | 75.85 | 101.80 | 16.33 | 23.33 |
| Quieto tras navegar | 75.21 | 101.86 | 1.33 | 1.33 |
| Cerrado | 65.90 | 65.63 | 1.00 | 1.00 |

Swap proporcional ~95.7 MiB para ambos. CPU de navegación Rust pasa de 27.81 a
23.33 % (~16 % menos adicional; ~58 % menos que 56.11 % inicial). La referencia
QML se mantiene ~16.3–16.6 %. Rust sigue consumiendo más CPU y RAM que QML.
No hay ahorro de RAM demostrado: la caché gráfica cambia CPU por almacenamiento
acotado; la memoria residente durante el giro se mantiene alrededor de 102 MiB.
Son mediciones secuenciales de sesión real, no pruebas térmicas/energéticas.

Detalle: `/tmp/haku-carousel-full-comparison-20261013-154901.json`.

## Cuarta medición: shader GPU propio para las tarjetas

Mismo binario con selección `HAKU_CAROUSEL_RENDERER=canvas|gpu` y QML intacto.
Tres rondas por ruta, orden canvas/gpu/qml y qml/gpu/canvas alternado, galería
real de 91 entradas, 40 cambios cada 250 ms. Medianas:

| Durante el giro | Canvas Rust | Shader Rust | QML |
|---|---:|---:|---:|
| CPU, % de un núcleo | 22.67 | 20.45 | 16.22 |
| PSS residente, MiB | 102.01 | 100.54 | 77.03 |
| Swap PSS, MiB | 92.96 | 92.96 | 92.98 |

CPU ~9.8 % menos frente a Canvas en la misma comparación. RAM residente ~1.5
MiB menor: diferencia pequeña, no un ahorro grande. En reposo, ambas rutas Rust
rondan 98.5 MiB con CPU 1–1.25 %; cerradas, ~67 MiB para la shell restante.
QML conserva ventaja (~26 % menos CPU que shader durante el giro y ~24 MiB
menos residentes). No extrapolar estos porcentajes a consumo energético/GPU.

20 pruebas unitarias y smoke de búsqueda/navegación/cierre pasan. El smoke GPU
comprueba caché de texturas <=14 y contador de uploads estable sin cambios de
tarjeta. Capturas de ambas rutas verificadas visualmente: mismo recorte, texto,
superposición y diseño. No se aplicaron ni borraron fondos durante la prueba.

Se descartó una ejecución inicial porque el carrusel se cerró durante una ronda;
el script ahora verifica supervivencia y ruta activa antes/después de cada fase,
y existencia del proceso Rust en cada muestra. Los números anteriores de esa
ejecución interrumpida no se usaron para esta comparación.

Shader queda como ruta predeterminada de Rust; Canvas permanece seleccionable.
Detalle: `/tmp/haku-carousel-full-comparison-20261013-161726.json`.

## Quinta medición: optimización del QML restaurado

QML sigue activo; no se reinstala la interfaz Rust experimental. El backend Rust
añade información de caché válida al catálogo. QML reutiliza esas rutas sin
spawn, no reemplaza el diccionario si no cambió, y limita la decodificación al
viewport con margen de 64 px. Se conservan siete tarjetas recicladas, tamaño,
tipografía, controles, animación de giro de 210 ms y entrada de 160 ms.

Primero se midió el componente original en tres rondas (CPU de navegación
mediana 20.57 %). Después se compararon ambas rutas en el mismo componente,
alternando `qml-base/qml-opt` y `qml-opt/qml-base`, tres veces, 40 pasos de 250 ms:

| Medida | QML base | QML optimizado |
|---|---:|---:|
| CPU de navegación, % de un núcleo, mediana | 20.55 | 20.33 |
| Workers de miniatura por ronda, caché disponible | 47 | 0 |
| Consultas directas a caché por ronda | 0 | 47 |
| Slots de imagen activos al terminar | 7 | 5 |

No se demuestra una reducción relevante de CPU: diferencia ~1 %, pequeña frente
a la variabilidad. No interpretar las medianas de RAM brutas como ahorro: la
swap cambió ~79 a ~97 MiB durante la sesión, y la residencia base también cambió.
El beneficio comprobado es menos procesos y menos imágenes activas, no una
reducción térmica o de RAM cuantificada.

Referencia original: `/tmp/haku-carousel-full-comparison-20261013-174823.json`.
A/B completo: `/tmp/haku-carousel-full-comparison-20261013-175917.json`.
Una ejecución A/B previa se interrumpió por timeout IPC y no se usó para resumir.
Tras la comparación se compactó el campo de caché a nombre de archivo en vez
de ruta completa (catálogo JSON compacto 30317 → 26040 bytes); las URLs finales
y el renderizado son los mismos. No se midió por separado su efecto en apertura.

Pruebas finales: 5 Rust, 19 worker con fixtures, 6 del backend anterior. El smoke
QML pasó ocho comprobaciones, incluida recuperación de ruta de caché inexistente
sin borrar archivos reales, y compatibilidad sin el campo nuevo. Captura visual
verificada. No se aplicaron ni enviaron fondos a Papelera.
