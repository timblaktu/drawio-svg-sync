{
  description = "Re-render .drawio.svg files from embedded mxGraphModel XML";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

      pkgsFor = system: import nixpkgs {
        inherit system;
        config.allowUnfree = true; # drawio-headless has unfree license
      };
    in
    {
      packages = forAllSystems (system:
        let pkgs = pkgsFor system; in {
          default = pkgs.callPackage ./package.nix { };
          drawio-svg-sync = self.packages.${system}.default;
        }
      );

      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/drawio-svg-sync";
        };
        drawio-svg-sync = self.apps.${system}.default;
      });

      devShells = forAllSystems (system:
        let pkgs = pkgsFor system; in {
          default = pkgs.mkShell {
            buildInputs = [
              self.packages.${system}.default
              pkgs.drawio-headless
            ];
            shellHook = ''
              echo "drawio-svg-sync development shell"
              echo "Commands: drawio-svg-sync, drawio"
            '';
          };
        }
      );

      # Overlay for use in other flakes
      overlays.default = final: prev: {
        drawio-svg-sync = self.packages.${prev.system}.default;
      };
    };
}
