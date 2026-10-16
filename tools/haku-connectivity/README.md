# Consultas de conectividad Rust

Helper bajo demanda; no daemon. La UI usa Rust para `wifi status`, `wifi scan`
y `bluetooth status/scan`. Se conservan el formato JSON, redes guardadas, deduplicación
y prioridad de conexiones activas. El parser nmcli reconoce campos escapados
(dos puntos y barras), también en el SSID conectado.

Dependencias del sistema: nmcli, busctl y timeout. Los comandos tienen un límite
de 12 segundos. Las consultas Bluetooth usan ObjectManager de BlueZ mediante
busctl JSON; no cambian radio, descubrimiento ni conexiones.

Las operaciones del panel de conectividad ya usan Rust. El wrapper permite
volver a Python si falta el binario. No se modificaron frecuencias de consulta,
diseño ni comportamiento de confirmaciones/credenciales.

El escaneo mantiene una conexión D-Bus propia con BlueZ (libdbus/dbus Rust).
Actualiza por señales, agrupa cambios como máximo cada 250 ms y no vuelve a
emitir listas idénticas. No lanza busctl/Python por actualización. SIGTERM/SIGINT,
salida rota, errores y el límite de 120 s liberan la sesión propia de descubrimiento.
Cerrar la conexión también permite que BlueZ retire esa sesión si el proceso muere.
No se sustituye ningún agente de emparejamiento ni se modifica la potencia.
Compilar requiere libdbus y pkg-config. Referencia de la API:
https://docs.rs/dbus/0.9.12/dbus/blocking/struct.Connection.html

Las acciones Bluetooth `toggle-power` y `toggle-connect` también usan Rust,
conservando bluetoothctl y límites de 20/25 segundos. Validan la dirección MAC,
consultan el estado antes de elegir conectar/desconectar y no ejecutan cambios
si falla esa consulta. La UI solo empareja dispositivos nuevos mediante el agente
Rust, sin cambios en sus preguntas ni confirmaciones. Las pruebas
de estas acciones usan bluetoothctl/BlueZ falsos: no cambian dispositivos reales.

Wi-Fi `toggle-radio`, `connect` sin contraseña, `disconnect` y `forget` también
usan Rust. Conservan nmcli y la preferencia por perfiles guardados, con espera
de 25 s para conectar y límite externo de 30 s. Los nombres se pasan como
argumentos literales, sin shell; se interpretan los escapes de nmcli al buscar
perfiles. Los errores se devuelven como JSON y no se cambia la radio si falla
la consulta previa. Las pruebas usan nmcli simulado, sin desconectar ni borrar
perfiles reales.

`wifi connect-private <ssid>` también usa Rust/libdbus: recibe una sola línea JSON
por stdin (máximo 16 KiB), sin secreto en argv ni logs. Conserva la búsqueda del
AP, WPA-PSK/SAE, AddAndActivateConnection2 con `persist=memory`, espera de 25 s
y eliminación del perfil temporal si falla después de crearse. Rechaza redes
empresariales como el backend anterior. No persiste claves en archivos propios.
Las pruebas usan un backend simulado: éxito, timeout, cancelación, fallo de
estado, AP ausente y validación. Las pruebas CLI de entradas inválidas no llegan
a NetworkManager. No se probó una reconexión real para evitar alterar la red.

`bluetooth pair <mac>` implementa el agente KeyboardDisplay por D-Bus en Rust.
Conserva PIN, passkey, confirmación numérica, autorización y códigos mostrados.
El agente es propio de la aplicación, no sustituye al agente predeterminado.
Solo acepta peticiones de BlueZ para el dispositivo elegido. Las respuestas se
reciben por stdin, no argumentos. Cancela al recibir SIGTERM/SIGINT, EOF o una
petición de cancelación; rechaza respuestas pendientes y desregistra el agente.
Límites: Pair 65 s, Connect 20 s y sesión 75 s. El agente Python original sigue
disponible en el wrapper si falta el binario.

Pruebas completas del protocolo (requieren dbus-daemon, python-dbus y PyGObject
únicamente para el servicio simulado):

```sh
python3 ~/haku_shell/tools/haku-connectivity/test_pair.py
```

Cada prueba crea un bus D-Bus privado y BlueZ falso; no registra agentes ni
empareja dispositivos en el bus del sistema. Se verifican confirmaciones, PIN,
passkey, rechazos, cancelación, EOF, señales, otro dispositivo y fallo posterior
de Connect, incluida la desregistración. No se ha probado un emparejamiento real.

```sh
cargo build --locked --release --manifest-path ~/haku_shell/tools/haku-connectivity/Cargo.toml
cargo test --locked --manifest-path ~/haku_shell/tools/haku-connectivity/Cargo.toml
python3 ~/haku_shell/tools/haku-connectivity/test_worker.py
```

Las pruebas usan herramientas falsas y no modifican conectividad. Comprobación
real de solo lectura: mismo JSON de estado que Python para Wi-Fi y Bluetooth.
Medianas de 5 consultas en esta sesión: Wi-Fi 63,7→27,1 ms; Bluetooth
74,1→4,9 ms. No demuestra una reducción de temperatura ni de RAM en reposo.
