# Plan: DrawIO-SVG-Sync WSL2 Compatibility

**Created**: 2026-02-02
**Updated**: 2026-02-02
**Status**: COMPLETE - root cause was invalid test fixtures, not drawio/WSL2 issue
**Priority**: 1 (CRITICAL - blocks primary development environment)
**Branch**: `wsl2-fix`

---

## Problem Statement (Original)

`drawio-svg-sync` fails silently in WSL2 environments.

**Error observed**:
```
Rendering: diagram.drawio.svg ... failed
Rendered: 0 file(s)
Failed:   1 file(s)
```

---

## Root Cause Analysis (2026-02-02)

### Initial Hypothesis (INCORRECT)
- Xvfb socket permission issues in WSL2
- GPU/Vulkan driver failures in WSLg

### Actual Root Cause (CORRECT)
**Test fixtures contained INVALID compressed data.**

The draw.io compression format is: `URL encode → raw deflate → Base64`

Test fixtures were created with invalid/corrupted compressed content that could not be parsed by drawio's export function.

### Evidence

1. **GPU warnings are cosmetic** - exports succeed despite `ERROR:viz_main_impl.cc:189`
2. **Real-world files work** - converix-hsw diagrams export successfully
3. **Properly compressed test data works** - created valid fixtures that export correctly
4. **Invalid compression fails regardless of environment** - not WSL2-specific

---

## Resolution

### Changes Made

1. **Smart display detection** (commit 8cd5e88) - use WSLg's X server when available
2. **Fixed test fixtures** - regenerated all fixtures with valid draw.io compression

### Files Changed

- `package.nix` - Use `drawio` directly with `xvfb-run` fallback
- `tests/fixtures/*.drawio.svg` - Regenerated with valid compression
- `scripts/regenerate-fixtures.py` - Script to create valid fixtures

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
| 2.1 Test in WSL2 | `TASK:COMPLETE` | Works with fixed fixtures |
| 2.2 Test fallback | `TASK:COMPLETE` | xvfb-run works for headless |
| 2.3 Update test suite | `TASK:COMPLETE` | Fixtures regenerated with valid compression |
| **3. Documentation** | | |
| 3.1 Update README | `TASK:COMPLETE` | Document WSL2 behavior and verbose flag |
| 3.2 Add troubleshooting | `TASK:COMPLETE` | Common issues and solutions |
| **4. Integration** | | |
| 4.1 Test with diagram skill | `TASK:PENDING` | End-to-end skill workflow works |
| 4.2 Update nixcfg if needed | `TASK:PENDING` | Any flake/overlay changes |

---

## Future Work: Test Infrastructure Improvements

### TASK:FUTURE-1: Fixture Validation in CI
Add a Nix check that validates all test fixtures:
- Verify compression format is valid (can be decompressed)
- Verify mxfile structure is valid
- Ensure fixtures can be exported by drawio

### TASK:FUTURE-2: Fixture Generation Documentation
Document the compression format and provide tooling:
- Keep `scripts/regenerate-fixtures.py` maintained
- Add comments explaining draw.io compression: `URL encode → raw deflate → Base64`
- Include example for creating new fixtures

### TASK:FUTURE-3: Real-File Testing
Add integration tests that:
- Use drawio to create fresh diagrams (not hand-crafted fixtures)
- Export and re-import to verify round-trip
- Test with actual drawio binary, not mocked data

### TASK:FUTURE-4: Compression Validation Function
Add a validation function to the test suite:
```python
def validate_drawio_compression(data: str) -> bool:
    """Return True if data is valid draw.io compressed format."""
    try:
        b64_decoded = base64.b64decode(data)
        inflated = zlib.decompress(b64_decoded, -15)  # raw deflate
        unquote(inflated.decode('utf-8'))
        return True
    except:
        return False
```

---

## Technical Details

### Draw.io Compression Format

**Encode** (creating compressed content):
```python
url_encoded = quote(xml, safe='')
deflated = zlib.compress(url_encoded.encode('utf-8'), level=9)[2:-4]  # strip zlib header/trailer
b64_encoded = base64.b64encode(deflated).decode('ascii')
```

**Decode** (reading compressed content):
```python
b64_decoded = base64.b64decode(compressed)
inflated = zlib.decompress(b64_decoded, -15)  # raw inflate
xml = unquote(inflated.decode('utf-8'))
```

### Key Learnings

1. GPU/Vulkan warnings in WSL2 are **cosmetic** - exports succeed regardless
2. `drawio-headless` uses `xvfb-run` which can fail in WSL2, but direct `drawio` with WSLg works
3. Test fixtures must use **exact** draw.io compression format
4. Python `zlib.compress(...)[2:-4]` produces compatible raw deflate

---

## Related

- **nixcfg Plan 016**: General Diagramming Skill (unblocked by this fix)
- **Diagram Skill**: `home/modules/claude-code/skills/diagram/SKILL.md`
