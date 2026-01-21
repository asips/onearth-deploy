#!/bin/bash
# Apply local patches to the onearth submodule

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ONEARTH_DIR="$REPO_ROOT/onearth"

if [ ! -d "$ONEARTH_DIR/.git" ]; then
    echo "Error: onearth submodule not found at $ONEARTH_DIR"
    exit 1
fi

cd "$ONEARTH_DIR"

# Apply all .patch files in the patches directory
for patch_file in "$SCRIPT_DIR"/*.patch; do
    if [ -f "$patch_file" ]; then
        patch_name=$(basename "$patch_file")
        echo "Applying patch: $patch_name"
        patch -p1 < "$patch_file"
        echo "Successfully applied: $patch_name"
    fi
done

echo "All patches applied successfully"
