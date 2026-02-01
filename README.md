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

## Testing

### Run CLI tests (sandboxed)

```bash
nix flake check
```

This runs the `integration` check which tests CLI behavior, argument parsing, and error handling.

### Run full rendering tests (requires display)

```bash
# Enter dev shell with all dependencies
nix develop

# Run the test suite
./tests/run-tests.sh
```

The full test suite renders actual `.drawio.svg` files and requires a display (X11/Wayland) since drawio-headless uses Electron.

### Test fixtures

The `tests/fixtures/` directory contains various test cases:

- `simple-rect.drawio.svg` - Basic rectangle shape
- `with-text.drawio.svg` - Shape with text label
- `two-boxes-arrow.drawio.svg` - Two shapes with connector arrow
- `special-chars.drawio.svg` - UTF-8 characters (Héllo Wörld 日本語)
- `empty-diagram.drawio.svg` - Minimal empty diagram
- `nested/deep/nested-box.drawio.svg` - Nested directory structure (tests `-a` flag)
- `invalid-corrupt.drawio.svg` - Invalid content (tests error handling)
- `not-drawio.svg` - Regular SVG without draw.io content (tests extension filtering)

## License

MIT - see [LICENSE](LICENSE)

## Note on Dependencies

This flake depends on `drawio-headless` which has an unfree license (`asl20 unfreeRedistributable`). The flake handles this automatically - no need to set `NIXPKGS_ALLOW_UNFREE`.
