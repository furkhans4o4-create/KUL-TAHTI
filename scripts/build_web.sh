#!/usr/bin/env bash
set -euo pipefail
ENGINE="Godot_v4.3-stable_linux.x86_64"
RELEASE="https://github.com/godotengine/godot-builds/releases/download/4.3-stable"
curl -fLsS --retry 3 -o /tmp/kul-godot.zip "$RELEASE/$ENGINE.zip"
curl -fLsS --retry 3 -o /tmp/kul-exports.tpz "$RELEASE/Godot_v4.3-stable_export_templates.tpz"
mkdir -p /tmp/kul-godot /tmp/kul-godot-tpl "$HOME/.local/share/godot/export_templates/4.3.stable"
unzip -q /tmp/kul-godot.zip -d /tmp/kul-godot
unzip -q /tmp/kul-exports.tpz -d /tmp/kul-godot-tpl
cp /tmp/kul-godot-tpl/templates/* "$HOME/.local/share/godot/export_templates/4.3.stable/"
chmod +x "/tmp/kul-godot/$ENGINE"
mkdir -p dist
"/tmp/kul-godot/$ENGINE" --headless --path . --editor --quit
"/tmp/kul-godot/$ENGINE" --headless --path . --export-release "Web" dist/index.html
test -s dist/index.html
test -s dist/index.wasm
