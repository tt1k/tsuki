#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
FE_MAC_DIR="$ROOT_DIR/code/fe/macos"
FE_WEB_DIR="$ROOT_DIR/code/fe/web"
BE_DIR="$ROOT_DIR/code/be"
JMDICT_DB_PATH="$ROOT_DIR/code/db/jmdict/data/jmdict.sqlite3"
LOCAL_DICTIONARY_DB_PATH="$ROOT_DIR/code/db/ipadict/result/tsuki.sqlite3"

TSUKI_DEFAULT_VERSION="0.0.3"
TSUKI_DEFAULT_VERSION_DEV="0.0.3-dev"
TSUKI_WEB_PORT="5199"
TSUKI_DMG_WINDOW_LEFT="100"
TSUKI_DMG_WINDOW_TOP="100"
TSUKI_DMG_DEFAULT_CANVAS_WIDTH="660"
TSUKI_DMG_DEFAULT_CANVAS_HEIGHT="400"
TSUKI_DMG_ICON_SIZE="180"
TSUKI_DMG_TEXT_SIZE="13"
TSUKI_DMG_POS_APP_X="330"
TSUKI_DMG_POS_APP_Y="245"

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
  ./tsuki.sh be <run|stop|clean>
  ./tsuki.sh -h|--help|help

Commands:
  (no args)            Show help
  fe mac run           Run TsukiApp (macOS)
  fe mac stop          Stop TsukiApp (macOS)
  fe mac build         Build TsukiApp (macOS)
  fe mac clean         Clean frontend build cache (macOS)
  fe mac package       Build signed versioned .dmg variants in build/ (macOS)
  fe web run           Run web frontend dev server in background
  fe web stop          Stop web frontend dev server
  fe web status        Show web frontend dev server status
  be run               Run backend service in background
  be stop              Stop current backend service
  be clean             Clean backend build cache
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

copy_jmdict_database() {
  local target_app_dir="$1"
  local resources_dir="$target_app_dir/Contents/Resources"
  local target_db="$resources_dir/jmdict.sqlite3"

  if [[ ! -f "$JMDICT_DB_PATH" ]]; then
    log_warn "JMdict database not found at $JMDICT_DB_PATH"
    return 1
  fi

  mkdir -p "$resources_dir"
  cp "$JMDICT_DB_PATH" "$target_db"
  log_info "Bundled JMdict database: $target_db"
}

copy_local_dictionary_database() {
  local target_app_dir="$1"
  local resources_dir="$target_app_dir/Contents/Resources"
  local target_db="$resources_dir/tsuki.sqlite3"

  if [[ ! -f "$LOCAL_DICTIONARY_DB_PATH" ]]; then
    log_warn "Local dictionary database not found at $LOCAL_DICTIONARY_DB_PATH"
    return 1
  fi

  mkdir -p "$resources_dir"
  cp "$LOCAL_DICTIONARY_DB_PATH" "$target_db"
  log_info "Bundled local dictionary database: $target_db"
}

copy_cli_to_app_resources() {
  local target_app_dir="$1"
  local cli_source="$FE_MAC_DIR/tsuki"
  local resources_dir="$target_app_dir/Contents/Resources"
  local target_cli="$resources_dir/tsuki"

  if [[ ! -f "$cli_source" ]]; then
    log_warn "CLI script not found at $cli_source; skipping bundled recap installer resource"
    return
  fi

  mkdir -p "$resources_dir"
  cp "$cli_source" "$target_cli"
  chmod +x "$target_cli"
  log_info "Bundled recap CLI resource: $target_cli"
}

install_system_cli() {
  local cli_source="$FE_MAC_DIR/tsuki"
  local target_dir="/usr/local/bin"
  local target_cli="$target_dir/tsuki"

  if [[ ! -f "$cli_source" ]]; then
    log_warn "CLI script not found at $cli_source; skipped system CLI update"
    return
  fi

  if [[ ! -d "$target_dir" ]]; then
    log_info "Creating $target_dir ..."
    sudo mkdir -p "$target_dir"
  fi

  if [[ -w "$target_dir" ]]; then
    install -m 755 "$cli_source" "$target_cli"
  else
    log_info "Updating system CLI at $target_cli (requires admin permission)..."
    sudo install -m 755 "$cli_source" "$target_cli"
  fi

  log_success "Updated system CLI: $target_cli"
}

stage_dmg_background_assets() {
  local staging_dir="$1"
  local app_name="$2"
  local png_template="$ROOT_DIR/background.png"
  local svg_template="$ROOT_DIR/background.svg"
  local background_template
  local background_dir="$staging_dir/.background"
  local background_tiff="$background_dir/background.tiff"
  local tmp_background_dir
  local tmp_background_tiff
  local app_icon_name="${app_name}.app"
  local osa_output
  local canvas_width
  local canvas_height
  local window_width
  local window_height
  local bg_pixel_width
  local bg_pixel_height

  if [[ -f "$png_template" ]]; then
    background_template="$png_template"
    read -r canvas_width canvas_height < <(sips -g pixelWidth -g pixelHeight "$background_template" 2>/dev/null | awk '/pixelWidth:/ {w=$2} /pixelHeight:/ {h=$2} END {print w, h}')
  else
    background_template="$svg_template"
    read -r canvas_width canvas_height < <(python3 - "$background_template" "$TSUKI_DMG_DEFAULT_CANVAS_WIDTH" "$TSUKI_DMG_DEFAULT_CANVAS_HEIGHT" <<'PY'
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
  fi

  if [[ -z "${canvas_width:-}" || -z "${canvas_height:-}" ]]; then
    canvas_width="$TSUKI_DMG_DEFAULT_CANVAS_WIDTH"
    canvas_height="$TSUKI_DMG_DEFAULT_CANVAS_HEIGHT"
  fi

  window_width="$canvas_width"
  window_height=$((canvas_height + 22))
  bg_pixel_width="$canvas_width"
  bg_pixel_height="$canvas_height"

  log_info "DMG canvas ${canvas_width}x${canvas_height}, window ${window_width}x${window_height}, bg ${bg_pixel_width}x${bg_pixel_height}"

  if [[ ! -f "$background_template" ]]; then
    log_warn "DMG background template not found at $background_template; using plain packaging"
    return
  fi

  if ! command -v sips >/dev/null 2>&1; then
    log_warn "sips not found; skipped DMG background generation"
    return
  fi

  mkdir -p "$background_dir"
  tmp_background_dir="$(mktemp -d "/tmp/tsuki-bg.XXXXXX")"
  tmp_background_tiff="$tmp_background_dir/background.tiff"

  if ! sips -s format tiff -z "$bg_pixel_height" "$bg_pixel_width" "$background_template" --out "$tmp_background_tiff" >/dev/null; then
    rm -rf "$tmp_background_dir"
    log_warn "Failed to generate .background.tiff from $background_template"
    return
  fi

  cp "$tmp_background_tiff" "$background_tiff"
  rm -rf "$tmp_background_dir"

  if ! command -v osascript >/dev/null 2>&1; then
    log_warn "osascript not found; generated background image but skipped Finder layout"
    return
  fi

  if ! osa_output="$(osascript - "$staging_dir" "$app_icon_name" "$TSUKI_DMG_WINDOW_LEFT" "$TSUKI_DMG_WINDOW_TOP" "$window_width" "$window_height" "$TSUKI_DMG_ICON_SIZE" "$TSUKI_DMG_TEXT_SIZE" "$TSUKI_DMG_POS_APP_X" "$TSUKI_DMG_POS_APP_Y" <<'APPLESCRIPT' 2>&1
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

  log_info "Applied DMG background and Finder layout from background asset"
}

stage_dmg_volume_icon() {
  local mount_point="$1"
  local app_name="$2"
  local app_icon="$mount_point/${app_name}.app/Contents/Resources/${app_name}.icns"
  local volume_icon="$mount_point/.VolumeIcon.icns"

  if [[ ! -f "$app_icon" ]]; then
    log_warn "App icon not found at $app_icon; skipped DMG volume icon"
    return
  fi

  cp "$app_icon" "$volume_icon"
  if command -v SetFile >/dev/null 2>&1; then
    SetFile -a C "$mount_point"
  else
    log_warn "SetFile not found; copied volume icon but custom icon flag was not set"
  fi
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

build_mac_dmg_variant() {
  local app_name="$1"
  local short_version="$2"
  local version_suffix="$3"
  local executable_path="$4"
  local packaged_dmg_path="$5"
  local include_jmdict_db="$6"
  local tmp_pkg_dir
  local temp_app_dir
  local dmg_staging_dir
  local rw_dmg_path
  local mount_point

  tmp_pkg_dir="$(mktemp -d "/tmp/tsuki-package.XXXXXX")"
  trap 'rm -rf "$tmp_pkg_dir"' RETURN
  temp_app_dir="$tmp_pkg_dir/${app_name}.app"
  dmg_staging_dir="$tmp_pkg_dir/stage"

  mkdir -p "$temp_app_dir/Contents/MacOS" "$temp_app_dir/Contents/Resources"

  cp "$executable_path" "$temp_app_dir/Contents/MacOS/$app_name"
  chmod +x "$temp_app_dir/Contents/MacOS/$app_name"
  write_info_plist "$temp_app_dir" "$app_name" "com.tsuki.app" "$short_version" "$short_version"
  copy_app_icon "$temp_app_dir"
  copy_cli_to_app_resources "$temp_app_dir"

  if [[ "$include_jmdict_db" == "1" ]]; then
    if ! copy_jmdict_database "$temp_app_dir"; then
      rm -rf "$tmp_pkg_dir"
      log_error "Cannot build DB bundle without $JMDICT_DB_PATH"
      exit 1
    fi
    if ! copy_local_dictionary_database "$temp_app_dir"; then
      rm -rf "$tmp_pkg_dir"
      log_error "Cannot build DB bundle without $LOCAL_DICTIONARY_DB_PATH"
      exit 1
    fi
  fi

  sign_app_bundle "$temp_app_dir"

  mkdir -p "$dmg_staging_dir"
  cp -R "$temp_app_dir" "$dmg_staging_dir/${app_name}.app"

  rw_dmg_path="$tmp_pkg_dir/Tsuki-${version_suffix}.rw.dmg"
  mount_point="$tmp_pkg_dir/mount"

  local dmg_size="128m"
  if [[ "$include_jmdict_db" == "1" ]]; then
    dmg_size="768m"
  fi

  hdiutil create -volname "Tsuki Installer" -srcfolder "$dmg_staging_dir" -fs HFS+ -size "$dmg_size" -format UDRW -ov "$rw_dmg_path" >/dev/null
  mkdir -p "$mount_point"
  hdiutil attach -nobrowse -readwrite -mountpoint "$mount_point" "$rw_dmg_path" >/dev/null

  stage_dmg_volume_icon "$mount_point" "$app_name"
  stage_dmg_background_assets "$mount_point" "$app_name"

  hdiutil detach "$mount_point" >/dev/null

  hdiutil convert "$rw_dmg_path" -format UDZO -o "$packaged_dmg_path" >/dev/null
  codesign --force --sign - "$packaged_dmg_path"

  rm -rf "$tmp_pkg_dir"
  trap - RETURN
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
      local logs_dir="$HOME/Library/Logs/tsuki/logs"
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
        copy_cli_to_app_resources "$app_dir"
        copy_jmdict_database "$app_dir" || true
        copy_local_dictionary_database "$app_dir" || true

        open -na "$app_dir" --args --run-id "$timestamp"
        log_success "TsukiApp launched via app bundle: $app_dir"
      } 2>&1 | tee -a "$app_log_path"

      install_system_cli
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
      local packaged_lite_dmg_path

      short_version="$TSUKI_DEFAULT_VERSION"
      version_suffix="${short_version//[^[:alnum:]._-]/-}"

      if [[ -z "$version_suffix" ]]; then
        log_error "Invalid version value: $short_version"
        exit 1
      fi

      packaged_dmg_path="$ROOT_DIR/build/${app_name}-${version_suffix}.dmg"
      packaged_lite_dmg_path="$ROOT_DIR/build/${app_name}-${version_suffix}-Lite.dmg"
      mkdir -p "$ROOT_DIR/build"

      confirm_package_version "$short_version" "$packaged_lite_dmg_path, $packaged_dmg_path"

      swift build --configuration release --package-path "$FE_MAC_DIR"
      bin_dir="$(swift build --configuration release --package-path "$FE_MAC_DIR" --show-bin-path)"
      executable_path="$bin_dir/TsukiApp"

      if [[ ! -x "$executable_path" ]]; then
        log_error "Missing release executable at $executable_path"
        exit 1
      fi

      rm -f "$packaged_dmg_path"
      rm -f "$packaged_lite_dmg_path"

      build_mac_dmg_variant "$app_name" "$short_version" "${version_suffix}-Lite" "$executable_path" "$packaged_lite_dmg_path" "0"
      build_mac_dmg_variant "$app_name" "$short_version" "$version_suffix" "$executable_path" "$packaged_dmg_path" "1"

      log_success "Packaged dmg: $packaged_lite_dmg_path"
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
  local web_logs_dir="$logs_dir/logs"
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

run_be() {
  local action="${1:-run}"
  local be_app_dir="$BE_DIR/bg-tsuki"
  local be_logs_dir="$be_app_dir/.tsuki"
  local pid_file="$be_logs_dir/tsuki-be.pid"
  local log_file="$be_logs_dir/tsuki-be.log"
  local be_port="5188"
  local ready_timeout_secs="60"
  local poll_interval_secs="0.5"
  local port_release_timeout_secs="12"
  local pid

  if [[ ! -f "$be_app_dir/gradlew" ]]; then
    log_error "Missing backend runner at $be_app_dir/gradlew"
    exit 1
  fi

  is_be_running() {
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

  is_be_port_in_use() {
    lsof -nP -iTCP:"$be_port" -sTCP:LISTEN >/dev/null 2>&1
  }

  wait_be_port_release() {
    local waited="0"
    local sleep_secs="0.2"
    local max_steps=$((port_release_timeout_secs * 5))

    for ((step=1; step<=max_steps; step++)); do
      if ! is_be_port_in_use; then
        return 0
      fi
      sleep "$sleep_secs"
      waited=$((waited + 1))
    done

    return 1
  }

  print_be_port_owners() {
    lsof -nP -iTCP:"$be_port" -sTCP:LISTEN || true
  }

  case "$action" in
    run)
      mkdir -p "$be_logs_dir"

      if is_be_running; then
        log_warn "Backend is already running (pid: $pid); stopping it before restart"
        kill "$pid" >/dev/null 2>&1 || true

        for _ in 1 2 3 4 5; do
          if kill -0 "$pid" >/dev/null 2>&1; then
            sleep 0.2
          else
            break
          fi
        done

        if kill -0 "$pid" >/dev/null 2>&1; then
          log_warn "Backend did not stop gracefully; force killing (pid: $pid)"
          kill -9 "$pid" >/dev/null 2>&1 || true
        fi

        rm -f "$pid_file"
        log_info "Previous backend process stopped"
      fi

      if is_be_port_in_use; then
        log_warn "Backend port $be_port is still in use; waiting for release..."
        if ! wait_be_port_release; then
          log_error "Port $be_port is still occupied after ${port_release_timeout_secs}s"
          print_be_port_owners
          log_error "Please stop the process above, then retry ./tsuki.sh be run"
          exit 1
        fi
      fi

      rm -f "$pid_file"
      (
        cd "$be_app_dir"
        nohup ./gradlew :tsuki-api:bootRun >"$log_file" 2>&1 &
        echo $! >"$pid_file"
      )

      if ! is_be_running; then
        log_error "Failed to start backend. Check logs: $log_file"
        exit 1
      fi

      log_info "Backend process started (pid: $pid), waiting for ready..."
      local elapsed="0"
      local total_steps=$((ready_timeout_secs * 2))

      for ((step=1; step<=total_steps; step++)); do
        if ! kill -0 "$pid" >/dev/null 2>&1; then
          rm -f "$pid_file"
          log_error "Backend process exited before ready. Check logs: $log_file"
          exit 1
        fi

        if [[ -f "$log_file" ]]; then
          if grep -q "Tomcat started on port" "$log_file" && grep -q "Started .* in .* seconds" "$log_file"; then
            log_success "Backend is ready (pid: $pid)"
            log_info "Logs: $log_file"
            return
          fi
        fi

        sleep "$poll_interval_secs"
        elapsed=$((elapsed + 1))
      done

      log_error "Backend did not become ready within ${ready_timeout_secs}s. Check logs: $log_file"
      exit 1
      ;;
    stop)
      if ! is_be_running; then
        rm -f "$pid_file"
        log_info "Backend is not running"
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

      if is_be_port_in_use; then
        if ! wait_be_port_release; then
          rm -f "$pid_file"
          log_warn "Backend process stopped, but port $be_port is still occupied"
          print_be_port_owners
          return
        fi
      fi

      rm -f "$pid_file"
      if kill -0 "$pid" >/dev/null 2>&1; then
        log_warn "Backend stop requested, but process still exists (pid: $pid)"
      else
        log_success "Backend stopped"
      fi
      ;;
    clean)
      log_section "Cleaning Backend Cache"
      (
        cd "$be_app_dir"
        ./gradlew clean
      )
      log_success "Backend build cache cleaned"
      ;;
    *)
      log_error "Unknown backend action: $action"
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
    be)
      shift
      run_be "${1:-run}"
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
