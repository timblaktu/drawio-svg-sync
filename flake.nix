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
        config.allowUnfree = true; # drawio has unfree license
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
              pkgs.drawio
              pkgs.xvfb-run
              pkgs.xorg.xdpyinfo
            ];
            shellHook = ''
              echo "drawio-svg-sync development shell"
              echo "Commands: drawio-svg-sync, drawio"
              if [[ -n "''${DISPLAY:-}" ]] && xdpyinfo &>/dev/null; then
                echo "Display detected: $DISPLAY (using native X11)"
              else
                echo "No display detected (will use xvfb-run)"
              fi
            '';
          };
        }
      );

      # Overlay for use in other flakes
      overlays.default = final: prev: {
        drawio-svg-sync = self.packages.${prev.system}.default;
      };

      # Tests
      checks = forAllSystems (system:
        let
          pkgs = pkgsFor system;
          drawio-svg-sync = self.packages.${system}.default;
        in
        {
          # Full integration test suite
          integration = pkgs.runCommand "drawio-svg-sync-integration-tests"
            {
              nativeBuildInputs = [
                drawio-svg-sync
                pkgs.fd
                pkgs.coreutils
                pkgs.gnugrep
                pkgs.bash
              ];
              # Required for drawio-headless (Electron app)
              # Note: These tests may need to run with --impure or in a VM
              # for full graphical rendering
            } ''
            set -euo pipefail
            export HOME=$TMPDIR

            echo "=== Running drawio-svg-sync integration tests ==="

            # Copy test fixtures to work directory
            cp -r ${./tests/fixtures} $TMPDIR/fixtures
            chmod -R u+w $TMPDIR/fixtures
            cd $TMPDIR/fixtures

            # Test 1: Help flag
            echo "Test 1: Help flag..."
            drawio-svg-sync --help | grep -q "Usage:" || exit 1
            echo "  PASS"

            # Test 2: Dry run mode
            echo "Test 2: Dry run mode..."
            drawio-svg-sync -d simple-rect.drawio.svg 2>&1 | grep -q "dry-run" || exit 1
            echo "  PASS"

            # Test 3: Error on no arguments
            echo "Test 3: Error on no arguments..."
            output=$(drawio-svg-sync 2>&1 || true)
            if echo "$output" | grep -q "No files specified"; then
              echo "  PASS"
            else
              echo "  FAIL: expected 'No files specified', got: $output"
              exit 1
            fi

            # Test 4: Error on nonexistent file
            echo "Test 4: Error on nonexistent file..."
            output=$(drawio-svg-sync /nonexistent.drawio.svg 2>&1 || true)
            if echo "$output" | grep -q "File not found"; then
              echo "  PASS"
            else
              echo "  FAIL: expected 'File not found', got: $output"
              exit 1
            fi

            # Test 5: Warning on wrong extension
            echo "Test 5: Warning on wrong extension..."
            drawio-svg-sync not-drawio.svg 2>&1 | grep -q "Skipping" || exit 1
            echo "  PASS"

            # Test 6: Batch dry run finds files
            echo "Test 6: Batch dry run finds files..."
            output=$(drawio-svg-sync -d -a 2>&1 || true)
            if echo "$output" | grep -q "Would render"; then
              echo "  PASS"
            else
              echo "  FAIL: expected 'Would render', got: $output"
              exit 1
            fi

            echo ""
            echo "=== All CLI tests passed ==="

            # Create output marker
            mkdir -p $out
            echo "All tests passed" > $out/result.txt
          '';

          # Rendering tests require display - run separately with --impure if needed
          # This is a placeholder that always passes for sandboxed builds
          rendering = pkgs.runCommand "drawio-svg-sync-rendering-tests"
            {
              nativeBuildInputs = [ drawio-svg-sync pkgs.fd ];
              meta.broken = pkgs.stdenv.isDarwin; # drawio-headless needs X11 on Linux
            } ''
            set -euo pipefail
            export HOME=$TMPDIR

            # Check the tool exists and has expected structure
            echo "Checking drawio-svg-sync installation..."
            drawio-svg-sync --help > /dev/null

            # NOTE: Full rendering tests require a display (Xvfb or real)
            # Run with: nix build .#checks.x86_64-linux.rendering-full --impure
            # Or use: nix develop -c ./tests/run-tests.sh

            echo "Installation check passed (rendering tests require display)"
            mkdir -p $out
            echo "Installation verified" > $out/result.txt
          '';
        }
      );
    };
}
