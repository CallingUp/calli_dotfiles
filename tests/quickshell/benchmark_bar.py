#!/usr/bin/env python3
"""Non-destructive bar animation benchmark; reject interrupted samples."""
import json
import os
from pathlib import Path
import subprocess
import time

CONFIG = Path(__file__).resolve().parents[2] / "config/quickshell/minflair-niri/niri-preview.qml"


def ipc(method):
    return subprocess.check_output(
        ["quickshell", "ipc", "-p", str(CONFIG), "call", "haku-bar", method],
        text=True, timeout=5,
    ).strip()


def state():
    return json.loads(ipc("status"))


def verify(visible):
    current = state()
    if current["fullscreen"] or current["open"] or current["panel"]:
        raise RuntimeError("Pantalla completa o panel abierto: muestra descartada")
    expected = 1 if visible else 0
    if current["visible"] != visible or abs(current["center"] - expected) > .01:
        raise RuntimeError("La barra cambió de estado durante la prueba: muestra descartada")


def main():
    original = state()
    if original["fullscreen"] or original["open"]:
        raise RuntimeError("Sal de pantalla completa y cierra los paneles; no hace falta cerrar el juego")
    pid = int(subprocess.check_output(
        ["systemctl", "--user", "show", "haku-quickshell.service", "-p", "MainPID", "--value"],
        text=True,
    ))

    def ticks():
        fields = Path(f"/proc/{pid}/stat").read_text().rsplit(")", 1)[1].split()
        return int(fields[11]) + int(fields[12])

    results = []
    try:
        for mode in ("hidden", "visible", "animation"):
            ipc("hide" if mode == "hidden" else "revealBar")
            time.sleep(.4)
            verify(mode != "hidden")
            before, started = ticks(), time.monotonic()
            for _ in range(8):
                if mode == "animation":
                    ipc("hide")
                    time.sleep(.2)
                    verify(False)
                    ipc("revealBar")
                time.sleep(.4)
                verify(mode != "hidden")
            results.append({"stage": mode, "cpu_one_core_pct": round(
                (ticks() - before) / os.sysconf("SC_CLK_TCK") / (time.monotonic() - started) * 100, 2)})
    finally:
        ipc("revealBar" if original["visible"] else "hide")
    print(json.dumps({"pid": pid, "samples": results,
                     "note": "Otras aplicaciones siguen activas; no es una prueba aislada."}, indent=2))


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, subprocess.SubprocessError, OSError) as error:
        raise SystemExit(str(error))
