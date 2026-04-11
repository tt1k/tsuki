#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
FE_MAC_DIR="$ROOT_DIR/code/fe/macos"
FE_WEB_DIR="$ROOT_DIR/code/fe/web"
BE_DIR="$ROOT_DIR/code/be"

TSUKI_DEFAULT_VERSION="0.0.1"
TSUKI_DEFAULT_BUILD="0008"
TSUKI_DEFAULT_VERSION_DEV="0.0.1-dev"
TSUKI_DEFAULT_BUILD_DEV="0008"

if [[ -t 1 ]]; then
  UI_RESET=$'\033[0m'
  UI_BOLD=$'\033[1m'
  UI_DIM=$'\033[2m'
  UI_BLUE=$'\033[34m'
  UI_GREEN=$'\033[32m'
  UI_YELLOW=$'\033[33m'
  UI_RED=$'\033[31m'
else
  UI_RESET=''
  UI_BOLD=''
  UI_DIM=''
  UI_BLUE=''
  UI_GREEN=''
  UI_YELLOW=''
  UI_RED=''
fi

log_section() {
  printf "\n%b%s%b\n" "$UI_BOLD" "$*" "$UI_RESET"
}

log_info() {
  printf "%b[INFO]%b %s\n" "$UI_BLUE" "$UI_RESET" "$*"
}

log_success() {
  printf "%b[ OK ]%b %s\n" "$UI_GREEN" "$UI_RESET" "$*"
}

log_warn() {
  printf "%b[WARN]%b %s\n" "$UI_YELLOW" "$UI_RESET" "$*" >&2
}

log_error() {
  printf "%b[ERR ]%b %s\n" "$UI_RED" "$UI_RESET" "$*" >&2
}

print_usage() {
  cat <<'EOF'
Tsuki Workspace CLI

Usage:
  ./tsuki.sh start
  ./tsuki.sh fe <run|stop|build|test|clean|package>
  ./tsuki.sh be start
  ./tsuki.sh be <command...>

Commands:
  start                Start frontend app (default)
  fe run               Run TsukiApp
  fe stop              Stop TsukiApp
  fe build             Build TsukiApp
  fe test              Run frontend tests
  fe clean             Clean frontend build cache
  fe package           Build signed versioned .dmg in dist/
  be start             Start backend service (auto-detect)
  be <command...>      Run custom command inside code/be
EOF
}

write_info_plist() {
  local target_app_dir="$1"
  local target_app_name="$2"
  local bundle_id="$3"
  local short_version="$4"
  local bundle_version="$5"

  cat >"$target_app_dir/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>$target_app_name</string>
  <key>CFBundleDisplayName</key><string>$target_app_name</string>
  <key>CFBundleIdentifier</key><string>$bundle_id</string>
  <key>CFBundleVersion</key><string>$bundle_version</string>
  <key>CFBundleShortVersionString</key><string>$short_version</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleExecutable</key><string>$target_app_name</string>
  <key>CFBundleIconFile</key><string>$target_app_name</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>CFBundleURLTypes</key>
  <array>
    <dict>
      <key>CFBundleURLName</key><string>com.tsuki.app.urlscheme</string>
      <key>CFBundleURLSchemes</key>
      <array>
        <string>tsuki</string>
      </array>
    </dict>
  </array>
</dict>
</plist>
EOF
}

copy_app_icon() {
  local target_app_dir="$1"
  local source_svg="$ROOT_DIR/icon.svg"
  local resources_dir="$target_app_dir/Contents/Resources"
  local icon_name="Tsuki"

  if [[ ! -f "$source_svg" ]]; then
    log_warn "App icon source not found at $source_svg"
    return
  fi

  local tmp_dir
  local content_png
  local iconset_dir

  tmp_dir="$(mktemp -d "/tmp/tsuki-icon.XXXXXX")"
  content_png="$tmp_dir/content.png"
  iconset_dir="$tmp_dir/$icon_name.iconset"

  mkdir -p "$iconset_dir" "$resources_dir"

  while IFS=':' read -r canvas_size content_size filename; do
    sips -s format png -z "$content_size" "$content_size" "$source_svg" --out "$content_png" >/dev/null
    sips --padToHeightWidth "$canvas_size" "$canvas_size" "$content_png" --out "$iconset_dir/$filename" >/dev/null
  done <<'EOF'
16:13:icon_16x16.png
32:26:icon_16x16@2x.png
32:26:icon_32x32.png
64:52:icon_32x32@2x.png
128:103:icon_128x128.png
256:206:icon_128x128@2x.png
256:206:icon_256x256.png
512:412:icon_256x256@2x.png
512:412:icon_512x512.png
1024:824:icon_512x512@2x.png
EOF

  iconutil -c icns "$iconset_dir" -o "$resources_dir/$icon_name.icns"
  rm -rf "$tmp_dir"
}

stage_cli_installer() {
  local staging_dir="$1"
  local cli_source="$FE_MAC_DIR/tsuki"
  local cli_copy_path="$staging_dir/tsuki"
  local installer_path="$staging_dir/Install Tsuki CLI.command"

  if [[ ! -f "$cli_source" ]]; then
    log_warn "CLI script not found at $cli_source; skipping CLI installer in dmg"
    return
  fi

  cp "$cli_source" "$cli_copy_path"
  chmod +x "$cli_copy_path"

  cat >"$installer_path" <<'EOF'
#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_CLI="$SCRIPT_DIR/tsuki"
TARGET_DIR="/usr/local/bin"
TARGET_CLI="$TARGET_DIR/tsuki"

if [[ ! -f "$SOURCE_CLI" ]]; then
  echo "Error: bundled tsuki script not found at $SOURCE_CLI" >&2
  exit 1
fi

if [[ ! -d "$TARGET_DIR" ]]; then
  echo "Creating $TARGET_DIR ..."
  sudo mkdir -p "$TARGET_DIR"
fi

if [[ -w "$TARGET_DIR" ]]; then
  install -m 755 "$SOURCE_CLI" "$TARGET_CLI"
else
  echo "Installing to $TARGET_CLI requires administrator permission..."
  sudo install -m 755 "$SOURCE_CLI" "$TARGET_CLI"
fi

echo "Installed CLI: $TARGET_CLI"
echo "Usage: tsuki \"text to translate\""
EOF

  chmod +x "$installer_path"
}

confirm_package_version() {
  local short_version="$1"
  local bundle_version="$2"
  local artifact_dmg="$3"
  local answer

  log_section "Package Configuration"
  printf "  %-10s %s\n" "Version:" "$short_version"
  printf "  %-10s %s\n" "Build:" "$bundle_version"
  printf "  %-10s %s\n" "Artifact:" "$artifact_dmg"

  read -r -p "Proceed with packaging? [y/N] " answer
  case "$answer" in
    y|Y|yes|YES)
      ;;
    *)
      log_warn "Packaging cancelled."
      exit 0
      ;;
  esac
}

sign_app_bundle() {
  local target_app_dir="$1"

  if ! command -v codesign >/dev/null 2>&1; then
    log_error "codesign is required for packaging"
    exit 1
  fi

  codesign --force --deep --sign - "$target_app_dir"
}

update_dev_defaults_after_package() {
  local packaged_version="$1"
  local packaged_build="$2"
  local script_path="$ROOT_DIR/tsuki.sh"
  local dev_version="${packaged_version}-dev"
  local dev_build="${packaged_build}"

  python3 - "$script_path" "$dev_version" "$dev_build" <<'PY'
import pathlib
import re
import sys

script_path = pathlib.Path(sys.argv[1])
dev_version = sys.argv[2]
dev_build = sys.argv[3]

text = script_path.read_text(encoding="utf-8")
text = re.sub(
    r'^TSUKI_DEFAULT_VERSION_DEV="[^"]*"$',
    f'TSUKI_DEFAULT_VERSION_DEV="{dev_version}"',
    text,
    count=1,
    flags=re.MULTILINE,
)
text = re.sub(
    r'^TSUKI_DEFAULT_BUILD_DEV="[^"]*"$',
    f'TSUKI_DEFAULT_BUILD_DEV="{dev_build}"',
    text,
    count=1,
    flags=re.MULTILINE,
)
script_path.write_text(text, encoding="utf-8")
PY

  log_success "Updated dev defaults: TSUKI_DEFAULT_VERSION_DEV=\"$dev_version\", TSUKI_DEFAULT_BUILD_DEV=\"$dev_build\""
}

release_tag_name() {
  local short_version="$1"
  printf 'v%s' "$short_version"
}

maybe_commit_and_tag_after_package() {
  local short_version="$1"
  local tag_name
  local answer

  tag_name="$(release_tag_name "$short_version")"

  log_section "Packaging Finished"
  read -r -p "Create git commit and tag $tag_name now? [y/N] " answer
  case "$answer" in
    y|Y|yes|YES)
      ;;
    *)
      log_info "Skipped git commit/tag."
      return
      ;;
  esac

  if ! command -v git >/dev/null 2>&1; then
    log_warn "git not found; skipped commit/tag."
    return
  fi

  if ! git -C "$ROOT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    log_warn "not a git repository; skipped commit/tag."
    return
  fi

  if git -C "$ROOT_DIR" rev-parse -q --verify "refs/tags/$tag_name" >/dev/null 2>&1; then
    log_error "Tag already exists: $tag_name"
    log_error "Aborted: duplicate tag detected. Please bump version/build and package again."
    return 1
  fi

  if git -C "$ROOT_DIR" diff --cached --quiet; then
    if ! git -C "$ROOT_DIR" diff --quiet -- "$ROOT_DIR/tsuki.sh"; then
      git -C "$ROOT_DIR" add "$ROOT_DIR/tsuki.sh"
    fi
  fi

  if git -C "$ROOT_DIR" diff --cached --quiet; then
    log_info "No staged changes found. Tagging current HEAD."
  else
    git -C "$ROOT_DIR" commit -m "release: $tag_name"
  fi

  git -C "$ROOT_DIR" tag "$tag_name"
  log_success "Created tag: $tag_name"
}

run_fe() {
  local action="${1:-run}"
  local app_name="Tsuki"
  local app_dir="$ROOT_DIR/dist/${app_name}.app"

  stop_fe_processes() {
    local stopped=0
    pkill -f "$FE_MAC_DIR/.build/arm64-apple-macosx/debug/TsukiApp" >/dev/null 2>&1 && stopped=1 || true
    pkill -f "$app_dir/Contents/MacOS/$app_name" >/dev/null 2>&1 && stopped=1 || true
    return "$stopped"
  }

  if [[ ! -f "$FE_MAC_DIR/Package.swift" ]]; then
    log_error "Missing frontend package file at $FE_MAC_DIR/Package.swift"
    exit 1
  fi

  case "$action" in
    run)
      local logs_dir="$HOME/Library/Logs/tsuki"
      local timestamp
      local app_log_path
      local bin_dir
      local executable_path

      timestamp="$(date +"%Y%m%d-%H%M%S")"
      mkdir -p "$logs_dir"
      app_log_path="$logs_dir/tsuki-app-${timestamp}.log"

      {
        stop_fe_processes || true

        swift build --package-path "$FE_MAC_DIR"
        bin_dir="$(swift build --package-path "$FE_MAC_DIR" --show-bin-path)"
        executable_path="$bin_dir/TsukiApp"

        if [[ ! -x "$executable_path" ]]; then
          log_error "Missing debug executable at $executable_path"
          exit 1
        fi

        rm -rf "$app_dir"
        mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
        cp "$executable_path" "$app_dir/Contents/MacOS/$app_name"
        chmod +x "$app_dir/Contents/MacOS/$app_name"
        write_info_plist "$app_dir" "$app_name" "com.tsuki.app.debug" "$TSUKI_DEFAULT_VERSION_DEV" "$TSUKI_DEFAULT_BUILD_DEV"
        copy_app_icon "$app_dir"

        open -na "$app_dir" --args --run-id "$timestamp"
        log_success "TsukiApp launched via app bundle: $app_dir"
      } 2>&1 | tee -a "$app_log_path"

      log_info "Log saved: $app_log_path"
      ;;
    stop)
      if stop_fe_processes; then
        log_info "TsukiApp is not running"
      else
        log_success "TsukiApp stopped"
      fi
      ;;
    build)
      swift build --package-path "$FE_MAC_DIR"
      ;;
    test)
      swift test --package-path "$FE_MAC_DIR"
      ;;
    clean)
      rm -rf "$FE_MAC_DIR/.build"
      log_success "Frontend build cache cleaned: $FE_MAC_DIR/.build"
      ;;
    package)
      local bin_dir
      local executable_path
      local short_version
      local bundle_version
      local version_suffix
      local packaged_dmg_path
      local tmp_pkg_dir
      local temp_app_dir
      local dmg_staging_dir

      short_version="$TSUKI_DEFAULT_VERSION"
      bundle_version="$TSUKI_DEFAULT_BUILD"
      version_suffix="${short_version//[^[:alnum:]._-]/-}"

      if [[ -z "$version_suffix" ]]; then
        log_error "Invalid version value: $short_version"
        exit 1
      fi

      packaged_dmg_path="$ROOT_DIR/dist/${app_name}-${version_suffix}-build-${bundle_version}.dmg"
      mkdir -p "$ROOT_DIR/dist"

      confirm_package_version "$short_version" "$bundle_version" "$packaged_dmg_path"

      swift build --configuration release --package-path "$FE_MAC_DIR"
      bin_dir="$(swift build --configuration release --package-path "$FE_MAC_DIR" --show-bin-path)"
      executable_path="$bin_dir/TsukiApp"

      if [[ ! -x "$executable_path" ]]; then
        log_error "Missing release executable at $executable_path"
        exit 1
      fi

      rm -f "$packaged_dmg_path"

      tmp_pkg_dir="$(mktemp -d "/tmp/tsuki-package.XXXXXX")"
      trap 'rm -rf "$tmp_pkg_dir"' RETURN
      temp_app_dir="$tmp_pkg_dir/${app_name}.app"
      dmg_staging_dir="$tmp_pkg_dir/stage"

      mkdir -p "$temp_app_dir/Contents/MacOS" "$temp_app_dir/Contents/Resources"

      cp "$executable_path" "$temp_app_dir/Contents/MacOS/$app_name"
      chmod +x "$temp_app_dir/Contents/MacOS/$app_name"
      write_info_plist "$temp_app_dir" "$app_name" "com.tsuki.app" "$short_version" "$bundle_version"
      copy_app_icon "$temp_app_dir"
      sign_app_bundle "$temp_app_dir"

      mkdir -p "$dmg_staging_dir"
      cp -R "$temp_app_dir" "$dmg_staging_dir/${app_name}.app"
      ln -s /Applications "$dmg_staging_dir/Applications"
      stage_cli_installer "$dmg_staging_dir"

      hdiutil create -volname "Tsuki ${short_version}" -srcfolder "$dmg_staging_dir" -format UDZO -ov "$packaged_dmg_path" >/dev/null
      codesign --force --sign - "$packaged_dmg_path"

      rm -rf "$tmp_pkg_dir"
      trap - RETURN

      log_success "Packaged dmg: $packaged_dmg_path"
      update_dev_defaults_after_package "$short_version" "$bundle_version"
      maybe_commit_and_tag_after_package "$short_version" "$bundle_version"
      open "$ROOT_DIR/dist"
      ;;
    *)
      log_error "Unknown frontend action: $action"
      print_usage
      exit 1
      ;;
  esac
}

run_be_start() {
  if [[ ! -d "$BE_DIR" ]]; then
    log_error "Backend directory not found: $BE_DIR"
    exit 1
  fi

  if [[ -x "$BE_DIR/start.sh" ]]; then
    (cd "$BE_DIR" && ./start.sh)
    return
  fi

  if [[ -f "$BE_DIR/package.json" ]]; then
    if command -v npm >/dev/null 2>&1; then
      (cd "$BE_DIR" && npm run dev)
      return
    fi
    log_error "npm is required to start backend from package.json"
    exit 1
  fi

  if [[ -f "$BE_DIR/requirements.txt" ]]; then
    if command -v python3 >/dev/null 2>&1; then
      log_error "Backend Python environment detected. No default start command configured."
      log_info "Try: ./tsuki.sh be python3 app.py"
      exit 1
    fi
  fi

  log_error "Could not auto-detect backend start command in $BE_DIR"
  log_info "Use a custom command, e.g.: ./tsuki.sh be npm run dev"
  exit 1
}

run_be_custom() {
  if [[ ! -d "$BE_DIR" ]]; then
    log_error "Backend directory not found: $BE_DIR"
    exit 1
  fi

  if [[ $# -eq 0 ]]; then
    log_error "Missing backend command"
    print_usage
    exit 1
  fi

  (cd "$BE_DIR" && "$@")
}

main() {
  if [[ $# -eq 0 ]]; then
    run_fe run
    return
  fi

  case "$1" in
    start)
      run_fe run
      ;;
    fe)
      shift
      run_fe "${1:-run}"
      ;;
    be)
      shift
      if [[ "${1:-}" == "start" ]]; then
        shift
        run_be_start
      else
        run_be_custom "$@"
      fi
      ;;
    -h|--help|help)
      print_usage
      ;;
    *)
      log_error "Unknown command: $1"
      print_usage
      exit 1
      ;;
  esac
}

main "$@"
