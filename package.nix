{ lib
, writeShellApplication
, drawio              # Direct drawio binary, not drawio-headless
, xvfb-run           # Fallback for headless environments
, xorg               # For xdpyinfo to test display availability
, fd
, coreutils
}:

writeShellApplication {
  name = "drawio-svg-sync";

  runtimeInputs = [ drawio xvfb-run xorg.xdpyinfo fd coreutils ];

  text = ''
    # Colors for output
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    NC='\033[0m' # No Color

    # Verbose mode (off by default)
    VERBOSE=false

    usage() {
      echo "Usage: drawio-svg-sync [OPTIONS] [FILE...]"
      echo ""
      echo "Re-render .drawio.svg files from embedded mxGraphModel XML."
      echo ""
      echo "OPTIONS:"
      echo "  -a, --all      Find and render all .drawio.svg files recursively"
      echo "  -d, --dry-run  Show what would be rendered without executing"
      echo "  -v, --verbose  Show detailed output including display detection"
      echo "  -h, --help     Show this help message"
      echo ""
      echo "EXAMPLES:"
      echo "  drawio-svg-sync docs/diagram.drawio.svg     # Render single file"
      echo "  drawio-svg-sync -a                          # Render all .drawio.svg files"
      echo "  drawio-svg-sync -d -a                       # Dry run for all files"
      echo "  drawio-svg-sync -v -a                       # Verbose mode for debugging"
    }

    # Check if we have a working X display (e.g., WSLg provides DISPLAY=:0)
    has_working_display() {
      [[ -n "''${DISPLAY:-}" ]] && xdpyinfo -display "$DISPLAY" &>/dev/null
    }

    render_file() {
      local file="$1"
      local dry_run="''${2:-false}"

      if [[ ! -f "$file" ]]; then
        echo -e "''${RED}Error: File not found: $file''${NC}" >&2
        return 1
      fi

      if [[ ! "$file" =~ \.drawio\.svg$ ]]; then
        echo -e "''${YELLOW}Warning: Skipping non-.drawio.svg file: $file''${NC}" >&2
        return 0
      fi

      if [[ "$dry_run" == "true" ]]; then
        echo -e "''${YELLOW}[dry-run]''${NC} Would render: $file"
        return 0
      fi

      echo -n "Rendering: $file ... "

      # Export to temporary file, then move back
      # drawio -x exports based on embedded XML, regenerating SVG body
      local tmpfile tmpconfig
      tmpfile=$(mktemp --suffix=.svg)
      tmpconfig=$(mktemp -d)

      # Cleanup on function return
      cleanup() { rm -f "$tmpfile"; rm -rf "$tmpconfig"; }
      trap cleanup RETURN

      local result=0

      if has_working_display; then
        # Use existing display (WSLg, native X11, etc.)
        [[ "$VERBOSE" == "true" ]] && echo -e "\n  ''${YELLOW}Using display: $DISPLAY''${NC}"
        if [[ "$VERBOSE" == "true" ]]; then
          XDG_CONFIG_HOME="$tmpconfig" drawio -x -f svg -o "$tmpfile" "$file" || result=$?
        else
          # Suppress GPU/Vulkan warnings in normal mode
          XDG_CONFIG_HOME="$tmpconfig" drawio -x -f svg -o "$tmpfile" "$file" 2>/dev/null || result=$?
        fi
      else
        # No display available, use xvfb-run
        [[ "$VERBOSE" == "true" ]] && echo -e "\n  ''${YELLOW}No display, using xvfb-run''${NC}"
        if [[ "$VERBOSE" == "true" ]]; then
          XDG_CONFIG_HOME="$tmpconfig" xvfb-run --auto-servernum drawio -x -f svg -o "$tmpfile" "$file" || result=$?
        else
          XDG_CONFIG_HOME="$tmpconfig" xvfb-run --auto-servernum drawio -x -f svg -o "$tmpfile" "$file" 2>/dev/null || result=$?
        fi
      fi

      if [[ $result -eq 0 && -s "$tmpfile" ]]; then
        mv "$tmpfile" "$file"
        echo -e "''${GREEN}done''${NC}"
        return 0
      else
        echo -e "''${RED}failed''${NC}"
        return 1
      fi
    }

    # Parse arguments
    ALL=false
    DRY_RUN=false
    FILES=()

    while [[ $# -gt 0 ]]; do
      case $1 in
        -a|--all)
          ALL=true
          shift
          ;;
        -d|--dry-run)
          DRY_RUN=true
          shift
          ;;
        -v|--verbose)
          VERBOSE=true
          shift
          ;;
        -h|--help)
          usage
          exit 0
          ;;
        -*)
          echo -e "''${RED}Unknown option: $1''${NC}" >&2
          usage
          exit 1
          ;;
        *)
          FILES+=("$1")
          shift
          ;;
      esac
    done

    # Validate arguments
    if [[ "$ALL" == "false" && ''${#FILES[@]} -eq 0 ]]; then
      echo -e "''${RED}Error: No files specified. Use -a for all files or specify files.''${NC}" >&2
      usage
      exit 1
    fi

    # Find all files if --all
    if [[ "$ALL" == "true" ]]; then
      while IFS= read -r -d "" file; do
        FILES+=("$file")
      done < <(fd -e drawio.svg -0)
    fi

    # Handle no files found
    if [[ ''${#FILES[@]} -eq 0 ]]; then
      echo -e "''${YELLOW}No .drawio.svg files found.''${NC}"
      exit 0
    fi

    # Render files
    success=0
    failed=0
    for file in "''${FILES[@]}"; do
      if render_file "$file" "$DRY_RUN"; then
        ((success++)) || true
      else
        ((failed++)) || true
      fi
    done

    # Summary
    if [[ "$DRY_RUN" == "true" ]]; then
      echo -e "\n''${YELLOW}Dry run complete.''${NC} Would render $success file(s)."
    else
      echo -e "\nRendered: ''${GREEN}$success''${NC} file(s)"
      if [[ $failed -gt 0 ]]; then
        echo -e "Failed:   ''${RED}$failed''${NC} file(s)"
        exit 1
      fi
    fi
  '';

  meta = with lib; {
    description = "Re-render .drawio.svg files from embedded mxGraphModel XML";
    longDescription = ''
      Re-renders the visible SVG body of .drawio.svg files from the
      embedded mxGraphModel XML, which is the source of truth.

      Use this after editing .drawio.svg files directly (e.g., with Claude Code
      or any text editor) to ensure the visible SVG matches the XML data.
    '';
    homepage = "https://github.com/timblaktu/drawio-svg-sync";
    license = licenses.mit;
    maintainers = [ ];
    platforms = platforms.unix;
    mainProgram = "drawio-svg-sync";
  };
}
