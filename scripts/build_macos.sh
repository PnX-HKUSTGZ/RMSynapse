#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

HOST_MACHINE="$(uname -m)"
if [[ "${HOST_MACHINE}" == "arm64" || "${HOST_MACHINE}" == "aarch64" ]]; then
  DEFAULT_ARCH="arm64"
else
  DEFAULT_ARCH="x86_64"
fi

TARGET="template_release"
ARCH="${DEFAULT_ARCH}"
BUILD_UI=1
BUILD_VIDEO=1
RUN_EXPORT=0
LFS_PULL=0
NPM_CI=1
GODOT_BIN="${GODOT_BIN:-godot}"
SCONS_EXTRA=()

usage() {
  cat <<'EOF'
Usage: scripts/build_macos.sh [options] [-- extra_scons_args...]

Options:
  --debug                 Use target=template_debug.
  --target <target>       SCons target, default: template_release.
  --arch <arch>           SCons arch: arm64, x86_64, or universal.
  --skip-ui               Do not build/copy react-ui.
  --skip-video            Do not build rm_video_decoder.
  --export                Export Godot macOS preset after building.
  --godot <path>          Godot executable, default: $GODOT_BIN or godot.
  --lfs-pull              Run git lfs pull before building.
  --no-npm-ci             Skip npm ci and only run npm run build.
  --ffmpeg-root <path>    Pass ffmpeg_root=<path> to SCons.
  --ffmpeg-runtime <path> Pass ffmpeg_runtime_dir=<path> to SCons.
  --copy-ffmpeg <mode>    Pass copy_ffmpeg_runtime=auto|yes|no to SCons.
  -h, --help              Show this help.

Examples:
  scripts/build_macos.sh --arch arm64
  scripts/build_macos.sh --arch universal --export
  scripts/build_macos.sh --ffmpeg-root /opt/homebrew/opt/ffmpeg
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --debug)
      TARGET="template_debug"
      shift
      ;;
    --target)
      TARGET="${2:?missing value for --target}"
      shift 2
      ;;
    --arch)
      ARCH="${2:?missing value for --arch}"
      shift 2
      ;;
    --skip-ui)
      BUILD_UI=0
      shift
      ;;
    --skip-video)
      BUILD_VIDEO=0
      shift
      ;;
    --export)
      RUN_EXPORT=1
      shift
      ;;
    --godot)
      GODOT_BIN="${2:?missing value for --godot}"
      shift 2
      ;;
    --lfs-pull)
      LFS_PULL=1
      shift
      ;;
    --no-npm-ci)
      NPM_CI=0
      shift
      ;;
    --ffmpeg-root)
      SCONS_EXTRA+=("ffmpeg_root=${2:?missing value for --ffmpeg-root}")
      shift 2
      ;;
    --ffmpeg-runtime)
      SCONS_EXTRA+=("ffmpeg_runtime_dir=${2:?missing value for --ffmpeg-runtime}")
      shift 2
      ;;
    --copy-ffmpeg)
      SCONS_EXTRA+=("copy_ffmpeg_runtime=${2:?missing value for --copy-ffmpeg}")
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      SCONS_EXTRA+=("$@")
      break
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

run_lfs_pull() {
  if [[ "${LFS_PULL}" -eq 1 ]]; then
    git -C "${ROOT_DIR}" lfs pull
  fi
}

build_ui() {
  if [[ "${BUILD_UI}" -eq 0 ]]; then
    return
  fi

  pushd "${ROOT_DIR}/react-ui" >/dev/null
  if [[ "${NPM_CI}" -eq 1 ]]; then
    npm ci
  fi
  npm run build
  popd >/dev/null

  rm -rf "${ROOT_DIR}/rm_synapse/ui/web"
  mkdir -p "${ROOT_DIR}/rm_synapse/ui/web"
  cp -R "${ROOT_DIR}/react-ui/dist/." "${ROOT_DIR}/rm_synapse/ui/web/"
}

build_video() {
  if [[ "${BUILD_VIDEO}" -eq 0 ]]; then
    return
  fi

  pushd "${ROOT_DIR}/plugins/rm_video_decoder" >/dev/null
  scons "platform=macos" "target=${TARGET}" "arch=${ARCH}" "${SCONS_EXTRA[@]}"
  popd >/dev/null
}

export_project() {
  if [[ "${RUN_EXPORT}" -eq 0 ]]; then
    return
  fi

  if [[ "${ARCH}" != "universal" ]]; then
    echo "Note: Godot macOS export preset is universal; make sure CEF and GDExtension runtime libraries match the export architecture." >&2
  fi

  mkdir -p "${ROOT_DIR}/rm_synapse/Export/macos"
  "${GODOT_BIN}" --headless --path "${ROOT_DIR}/rm_synapse" \
    --export-release "macOS" "${ROOT_DIR}/rm_synapse/Export/macos/rmsynapse.dmg"
}

run_lfs_pull
build_ui
build_video
export_project

echo "macOS build finished."
