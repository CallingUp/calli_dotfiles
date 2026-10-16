{ lib }:
lib.cleanSourceWith {
  src = ../.;
  filter = path: type:
    let name = baseNameOf path;
    in !(builtins.elem name [ ".git" "target" "__pycache__" "result" ])
       && lib.cleanSourceFilter path type;
}
