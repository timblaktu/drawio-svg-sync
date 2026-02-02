# Plan: DrawIO-SVG-Sync WSL2 Compatibility

**Created**: 2026-02-02
**Updated**: 2026-02-02
**Status**: BLOCKED - deeper drawio issue discovered
**Priority**: 1 (CRITICAL - blocks primary development environment)
**Branch**: `wsl2-fix`

---

## Problem Statement

`drawio-svg-sync` fails silently in WSL2 environments because:
1. It uses `drawio-headless` which unconditionally invokes `xvfb-run`
2. Xvfb fails in WSL2 due to `/tmp/.X11-unix` socket permission issues
3. WSLg already provides a working X server at `DISPLAY=:0`

**Error observed**:
```
Rendering: diagram.drawio.svg ... failed
Rendered: 0 file(s)
Failed:   1 file(s)
```

**Root cause**: Xvfb socket creation fails:
```
_XSERVTransmkdir: Mode of /tmp/.X11-unix should be set to 1777
_XSERVTransSocketCreateListener: failed to bind listener
```

---

## Proof of Concept (2026-02-02)

Direct DrawIO rendering with WSLg's X server WORKS:
```bash
DISPLAY=:0 XDG_CONFIG_HOME=$(mktemp -d) \
  drawio -x -f svg -o output.svg input.drawio.svg
# SUCCESS - valid SVG output created
```

GPU/Vulkan warnings are cosmetic and can be suppressed.

---

## Solution: Smart Display Detection

**Approach**: Bypass `drawio-headless` entirely. Use `drawio` directly with intelligent display detection.

### Architecture

```
                                ┌─────────────────────┐
                                │ drawio-svg-sync     │
                                └──────────┬──────────┘
                                           │
                              ┌────────────┴────────────┐
                              │                         │
                    ┌─────────▼─────────┐    ┌─────────▼─────────┐
                    │ Display Available │    │ No Display        │
                    │ (DISPLAY=:0)      │    │ (CI/headless)     │
                    └─────────┬─────────┘    └─────────┬─────────┘
                              │                         │
                    ┌─────────▼─────────┐    ┌─────────▼─────────┐
                    │ Use drawio        │    │ Use xvfb-run +    │
                    │ directly          │    │ drawio            │
                    └───────────────────┘    └───────────────────┘
```

---

## BLOCKER: DrawIO Export Fails in WSL2 (2026-02-02)

**Discovery**: The display detection fix was implemented, but testing revealed drawio export itself fails in WSL2 - even with `drawio-headless` (the original working solution).

**Evidence**:
```bash
# Original drawio-headless also fails:
$ nix run 'nixpkgs#drawio-headless' -- -x -f svg -o out.svg input.drawio.svg
# Exit code 1, no output

# Direct drawio with native X11 fails with GPU errors:
$ DISPLAY=:0 drawio -x -f svg -o out.svg input.drawio.svg
# [ERROR:viz_main_impl.cc:189] Exiting GPU process due to errors during initialization
# Error: Export failed: input.drawio.svg
```

**Root Cause Hypothesis**: The DrawIO Electron app's GPU process is failing to initialize in WSL2 due to Vulkan/DirectX driver issues (MESA dzn driver). This is a different issue than the Xvfb socket problem the original plan addressed.

**Possible Solutions**:
1. **Investigate `--disable-gpu` flag**: Electron apps often have this option, but it may not be exposed through drawio's CLI
2. **Use drawio AppImage**: May have different electron configuration
3. **Try older drawio version**: GPU requirements may have changed
4. **WSL2 GPU drivers**: Ensure latest Windows GPU drivers installed
5. **Wait for upstream fix**: This may be a known drawio/WSL2 issue

**Current State**: Implementation complete, but untestable until drawio export works.

---

## Progress Tracking

| Task | Status | Definition of Done |
|------|--------|-------------------|
| **0. Setup** | | |
| 0.1 Create branch | `TASK:COMPLETE` | `wsl2-fix` branch created from main |
| **1. Implementation** | | |
| 1.1 Update dependencies | `TASK:COMPLETE` | Replace `drawio-headless` with `drawio` + `xorg.xdpyinfo` |
| 1.2 Add display detection | `TASK:COMPLETE` | Function to test if DISPLAY works |
| 1.3 Implement dual-path rendering | `TASK:COMPLETE` | Direct drawio when display works, xvfb fallback otherwise |
| 1.4 Add verbose mode | `TASK:COMPLETE` | `-v/--verbose` flag for debugging |
| 1.5 Suppress GPU warnings | `TASK:COMPLETE` | Clean stderr output in normal mode |
| **2. Testing** | | |
| 2.1 Test in WSL2 | `TASK:BLOCKED` | **BLOCKED**: drawio export fails regardless of display |
| 2.2 Test fallback | `TASK:BLOCKED` | **BLOCKED**: drawio export fails with xvfb too |
| 2.3 Update test suite | `TASK:PENDING` | Tests pass in sandboxed build |
| **3. Documentation** | | |
| 3.1 Update README | `TASK:PENDING` | Document WSL2 behavior and verbose flag |
| 3.2 Add troubleshooting | `TASK:PENDING` | Common issues and solutions |
| **4. Integration** | | |
| 4.1 Test with diagram skill | `TASK:BLOCKED` | End-to-end skill workflow works |
| 4.2 Update nixcfg if needed | `TASK:PENDING` | Any flake/overlay changes |

---

## Implementation Details

### 1.1 Updated Dependencies (package.nix)

```nix
{ lib
, writeShellApplication
, drawio          # Direct drawio, not drawio-headless
, xvfb-run        # For fallback
, xorg            # For xdpyinfo
, fd
, coreutils
}:

writeShellApplication {
  name = "drawio-svg-sync";

  runtimeInputs = [
    drawio
    xvfb-run
    xorg.xdpyinfo  # To test display availability
    fd
    coreutils
  ];
  # ...
}
```

### 1.2 Display Detection Function

```bash
# Check if we have a working X display
has_working_display() {
  [[ -n "${DISPLAY:-}" ]] && xdpyinfo -display "$DISPLAY" &>/dev/null
}
```

### 1.3 Dual-Path Rendering

```bash
render_with_drawio() {
  local input="$1"
  local output="$2"
  local tmpconfig
  tmpconfig=$(mktemp -d)
  trap "rm -rf $tmpconfig" RETURN

  # Suppress GPU warnings unless verbose
  local stderr_redirect="2>/dev/null"
  [[ "$VERBOSE" == "true" ]] && stderr_redirect=""

  if has_working_display; then
    [[ "$VERBOSE" == "true" ]] && echo "  Using existing display: $DISPLAY"
    eval XDG_CONFIG_HOME="$tmpconfig" drawio -x -f svg -o "$output" "$input" $stderr_redirect
  else
    [[ "$VERBOSE" == "true" ]] && echo "  No display, using xvfb-run"
    eval XDG_CONFIG_HOME="$tmpconfig" xvfb-run --auto-servernum drawio -x -f svg -o "$output" "$input" $stderr_redirect
  fi
}
```

### 1.4 Verbose Mode

```bash
VERBOSE=false

# In argument parsing:
-v|--verbose)
  VERBOSE=true
  shift
  ;;
```

---

## Environment Detection Matrix

| Environment | DISPLAY | xdpyinfo | Action |
|-------------|---------|----------|--------|
| WSL2 + WSLg | `:0` | works | Direct drawio |
| WSL2 - WSLg | empty | fails | xvfb fallback |
| Linux desktop | `:0` | works | Direct drawio |
| Linux headless | empty | fails | xvfb fallback |
| CI (sandbox) | empty | fails | xvfb fallback |
| macOS | varies | varies | Test both paths |

---

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| xvfb-run not working in some environments | Already failing; this is strictly better |
| drawio direct mode has different behavior | Use same flags, test output equivalence |
| xdpyinfo adds dependency | Small, common X11 utility |
| GPU warnings pollute output | Suppress stderr unless verbose |

---

## Success Criteria

1. **Primary**: `drawio-svg-sync` renders successfully in WSL2 with WSLg
2. **Secondary**: Still works in headless environments via xvfb fallback
3. **Tertiary**: Clean output (no GPU warnings in normal mode)
4. **Bonus**: Verbose mode for debugging

---

## Related

- **nixcfg Plan 016**: General Diagramming Skill (depends on this)
- **Diagram Skill**: `home/modules/claude-code/skills/diagram/SKILL.md`
- **Feedback Report**: Session 2026-02-02 (converix-hsw test)
