# Rendimiento: diagnóstico reproducible

Las optimizaciones se evalúan con pruebas, no con la suposición de que un
lenguaje o renderer es siempre más ligero. No se publican cifras de una máquina
personal como garantías para otros equipos.

## Ciclo de vida

- Las islas dejan de dibujarse tras completar su animación de salida.
- Los procesos de estadísticas se ejecutan solo si existe un consumidor visible.
- El timeline y sus consultas auxiliares se activan bajo demanda.
- El carrusel se instancia al abrirlo y se libera tras la animación de cierre.
- Los eventos de micrófono se agrupan para evitar consultas duplicadas.
- Las comprobaciones de paquetes se limitan a backends y paneles compatibles.

## Método

1. Mantén iguales carga, perfil energético, resolución y límite de FPS.
2. Mide por separado reposo, apertura, navegación, animación y cierre.
3. Comprueba el estado real: una barra oculta por fullscreen no mide el dibujo
   de una barra visible.
4. Repite muestras alternando el orden de las implementaciones.
5. Usa CPU como porcentaje de un núcleo y PSS para memoria compartida.
   Informa SwapPss por separado y registra aplicaciones competidoras.
6. Para temperatura/energía necesitas mediciones propias sostenidas y una carga
   controlada; una diferencia pequeña de CPU no demuestra una mejora térmica.

## Herramientas

Desde la raíz del repositorio:

```sh
python3 tests/quickshell/benchmark_bar.py
```

La prueba comprueba visibilidad en cada ciclo y rechaza pantalla completa o
paneles que interfieran. Cambia temporalmente el estado de la barra y restaura
su estado anterior. No cierra aplicaciones ni cambia perfiles de energía.

Los scripts de `tools/haku-carousel-prototype/` son experimentales: revisa sus
argumentos y efectos antes de medir. No se ejecutan durante una instalación.
