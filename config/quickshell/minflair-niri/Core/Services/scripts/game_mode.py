#!/usr/bin/env python3
import json
import os
import subprocess
import sys
from pathlib import Path

sys.dont_write_bytecode = True

PREV_PROFILE_FILE = str(Path(os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local/state"))) / "haku-quickshell" / "previous-power-profile")


def get_status():
    daemon_active = False
    try:
        res = subprocess.run(
            ["gamemoded", "-s"], capture_output=True, text=True, timeout=1
        )
        if "is active" in res.stdout:
            daemon_active = True
    except Exception:
        pass

    power_profile = "balanced"
    try:
        res_pwr = subprocess.run(
            ["powerprofilesctl", "get"],
            capture_output=True,
            text=True,
            timeout=1,
        )
        if res_pwr.returncode == 0:
            power_profile = res_pwr.stdout.strip()
    except Exception:
        pass

    return {
        "gamemode_active": daemon_active,
        "power_profile": power_profile,
    }


def apply_mode():
    res = subprocess.run(["powerprofilesctl", "get"], capture_output=True, text=True, timeout=3)
    if res.returncode:
        return {"success": False, "output": "No se pudo consultar el perfil de energía"}
    current_profile = res.stdout.strip()
    if not os.path.exists(PREV_PROFILE_FILE):
        with open(PREV_PROFILE_FILE, "x") as f:
            f.write(current_profile)
    res = subprocess.run(["powerprofilesctl", "set", "performance"], capture_output=True, text=True, timeout=5)
    return {"success": res.returncode == 0, "status": "applied" if res.returncode == 0 else "failed",
            "output": "" if res.returncode == 0 else "No se pudo activar rendimiento"}


def revert_mode():
    if not os.path.exists(PREV_PROFILE_FILE):
        return {"success": True, "status": "unchanged"}
    with open(PREV_PROFILE_FILE) as f:
        prev_profile = f.read().strip()
    if prev_profile not in ("balanced", "performance", "power-saver"):
        return {"success": False, "output": "Perfil anterior no válido"}
    res = subprocess.run(["powerprofilesctl", "set", prev_profile], capture_output=True, text=True, timeout=5)
    if res.returncode == 0:
        os.remove(PREV_PROFILE_FILE)
    return {"success": res.returncode == 0, "restored_profile": prev_profile,
            "output": "" if res.returncode == 0 else "No se pudo restaurar el perfil anterior"}


def main():
    Path(PREV_PROFILE_FILE).parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    action = sys.argv[1] if len(sys.argv) > 1 else "status"
    if action == "status":
        print(json.dumps(get_status()))
    elif action == "apply":
        print(json.dumps(apply_mode()))
    elif action == "revert":
        print(json.dumps(revert_mode()))
    else:
        print(json.dumps({"error": f"Unknown action {action}"}))


if __name__ == "__main__":
    try:
        main()
    except (OSError, subprocess.TimeoutExpired):
        print(json.dumps({"success": False, "output": "El control de energía no respondió"}))
