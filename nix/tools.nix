{ pkgs }:
let
  source = import ./source.nix { inherit (pkgs) lib; };
  names = [ "haku-info" "haku-metrics" "haku-clipboard" "haku-connectivity" "haku-wallpaper" ];
  build = name: pkgs.rustPlatform.buildRustPackage {
    pname = name;
    version = "0.1.0";
    src = source + "/tools/${name}";
    cargoLock.lockFile = ../tools + "/${name}/Cargo.lock";
    nativeBuildInputs = [ pkgs.pkg-config ];
    buildInputs = pkgs.lib.optionals (name == "haku-connectivity") [ pkgs.dbus ];
    meta.platforms = pkgs.lib.platforms.linux;
  };
in pkgs.symlinkJoin { name = "haku-tools"; paths = map build names; }
