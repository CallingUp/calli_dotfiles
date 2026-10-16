{ pkgs }:
let
  python = pkgs.python3.withPackages (p: [ p.pillow p.psutil p.requests p.pygobject3 p.colorthief p.dbus-python ]);
in [
  pkgs.quickshell pkgs.kitty pkgs.jq pkgs.curl pkgs.wl-clipboard pkgs.cliphist
  pkgs.imagemagick pkgs.playerctl pkgs.brightnessctl pkgs.pamixer pkgs.wireplumber
  pkgs.libnotify pkgs.networkmanager pkgs.bluez pkgs.upower pkgs.glib pkgs.coreutils
  pkgs.procps pkgs.bash pkgs.swww pkgs.gammastep python
]
