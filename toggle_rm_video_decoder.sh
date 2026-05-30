#!/usr/bin/env bash
set -e

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"

GDEXT="$PROJECT_ROOT/rm_synapse/addons/rm_video_decoder/rm_video_decoder.gdextension"
GDEXT_DISABLED="$PROJECT_ROOT/rm_synapse/addons/rm_video_decoder/rm_video_decoder.gdextension.disabled"

SCENE="$PROJECT_ROOT/rm_synapse/net/video_udp/transfer_image.tscn"
SCENE_BAK="$PROJECT_ROOT/rm_synapse/net/video_udp/transfer_image.tscn.bak.rm_video_canvas"

usage() {
  echo "Usage:"
  echo "  ./toggle_rm_video_decoder.sh off   # 禁用 rm_video_decoder，让 macOS 先跑起来"
  echo "  ./toggle_rm_video_decoder.sh on    # 恢复 rm_video_decoder"
  echo "  ./toggle_rm_video_decoder.sh status"
}

disable_decoder() {
  echo "Disabling rm_video_decoder..."

  if [ -f "$GDEXT" ]; then
    mv "$GDEXT" "$GDEXT_DISABLED"
    echo "Disabled: $GDEXT"
  else
    echo "Already disabled or missing: $GDEXT"
  fi

  if [ -f "$SCENE" ]; then
    if [ ! -f "$SCENE_BAK" ]; then
      cp "$SCENE" "$SCENE_BAK"
      echo "Backup created: $SCENE_BAK"
    fi

    perl -i -pe 's/type="RMVideoCanvas"/type="Control"/g' "$SCENE"
    echo "Patched scene: RMVideoCanvas -> Control"
  else
    echo "Scene not found: $SCENE"
  fi

  echo "Done. Video decoder is OFF."
}

enable_decoder() {
  echo "Enabling rm_video_decoder..."

  if [ -f "$GDEXT_DISABLED" ]; then
    mv "$GDEXT_DISABLED" "$GDEXT"
    echo "Restored: $GDEXT"
  else
    echo "Already enabled or missing disabled file: $GDEXT_DISABLED"
  fi

  if [ -f "$SCENE_BAK" ]; then
    mv "$SCENE_BAK" "$SCENE"
    echo "Restored original scene: $SCENE"
  else
    echo "No scene backup found. Trying direct reverse patch..."
    if [ -f "$SCENE" ]; then
      perl -i -pe 's/type="Control"/type="RMVideoCanvas"/g if /name="RMVideoCanvas"/' "$SCENE"
      echo "Patched scene: Control -> RMVideoCanvas"
    fi
  fi

  echo "Done. Video decoder is ON."
}

status_decoder() {
  echo "=== rm_video_decoder status ==="

  if [ -f "$GDEXT" ]; then
    echo "GDExtension: ON"
  elif [ -f "$GDEXT_DISABLED" ]; then
    echo "GDExtension: OFF"
  else
    echo "GDExtension: missing"
  fi

  echo
  echo "=== RMVideoCanvas scene line ==="
  if [ -f "$SCENE" ]; then
    grep -n 'name="RMVideoCanvas"' "$SCENE" || echo "RMVideoCanvas node line not found"
  else
    echo "Scene not found: $SCENE"
  fi
}

case "${1:-}" in
  off)
    disable_decoder
    ;;
  on)
    enable_decoder
    ;;
  status)
    status_decoder
    ;;
  *)
    usage
    exit 1
    ;;
esac
