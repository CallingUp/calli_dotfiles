import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.Core
pragma Singleton

Item {
    id: systemInfoService

    property int performanceInterval: 2000
    property string powerProfile: "balanced"
    property bool hasPerformanceProfile: true
    property date currentTime: systemClock.date
    // Hosts without hover reveal retain the existing seconds behavior.
    property bool barClockVisible: true
    property string osId: "arch"
    readonly property string osName: {
        switch (osId) {
        case "endeavouros":
            return "EndeavourOS";
        case "manjaro":
        case "manjaro-arm":
            return "Manjaro";
        case "garuda":
            return "Garuda Linux";
        case "arcolinux":
            return "ArcoLinux";
        case "cachyos":
            return "CachyOS";
        case "artix":
            return "Artix Linux";
        default:
            return "Arch Linux";
        }
    }
    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: battery && battery.ready && battery.isLaptopBattery && battery.isPresent
    readonly property int batteryLevel: hasBattery ? Math.min(100, Math.max(0, Math.round(battery.percentage * 100))) : 0
    readonly property string batteryPercentage: batteryLevel + "%"
    readonly property string batteryStatus: {
        if (!hasBattery) return "No battery";
        switch (battery.state) {
        case UPowerDeviceState.Charging: return "Charging";
        case UPowerDeviceState.Discharging: return "Discharging";
        case UPowerDeviceState.FullyCharged: return "Full";
        case UPowerDeviceState.Empty: return "Discharging";
        case UPowerDeviceState.PendingCharge:
        case UPowerDeviceState.PendingDischarge: return "Not charging";
        default: return "Unknown";
        }
    }
    property string batteryEstimation: {
        if (!hasBattery)
            return "Continuous power supply active";

        if (batteryStatus === "Charging")
            return "Charging";
        else if (batteryStatus === "Discharging")
            return "Discharging";
        else if (batteryStatus === "Full")
            return "Fully Charged";
        else if (batteryStatus === "Not charging")
            return "Not charging";
        else
            return "Stationary";
    }

    function applyProfile(profile) {
        let targetProfile = profile;
        systemInfoService.powerProfile = targetProfile;
        setPowerProfileProc.running = false;
        setPowerProfileProc.command = ["powerprofilesctl", "set", targetProfile];
        setPowerProfileProc.running = true;
        if (targetProfile === "performance") {
            systemInfoService.performanceInterval = 1000;
            HyprlandService.enableAnimations = true;
            if (SettingsService.settingsLoaded)
                HyprlandService.setPowerSaverMode(false);

        } else if (targetProfile === "power-saver") {
            systemInfoService.performanceInterval = 5000;
            HyprlandService.enableAnimations = false;
            if (SettingsService.settingsLoaded)
                HyprlandService.setPowerSaverMode(true);

            DisplayProfileService.caffeineActive = false;
        } else {
            systemInfoService.performanceInterval = 2000;
            HyprlandService.enableAnimations = true;
            if (SettingsService.settingsLoaded)
                HyprlandService.setPowerSaverMode(false);

        }
        if (SettingsService.settingsLoaded)
            SettingsService.saveSettings();

    }

    onPerformanceIntervalChanged: {
        if (SettingsService.settingsLoaded)
            SettingsService.saveSettings();

    }

    SystemClock {
        id: systemClock

        precision: SettingsService.clockSeconds && (systemInfoService.barClockVisible || AppState.activeWidget !== "")
            ? SystemClock.Seconds : SystemClock.Minutes
    }

    Process {
        id: setPowerProfileProc
    }

    Process {
        id: osReleaseProc

        command: ["sh", "-c", "grep '^ID=' /etc/os-release | cut -d '=' -f 2 | tr -d '\"'"]
        running: true
        onExited: (exitCode) => {
            if (exitCode === 0) {
                let id = osOutput.text.trim();
                if (id !== "")
                    systemInfoService.osId = id;

            }
        }

        stdout: StdioCollector {
            id: osOutput
        }

    }

}
