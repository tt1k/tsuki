#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
FE_MAC_DIR="$ROOT_DIR/code/fe/macos"
FE_WEB_DIR="$ROOT_DIR/code/fe/web"
BE_DIR="$ROOT_DIR/code/be"

TSUKI_DEFAULT_VERSION="0.0.2"
TSUKI_DEFAULT_VERSION_DEV="0.0.2-dev"
TSUKI_WEB_PORT="5199"
TSUKI_DMG_WINDOW_LEFT="120"
TSUKI_DMG_WINDOW_TOP="120"
TSUKI_DMG_DEFAULT_CANVAS_WIDTH="660"
TSUKI_DMG_DEFAULT_CANVAS_HEIGHT="460"
TSUKI_DMG_ICON_SIZE="84"
TSUKI_DMG_TEXT_SIZE="10"
TSUKI_DMG_POS_APP_X="200"
TSUKI_DMG_POS_APP_Y="210"
TSUKI_DMG_POS_APPLICATIONS_X="460"
TSUKI_DMG_POS_APPLICATIONS_Y="210"
TSUKI_DMG_POS_CLI_X="200"
TSUKI_DMG_POS_CLI_Y="370"
TSUKI_DMG_POS_INSTALLER_X="460"
TSUKI_DMG_POS_INSTALLER_Y="370"

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
  ./tsuki.sh
  ./tsuki.sh fe web <run|stop|status>
  ./tsuki.sh fe mac <run|stop|build|clean|package>
  ./tsuki.sh -h|--help|help

Commands:
  (no args)            Show help
  fe mac run           Run TsukiApp (macOS)
  fe mac stop          Stop TsukiApp (macOS)
  fe mac build         Build TsukiApp (macOS)
  fe mac clean         Clean frontend build cache (macOS)
  fe mac package       Build signed versioned .dmg in build/ (macOS)
  fe web run           Run web frontend dev server in background
  fe web stop          Stop web frontend dev server
  fe web status        Show web frontend dev server status
  -h, --help, help     Show help
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

stage_dmg_background_assets() {
  local staging_dir="$1"
  local app_name="$2"
  local svg_template="$ROOT_DIR/background.svg"
  local background_dir="$staging_dir/.background"
  local background_tiff="$background_dir/background.tiff"
  local tmp_background_dir
  local tmp_background_tiff
  local app_icon_name="${app_name}.app"
  local osa_output
  local svg_canvas_width
  local svg_canvas_height
  local window_width
  local window_height
  local bg_pixel_width
  local bg_pixel_height

  read -r svg_canvas_width svg_canvas_height < <(python3 - "$svg_template" "$TSUKI_DMG_DEFAULT_CANVAS_WIDTH" "$TSUKI_DMG_DEFAULT_CANVAS_HEIGHT" <<'PY'
import re
import sys
import xml.etree.ElementTree as ET

svg_path = sys.argv[1]
default_w = int(sys.argv[2])
default_h = int(sys.argv[3])

def parse_num(raw: str):
    if raw is None:
        return None
    m = re.match(r"\s*([0-9]+(?:\.[0-9]+)?)", raw)
    if not m:
        return None
    return float(m.group(1))

try:
    root = ET.parse(svg_path).getroot()
except Exception:
    print(default_w, default_h)
    raise SystemExit(0)

w = parse_num(root.get("width"))
h = parse_num(root.get("height"))

if w is None or h is None:
    vb = root.get("viewBox")
    if vb:
        parts = [p for p in vb.replace(",", " ").split() if p]
        if len(parts) == 4:
            try:
                w = float(parts[2])
                h = float(parts[3])
            except Exception:
                pass

if w is None or h is None or w <= 0 or h <= 0:
    w = default_w
    h = default_h

print(int(round(w)), int(round(h)))
PY
)

  window_width="$svg_canvas_width"
  window_height=$((svg_canvas_height + 24))
  bg_pixel_width="$svg_canvas_width"
  bg_pixel_height="$svg_canvas_height"

  log_info "DMG canvas ${svg_canvas_width}x${svg_canvas_height}, window ${window_width}x${window_height}, bg ${bg_pixel_width}x${bg_pixel_height}"

  if [[ ! -f "$svg_template" ]]; then
    log_warn "DMG background template not found at $svg_template; using plain packaging"
    return
  fi

  if ! command -v sips >/dev/null 2>&1; then
    log_warn "sips not found; skipped DMG background generation"
    return
  fi

  mkdir -p "$background_dir"
  tmp_background_dir="$(mktemp -d "/tmp/tsuki-bg.XXXXXX")"
  tmp_background_tiff="$tmp_background_dir/background.tiff"

  if ! sips -s format tiff -z "$bg_pixel_height" "$bg_pixel_width" "$svg_template" --out "$tmp_background_tiff" >/dev/null; then
    rm -rf "$tmp_background_dir"
    log_warn "Failed to generate .background.tiff from $svg_template"
    return
  fi

  cp "$tmp_background_tiff" "$background_tiff"
  rm -rf "$tmp_background_dir"

  if ! command -v osascript >/dev/null 2>&1; then
    log_warn "osascript not found; generated background image but skipped Finder layout"
    return
  fi

  if ! osa_output="$(osascript - "$staging_dir" "$app_icon_name" "$TSUKI_DMG_WINDOW_LEFT" "$TSUKI_DMG_WINDOW_TOP" "$window_width" "$window_height" "$TSUKI_DMG_ICON_SIZE" "$TSUKI_DMG_TEXT_SIZE" "$TSUKI_DMG_POS_APP_X" "$TSUKI_DMG_POS_APP_Y" "$TSUKI_DMG_POS_APPLICATIONS_X" "$TSUKI_DMG_POS_APPLICATIONS_Y" "$TSUKI_DMG_POS_CLI_X" "$TSUKI_DMG_POS_CLI_Y" "$TSUKI_DMG_POS_INSTALLER_X" "$TSUKI_DMG_POS_INSTALLER_Y" <<'APPLESCRIPT' 2>&1
on run argv
  set stagingPosixPath to item 1 of argv
  set appBundleName to item 2 of argv
  set windowLeft to (item 3 of argv) as integer
  set windowTop to (item 4 of argv) as integer
  set windowWidth to (item 5 of argv) as integer
  set windowHeight to (item 6 of argv) as integer
  set iconSizeValue to (item 7 of argv) as integer
  set textSizeValue to (item 8 of argv) as integer
  set appPosX to (item 9 of argv) as integer
  set appPosY to (item 10 of argv) as integer
  set applicationsPosX to (item 11 of argv) as integer
  set applicationsPosY to (item 12 of argv) as integer
  set cliPosX to (item 13 of argv) as integer
  set cliPosY to (item 14 of argv) as integer
  set installerPosX to (item 15 of argv) as integer
  set installerPosY to (item 16 of argv) as integer
  set backgroundAlias to POSIX file (stagingPosixPath & "/.background/background.tiff") as alias

  tell application "Finder"
    set dmgFolder to POSIX file stagingPosixPath as alias
    open dmgFolder
    delay 0.6

    set targetWindow to front Finder window
    set current view of targetWindow to icon view
    set toolbar visible of targetWindow to false
    set statusbar visible of targetWindow to false
    set sidebar width of targetWindow to 0
    set bounds of targetWindow to {windowLeft, windowTop, windowLeft + windowWidth, windowTop + windowHeight}

    set viewOptions to icon view options of targetWindow
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to iconSizeValue
    set text size of viewOptions to textSizeValue
    set background picture of viewOptions to backgroundAlias

    try
      set position of item appBundleName of dmgFolder to {appPosX, appPosY}
    end try
    try
      set position of item "Applications" of dmgFolder to {applicationsPosX, applicationsPosY}
    end try
    try
      set position of item "tsuki" of dmgFolder to {cliPosX, cliPosY}
    end try
    try
      set position of item "Install Tsuki CLI.command" of dmgFolder to {installerPosX, installerPosY}
    end try

    close targetWindow
  end tell
end run
APPLESCRIPT
)"; then
    log_warn "Failed to apply Finder window layout; DMG may miss fixed icon positions"
    if [[ -n "$osa_output" ]]; then
      log_warn "osascript: $osa_output"
    fi
    return
  fi

  log_info "Applied DMG background and Finder layout from background.svg"
}

confirm_package_version() {
  local short_version="$1"
  local artifact_dmg="$2"
  local answer

  log_section "Package Configuration"
  printf "  %-10s %s\n" "Version:" "$short_version"
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
  local script_path="$ROOT_DIR/tsuki.sh"
  local dev_version="${packaged_version}-dev"

  python3 - "$script_path" "$dev_version" <<'PY'
import pathlib
import re
import sys

script_path = pathlib.Path(sys.argv[1])
dev_version = sys.argv[2]

text = script_path.read_text(encoding="utf-8")
text = re.sub(
    r'^TSUKI_DEFAULT_VERSION_DEV="[^"]*"$',
    f'TSUKI_DEFAULT_VERSION_DEV="{dev_version}"',
    text,
    count=1,
    flags=re.MULTILINE,
)
script_path.write_text(text, encoding="utf-8")
PY

  log_success "Updated dev default: TSUKI_DEFAULT_VERSION_DEV=\"$dev_version\""
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
  read -r -p "Create git tag $tag_name now? [y/N] " answer
  case "$answer" in
    y|Y|yes|YES)
      ;;
    *)
      log_info "Skipped git tag."
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
    log_error "Aborted: duplicate tag detected. Please bump version and package again."
    return 1
  fi

  git -C "$ROOT_DIR" tag "$tag_name"
  log_success "Created tag: $tag_name"
}

run_fe() {
  local action="${1:-run}"
  local app_name="Tsuki"
  local app_dir="$ROOT_DIR/build/${app_name}.app"

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
        write_info_plist "$app_dir" "$app_name" "com.tsuki.app.debug" "$TSUKI_DEFAULT_VERSION_DEV" "$TSUKI_DEFAULT_VERSION_DEV"
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
    clean)
      rm -rf "$FE_MAC_DIR/.build"
      log_success "Frontend build cache cleaned: $FE_MAC_DIR/.build"
      ;;
    package)
      local bin_dir
      local executable_path
      local short_version
      local version_suffix
      local packaged_dmg_path
      local tmp_pkg_dir
      local temp_app_dir
      local dmg_staging_dir

      short_version="$TSUKI_DEFAULT_VERSION"
      version_suffix="${short_version//[^[:alnum:]._-]/-}"

      if [[ -z "$version_suffix" ]]; then
        log_error "Invalid version value: $short_version"
        exit 1
      fi

      packaged_dmg_path="$ROOT_DIR/build/${app_name}-${version_suffix}.dmg"
      mkdir -p "$ROOT_DIR/build"

      confirm_package_version "$short_version" "$packaged_dmg_path"

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
      write_info_plist "$temp_app_dir" "$app_name" "com.tsuki.app" "$short_version" "$short_version"
      copy_app_icon "$temp_app_dir"
      sign_app_bundle "$temp_app_dir"

      mkdir -p "$dmg_staging_dir"
      cp -R "$temp_app_dir" "$dmg_staging_dir/${app_name}.app"
      ln -s /Applications "$dmg_staging_dir/Applications"
      stage_cli_installer "$dmg_staging_dir"

      local rw_dmg_path
      local mount_point

      rw_dmg_path="$tmp_pkg_dir/Tsuki-${version_suffix}.rw.dmg"
      mount_point="$tmp_pkg_dir/mount"

      hdiutil create -volname "Tsuki ${short_version}" -srcfolder "$dmg_staging_dir" -fs HFS+ -size 128m -format UDRW -ov "$rw_dmg_path" >/dev/null
      mkdir -p "$mount_point"
      hdiutil attach -nobrowse -readwrite -mountpoint "$mount_point" "$rw_dmg_path" >/dev/null

      stage_dmg_background_assets "$mount_point" "$app_name"

      hdiutil detach "$mount_point" >/dev/null

      hdiutil convert "$rw_dmg_path" -format UDZO -o "$packaged_dmg_path" >/dev/null
      codesign --force --sign - "$packaged_dmg_path"

      rm -rf "$tmp_pkg_dir"
      trap - RETURN

      log_success "Packaged dmg: $packaged_dmg_path"
      update_dev_defaults_after_package "$short_version"
      maybe_commit_and_tag_after_package "$short_version"
      open "$ROOT_DIR/build"
      ;;
    *)
      log_error "Unknown frontend action: $action"
      print_usage
      exit 1
      ;;
  esac
}

run_fe_web() {
  local action="${1:-run}"
  local web_app_dir="$FE_WEB_DIR/tsuki-app"
  local logs_dir="$HOME/Library/Logs/tsuki"
  local web_logs_dir="$logs_dir/log"
  local pid_file="$web_logs_dir/tsuki-web.pid"
  local log_file="$web_logs_dir/tsuki-web.log"
  local pid

  if [[ ! -f "$web_app_dir/package.json" ]]; then
    log_error "Missing web package file at $web_app_dir/package.json"
    exit 1
  fi

  if ! command -v npm >/dev/null 2>&1; then
    log_error "npm is required for web frontend commands"
    exit 1
  fi

  is_web_running() {
    if [[ ! -f "$pid_file" ]]; then
      return 1
    fi

    pid="$(<"$pid_file")"
    if [[ -z "$pid" ]]; then
      return 1
    fi

    if kill -0 "$pid" >/dev/null 2>&1; then
      return 0
    fi

    return 1
  }

  case "$action" in
    run)
      mkdir -p "$web_logs_dir"

      if is_web_running; then
        log_info "Web frontend is already running (pid: $pid)"
        log_info "URL: http://localhost:${TSUKI_WEB_PORT}/"
        log_info "Logs: $log_file"
        return
      fi

      rm -f "$pid_file"
      (
        cd "$web_app_dir"
        nohup npm run dev -- --port "$TSUKI_WEB_PORT" --strictPort >"$log_file" 2>&1 &
        echo $! >"$pid_file"
      )

      if is_web_running; then
        log_success "Web frontend started in background (pid: $pid)"
        log_info "URL: http://localhost:${TSUKI_WEB_PORT}/"
        log_info "Logs: $log_file"
      else
        log_error "Failed to start web frontend. Check logs: $log_file"
        exit 1
      fi
      ;;
    stop)
      if ! is_web_running; then
        rm -f "$pid_file"
        log_info "Web frontend is not running"
        return
      fi

      kill "$pid" >/dev/null 2>&1 || true

      for _ in 1 2 3 4 5; do
        if kill -0 "$pid" >/dev/null 2>&1; then
          sleep 0.2
        else
          break
        fi
      done

      if kill -0 "$pid" >/dev/null 2>&1; then
        kill -9 "$pid" >/dev/null 2>&1 || true
      fi

      rm -f "$pid_file"
      log_success "Web frontend stopped"
      ;;
    status)
      if is_web_running; then
        log_success "Web frontend is running (pid: $pid)"
        log_info "URL: http://localhost:${TSUKI_WEB_PORT}/"
        log_info "Logs: $log_file"
      else
        rm -f "$pid_file"
        log_info "Web frontend is not running"
      fi
      ;;
    *)
      log_error "Unknown web action: $action"
      print_usage
      exit 1
      ;;
  esac
}

main() {
  if [[ $# -eq 0 ]]; then
    print_usage
    return
  fi

  case "$1" in
    fe)
      shift
      case "${1:-}" in
        web)
          shift
          run_fe_web "${1:-run}"
          ;;
        mac)
          shift
          run_fe "${1:-run}"
          ;;
        *)
          log_error "Unknown frontend target: ${1:-<empty>}"
          print_usage
          exit 1
          ;;
      esac
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
