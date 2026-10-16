{
  description = "Haku QuickShell: portable desktop modules and Rust helpers";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  outputs = { self, nixpkgs }: let
    systems = [ "x86_64-linux" "aarch64-linux" ];
    each = f: nixpkgs.lib.genAttrs systems (system: f (import nixpkgs { inherit system; }));
  in {
    nixosModules.default = import ./nix/nixos.nix;
    homeManagerModules.default = import ./nix/home.nix;
    packages = each (pkgs: { default = import ./nix/tools.nix { inherit pkgs; }; });
  };
}
