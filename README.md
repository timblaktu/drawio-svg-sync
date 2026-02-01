# drawio-svg-sync

Re-render `.drawio.svg` files from embedded mxGraphModel XML.

## Problem

When editing `.drawio.svg` files with text editors or AI tools (like Claude Code), the embedded `mxGraphModel` XML is modified but the visible SVG body becomes out of sync. This tool re-renders the SVG from the XML source of truth.

## Installation

### Run directly (no installation)

```bash
nix run github:timblaktu/drawio-svg-sync -- docs/diagram.drawio.svg
```

### Add to your flake

```nix
{
  inputs.drawio-svg-sync.url = "github:timblaktu/drawio-svg-sync";

  outputs = { self, nixpkgs, drawio-svg-sync, ... }: {
    # Option 1: Add to your apps
    apps.x86_64-linux.drawio-svg-sync = drawio-svg-sync.apps.x86_64-linux.default;

    # Option 2: Use the overlay
    nixpkgs.overlays = [ drawio-svg-sync.overlays.default ];
    # Then pkgs.drawio-svg-sync is available

    # Option 3: Add to devShell
    devShells.x86_64-linux.default = pkgs.mkShell {
      buildInputs = [ drawio-svg-sync.packages.x86_64-linux.default ];
    };
  };
}
```

### Add to Home Manager

```nix
{ inputs, pkgs, ... }: {
  home.packages = [ inputs.drawio-svg-sync.packages.${pkgs.system}.default ];
}
```

## Usage

```bash
# Render a single file
drawio-svg-sync docs/diagram.drawio.svg

# Render all .drawio.svg files recursively
drawio-svg-sync -a

# Dry run (show what would be rendered)
drawio-svg-sync -d -a

# Show help
drawio-svg-sync -h
```

## Workflow

1. **Edit XML**: Modify the embedded `mxGraphModel` XML in `.drawio.svg` (text editor, Claude Code, etc.)
2. **Render**: Run `drawio-svg-sync path/to/diagram.drawio.svg`
3. **Verify**: View the SVG in browser/editor to confirm rendering
4. **Commit**: Stage both XML changes and rendered output

**Alternative**: Open `.drawio.svg` directly in Draw.io desktop app (it handles both editing and rendering).

## How it works

`.drawio.svg` files contain:
- An embedded `mxGraphModel` XML block (the source of truth)
- An SVG body (the rendered visualization)

This tool uses `drawio-headless` to export the SVG from the embedded XML, regenerating the visible SVG body.

## License

MIT - see [LICENSE](LICENSE)

## Note on Dependencies

This flake depends on `drawio-headless` which has an unfree license (`asl20 unfreeRedistributable`). The flake handles this automatically - no need to set `NIXPKGS_ALLOW_UNFREE`.
