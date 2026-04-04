#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
FE_DIR="$ROOT_DIR/code/FE"
BE_DIR="$ROOT_DIR/code/BE"

print_usage() {
  cat <<'EOF'
Usage:
  ./tsuki.sh start                Start frontend app (default)
  ./tsuki.sh fe run               Run TsukiApp
  ./tsuki.sh fe build             Build TsukiApp
  ./tsuki.sh fe test              Run frontend tests
  ./tsuki.sh fe clean             Clean frontend build cache
  ./tsuki.sh be start             Start backend service (auto-detect)
  ./tsuki.sh be <command...>      Run custom command inside code/BE

Examples:
  ./tsuki.sh
  ./tsuki.sh fe run
  ./tsuki.sh fe clean
  ./tsuki.sh be start
  ./tsuki.sh be npm run dev
EOF
}

run_fe() {
  local action="${1:-run}"

  if [[ ! -f "$FE_DIR/Package.swift" ]]; then
    echo "Error: missing frontend package file at $FE_DIR/Package.swift" >&2
    exit 1
  fi

  case "$action" in
    run)
      swift run --package-path "$FE_DIR" TsukiApp
      ;;
    build)
      swift build --package-path "$FE_DIR"
      ;;
    test)
      swift test --package-path "$FE_DIR"
      ;;
    clean)
      rm -rf "$FE_DIR/.build"
      echo "Frontend build cache cleaned: $FE_DIR/.build"
      ;;
    *)
      echo "Error: unknown frontend action: $action" >&2
      print_usage
      exit 1
      ;;
  esac
}

run_be_start() {
  if [[ ! -d "$BE_DIR" ]]; then
    echo "Error: backend directory not found: $BE_DIR" >&2
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
    echo "Error: npm is required to start backend from package.json" >&2
    exit 1
  fi

  if [[ -f "$BE_DIR/requirements.txt" ]]; then
    if command -v python3 >/dev/null 2>&1; then
      echo "Backend Python environment detected. No default start command configured." >&2
      echo "Try: ./tsuki.sh be python3 app.py" >&2
      exit 1
    fi
  fi

  echo "Error: could not auto-detect backend start command in $BE_DIR" >&2
  echo "Use a custom command, e.g.: ./tsuki.sh be npm run dev" >&2
  exit 1
}

run_be_custom() {
  if [[ ! -d "$BE_DIR" ]]; then
    echo "Error: backend directory not found: $BE_DIR" >&2
    exit 1
  fi

  if [[ $# -eq 0 ]]; then
    echo "Error: missing backend command" >&2
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
      echo "Error: unknown command: $1" >&2
      print_usage
      exit 1
      ;;
  esac
}

main "$@"
