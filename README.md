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

# Verbose mode (shows display detection, useful for debugging)
drawio-svg-sync -v -a

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
- A `content` attribute on the `<svg>` tag with compressed `mxGraphModel` XML (the source of truth)
- An SVG body (the rendered visualization)

This tool:
1. Extracts the `content` attribute from the original file
2. Uses the `drawio` desktop application in export mode (`drawio -x`) to regenerate the SVG body
3. Re-injects the `content` attribute into the rendered SVG

This preserves editability in DrawIO desktop while ensuring the rendered output matches the embedded XML source.

### Display handling

Draw.io requires a display to render (it uses Electron internally). The tool automatically handles this:

1. **WSLg/Native display**: If a working X11 display is available (WSLg in WSL2, native Linux, etc.), it uses that directly
2. **Headless fallback**: If no display is available, it automatically uses `xvfb-run` to create a virtual framebuffer

Use `-v/--verbose` to see which display mode is being used.

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

The full test suite renders actual `.drawio.svg` files and requires a display (or xvfb-run fallback) since drawio uses Electron.

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

## Troubleshooting

### GPU/Vulkan warnings

You may see warnings like these in verbose mode or in stderr:

```
ERROR:viz_main_impl.cc:189 GPU process launch failed
ERROR:gpu_init.cc:526 Passthrough is not supported
```

**These are cosmetic** and do not affect rendering. Draw.io/Electron logs these when hardware GPU acceleration isn't available (common in WSL2, containers, headless servers). The export still succeeds.

### Render fails silently ("failed" with no error)

If rendering fails without a clear error message:

1. **Check the file format**: The embedded XML may be corrupted. Use verbose mode:
   ```bash
   drawio-svg-sync -v diagram.drawio.svg
   ```

2. **Validate compression**: Draw.io uses a specific compression format (`URL encode → raw deflate → Base64`). Hand-edited or incorrectly generated files may have invalid compression.

3. **Test with Draw.io directly**: Open the file in Draw.io desktop to see if it can parse the content.

### Display detection issues

Use verbose mode to see which display path is being used:

```bash
drawio-svg-sync -v diagram.drawio.svg
```

Output will show:
- `Using existing display: :0` - Using WSLg or native X11
- `No working display, using xvfb-run` - Using virtual framebuffer fallback

If neither works:
- **WSL2**: Ensure WSLg is enabled (Windows 11 or Windows 10 with WSLg installed)
- **Headless Linux**: Install xvfb (`nix-shell -p xvfb-run` or `apt install xvfb`)

### WSL2-specific issues

1. **WSLg not working**: Check that `/tmp/.X11-unix/X0` exists. If not, restart WSL:
   ```powershell
   # From PowerShell
   wsl --shutdown
   ```

2. **xvfb-run permission errors**: Try running with direct display first, or ensure your user has permission to create virtual displays.

### Creating valid test fixtures

If you need to create new `.drawio.svg` test files:

1. **Best approach**: Create the diagram in Draw.io desktop and save as `.drawio.svg`

2. **Programmatic approach**: Use the compression format:
   ```python
   import zlib, base64
   from urllib.parse import quote

   # Encode: URL encode -> raw deflate -> base64
   url_encoded = quote(xml_content, safe='')
   deflated = zlib.compress(url_encoded.encode('utf-8'), level=9)[2:-4]  # strip zlib header/trailer
   compressed = base64.b64encode(deflated).decode('ascii')
   ```

   Refer to existing `tests/fixtures/*.drawio.svg` files for complete examples of the expected format.

## License

MIT - see [LICENSE](LICENSE)
