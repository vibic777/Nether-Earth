#!/bin/sh
# Контрибьютор: vibic777
set -e
root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
godot=${GODOT:-godot}
"$godot" --headless --path "$root" --import
"$godot" --headless --path "$root" -- --test
