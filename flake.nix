{
  description = "Python library that helps creating pipelines of arbitrary tasks";
  inputs = {
    textapp-pkgs.url = "git+ssh://git@tsa04.isa.ru/textapp/textapp-pkgs";
    udpipe_ext.url = "git+ssh://git@tsa04.isa.ru/textapp/udpipe_ext";
    udpipe_ext.inputs.textapp-pkgs.follows = "textapp-pkgs";
  };
  outputs = { self, textapp-pkgs, udpipe_ext }:
    let pkgs = import textapp-pkgs.inputs.nixpkgs {
          system = "x86_64-linux";
          overlays = [ textapp-pkgs.overlays.default udpipe_ext.overlays.default ];
          config.allowUnfree = true;
        };
        tlib = textapp-pkgs.lib;
        pypkgs = pkgs.python-torch.pkgs;
        tpkgs = textapp-pkgs.packages.x86_64-linux;
    in {

      devShells.x86_64-linux.default =
        pkgs.mkShell {
          inputsFrom = [ pypkgs.stanza ];
          buildInputs = [
            pypkgs.udpipe_ext
            pypkgs.pytest
            tpkgs.pyright
            pypkgs.pylint
            pypkgs.ipykernel
          ];

          shellHook=''
          export LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu/nvidia/current/:$LD_LIBRARY_PATH
          source ./scripts/config.sh
          [ -n "$PS1" ] && setuptoolsShellHook
          '';

        };
    };

}
