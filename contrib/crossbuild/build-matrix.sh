#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

# shellcheck source=/dev/null
[ -f "$ROOT_DIR/contrib/crossbuild/targets.env" ] && source "$ROOT_DIR/contrib/crossbuild/targets.env"

LINUX_HOST="${LINUX_HOST:-x86_64-pc-linux-gnu}"
WINDOWS_HOST="${WINDOWS_HOST:-x86_64-w64-mingw32}"
BUILD_BASE_DIR="${BUILD_BASE_DIR:-$ROOT_DIR/out/build}"
ARTIFACTS_DIR="${ARTIFACTS_DIR:-$ROOT_DIR/out/artifacts}"
MAKE_JOBS="${MAKE_JOBS:-$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)}"
MAKE_DEPENDS_JOBS="${MAKE_DEPENDS_JOBS:-$MAKE_JOBS}"
RUN_AUTOGEN="${RUN_AUTOGEN:-1}"
CONFIGURE_FLAGS_COMMON="${CONFIGURE_FLAGS_COMMON:---enable-reduce-exports}"
CONFIGURE_FLAGS_LINUX="${CONFIGURE_FLAGS_LINUX:-}"
CONFIGURE_FLAGS_WINDOWS="${CONFIGURE_FLAGS_WINDOWS:-}"

print_usage() {
  cat <<USAGE
Usage: $(basename "$0") [linux|windows|all] [--skip-depends] [--skip-package]

Targets:
  linux      Build Linux binaries (qt + cli + tx + daemon)
  windows    Build Windows binaries (qt + cli + tx + daemon)
  all        Build both targets (default)

Environment overrides (optional):
  LINUX_HOST, WINDOWS_HOST
  BUILD_BASE_DIR, ARTIFACTS_DIR
  MAKE_JOBS, MAKE_DEPENDS_JOBS
  RUN_AUTOGEN=0|1
  CONFIGURE_FLAGS_COMMON
  CONFIGURE_FLAGS_LINUX
  CONFIGURE_FLAGS_WINDOWS

Tip:
  Put your default overrides into contrib/crossbuild/targets.env.
USAGE
}

build_target() {
  local target="$1"
  local host="$2"
  local extra_flags="$3"
  local skip_depends="$4"
  local skip_package="$5"

  local build_dir="$BUILD_BASE_DIR/$target"
  local install_dir="$ARTIFACTS_DIR/$target"
  local config_site="$ROOT_DIR/depends/$host/share/config.site"

  echo "==> [$target] host=$host"

  if [ "$skip_depends" -eq 0 ]; then
    echo "==> [$target] building depends"
    make -C "$ROOT_DIR/depends" -j"$MAKE_DEPENDS_JOBS" HOST="$host"
  else
    echo "==> [$target] skipping depends build"
  fi

  mkdir -p "$build_dir" "$install_dir"

  echo "==> [$target] configuring in $build_dir"
  (
    cd "$build_dir"
    CONFIG_SITE="$config_site" "$ROOT_DIR/configure" \
      --prefix=/ \
      $CONFIGURE_FLAGS_COMMON \
      $extra_flags
  )

  echo "==> [$target] compiling"
  make -C "$build_dir" -j"$MAKE_JOBS"

  echo "==> [$target] installing into $install_dir"
  rm -rf "$install_dir/root"
  make -C "$build_dir" install DESTDIR="$install_dir/root"

  if [ "$skip_package" -eq 0 ]; then
    mkdir -p "$install_dir"
    local stamp
    stamp="$(date -u +%Y%m%d-%H%M%S)"

    if [ "$target" = "windows" ] && command -v zip >/dev/null 2>&1; then
      echo "==> [$target] packaging zip"
      (
        cd "$install_dir/root"
        zip -qr "$install_dir/botcoin-${target}-${stamp}.zip" .
      )
    else
      echo "==> [$target] packaging tar.gz"
      tar -C "$install_dir/root" -czf "$install_dir/botcoin-${target}-${stamp}.tar.gz" .
    fi
  else
    echo "==> [$target] skipping packaging"
  fi
}

TARGET="all"
SKIP_DEPENDS=0
SKIP_PACKAGE=0

for arg in "$@"; do
  case "$arg" in
    linux|windows|all)
      TARGET="$arg"
      ;;
    --skip-depends)
      SKIP_DEPENDS=1
      ;;
    --skip-package)
      SKIP_PACKAGE=1
      ;;
    -h|--help)
      print_usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      print_usage
      exit 1
      ;;
  esac
done

if [ "$RUN_AUTOGEN" -eq 1 ]; then
  echo "==> running autogen"
  "$ROOT_DIR/autogen.sh"
fi

case "$TARGET" in
  linux)
    build_target linux "$LINUX_HOST" "$CONFIGURE_FLAGS_LINUX" "$SKIP_DEPENDS" "$SKIP_PACKAGE"
    ;;
  windows)
    build_target windows "$WINDOWS_HOST" "$CONFIGURE_FLAGS_WINDOWS" "$SKIP_DEPENDS" "$SKIP_PACKAGE"
    ;;
  all)
    build_target linux "$LINUX_HOST" "$CONFIGURE_FLAGS_LINUX" "$SKIP_DEPENDS" "$SKIP_PACKAGE"
    build_target windows "$WINDOWS_HOST" "$CONFIGURE_FLAGS_WINDOWS" "$SKIP_DEPENDS" "$SKIP_PACKAGE"
    ;;
esac

echo "==> done. Artifacts are under: $ARTIFACTS_DIR"
