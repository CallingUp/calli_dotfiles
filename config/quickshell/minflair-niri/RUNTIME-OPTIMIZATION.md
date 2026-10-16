# Actualizaciones bajo demanda

## Prueba de capa gráfica (2026-10-15)

Con tres islas centradas, `tests/quickshell/benchmark_bar.py` verificó sus
estados en cada ciclo. CPU de QuickShell, porcentaje de un núcleo:

| Fondo | Oculto | Visible quieto | Aparición/cierre repetidos |
| --- | ---: | ---: | ---: |
| Capa original, MSAA 4 | 0,82 | 0,82 | 6,61 |
| Sin capa adicional | 0,82 | 0,82 | 6,50 |

Son muestras cortas con otras aplicaciones activas, no una prueba aislada.
La diferencia no demuestra ahorro: se restauró la capa original para conservar
el suavizado. No se atribuye a esta prueba una mejora térmica ni de RAM.

## Servicios

El árbol visual de las islas se marca no visible una vez completadas todas
las animaciones de salida (`barProgress === 0` y sin solicitudes de apertura).
Las líneas de hover permanecen fuera de ese árbol y siguen recibiendo eventos.
Los componentes no se destruyen: conservan estado y las salidas no se cortan.
No se afirma un ahorro medido por este cambio; Qt ya puede descartar parte
del contenido situado fuera de pantalla.

La comprobación del bloqueo de Pacman se ejecuta al abrir dashboard/gestor de
paquetes y mientras haya una actualización detectada. Ya no lanza `test -f`
cada diez segundos con esos paneles cerrados. Las actualizaciones externas
iniciadas con todo oculto se detectan al abrir el panel. Se mantienen las
búsquedas horarias y manuales de actualizaciones y la vigilancia de una
actualización ya detectada, aunque se cierre el panel.

Audio agrupa eventos de micrófono en 80 ms y no cancela/reinicia una consulta
de fuente ya en curso: conserva una actualización pendiente. Los eventos
`source-output` (streams de grabación) no provocan consultas de volumen;
los de `source` y `server` siguen actualizando fuente, volumen y mute.

El indicador de grabación deja de ejecutar `pidof wf-recorder` cada cinco
segundos mientras la barra y el panel de captura están ocultos y no se conoce
una grabación activa. Al mostrar la barra/panel consulta inmediatamente; una
grabación detectada mantiene la comprobación cada segundo hasta terminar.
Las grabaciones externas iniciadas con todo oculto se detectan al mostrar la
barra, no en segundo plano. El control explícito conserva su consulta diferida.

El reloj compartido usa precisión de minutos cuando la isla central está oculta
y no hay widgets abiertos. Recupera precisión de segundos al mostrarse, si esa
opción está habilitada. Se conserva el reloj activo para no congelar la fecha.
Esto reduce los ticks periódicos del reloj oculto, no acredita por sí solo un
ahorro medible de CPU, RAM ni temperatura.

MPRIS conserva metadatos y la última duración válida aunque el panel esté cerrado.
El fallback yt-dlp solo se programa si hay un consumidor de timeline abierto:
music, notificationsCenter, dashboard o controlCenter. Al cerrar se cancela el
debounce; una consulta ya iniciada puede terminar dentro de su límite de 20 s.
Abrir el panel llama rememberDuration para recuperar los datos que falten.
No se modifica reproducción, seeking ni recuperación de Firefox.

El brillo se lee al abrir y una vez por segundo mientras el panel está abierto,
no cuatro veces. El slider actualiza su valor inmediatamente al moverlo y
reconsulta al finalizar el comando si el usuario ya soltó el control.
Se evitan lecturas superpuestas con el setter; cerrado no hay sondeo.

Verificación:

```sh
node ~/haku_shell/config/quickshell/minflair-niri/Modules/Music/test_seek.cjs
quickshell ipc -p ~/haku_shell/config/quickshell/minflair-niri/niri-preview.qml call haku-media-timeline status
```

Muestras de 10 s, PID 1328, paneles cerrados (2026-10-13):
- Antes: CPU 0,9 % de un núcleo, PSS 158,62 MiB, SwapPss 28,95 MiB.
- Después de hot reload: CPU 0,7 %, PSS 160,91 MiB, SwapPss 28,95 MiB.

No son pruebas aisladas ni acreditan ahorro estable de CPU/RAM o temperatura.
La subida pequeña de PSS tras hot reload tampoco demuestra una fuga.
En la comprobación posterior no estaban activos haku-metrics, consultas de
estado/scan de haku-connectivity ni yt-dlp. Los principales workers ya estaban
condicionados a visibilidad antes de este ajuste. No se cambia el diseño.
