#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

SOURCE_DEPLOY_DIR="${SOURCE_DEPLOY_DIR:-$WORKSPACE_ROOT/build-ov585openstlinuxweston-stm32mp25-cargt-ov585/tmp-glibc/deploy/images/stm32mp25-cargt-ov585}"
FLASHLAYOUT_REL="${FLASHLAYOUT_REL:-flashlayout_ov585-cargt-image-dev/optee/FlashLayout_emmc_stm32mp257f-cargt-00395-00365v3-optee.tsv}"
BUNDLE_DIR="${BUNDLE_DIR:-$WORKSPACE_ROOT/flash-ov585-bundle}"
STM32_PROGRAMMER="${STM32_PROGRAMMER:-/mnt/c/Program Files/STMicroelectronics/STM32Cube/STM32CubeProgrammer/bin/STM32_Programmer_CLI.exe}"
STM32_PORT="${STM32_PORT:-usb1}"
STM32_VERBOSITY="${STM32_VERBOSITY:-1}"
STAGE_ONLY="${STAGE_ONLY:-0}"

stage_flashlayout_files() {
    local layout_src="$SOURCE_DEPLOY_DIR/$FLASHLAYOUT_REL"
    local layout_name

    layout_name="$(basename "$FLASHLAYOUT_REL")"

    if [ ! -f "$layout_src" ]; then
        echo "ERROR: flashlayout not found: $layout_src" >&2
        exit 1
    fi

    rm -rf "$BUNDLE_DIR"
    mkdir -p "$BUNDLE_DIR"

    echo "Staging flashlayout files:" >&2
    echo "  from: $SOURCE_DEPLOY_DIR" >&2
    echo "  to:   $BUNDLE_DIR" >&2
    echo >&2

    cp -L "$layout_src" "$BUNDLE_DIR/$layout_name"

    while read -r rel_path; do
        [ -z "$rel_path" ] && continue
        [ "$rel_path" = "none" ] && continue

        local src="$SOURCE_DEPLOY_DIR/$rel_path"
        if [ ! -f "$src" ]; then
            echo "ERROR: flashlayout references missing file: $src" >&2
            exit 1
        fi

        mkdir -p "$BUNDLE_DIR/$(dirname "$rel_path")"
        cp -L "$src" "$BUNDLE_DIR/$rel_path"
    done < <(awk 'NF >= 7 && $1 !~ /^#/ { print $7 }' "$layout_src" | sort -u)

    printf '%s\n' "$layout_name"
}

run_programmer() {
    local layout_name="$1"

    if [ ! -f "$STM32_PROGRAMMER" ]; then
        echo "ERROR: STM32CubeProgrammer CLI was not found:" >&2
        echo "  $STM32_PROGRAMMER" >&2
        echo "Set STM32_PROGRAMMER=/path/to/STM32_Programmer_CLI.exe and retry." >&2
        exit 1
    fi

    echo "Programmer:"
    echo "  $STM32_PROGRAMMER"
    echo "Working directory:"
    echo "  $BUNDLE_DIR"
    echo "FlashLayout:"
    echo "  $layout_name"
    echo "Port:"
    echo "  $STM32_PORT"
    echo

    cd "$BUNDLE_DIR"
    "$STM32_PROGRAMMER" \
        --verbosity "$STM32_VERBOSITY" \
        -c port="$STM32_PORT" \
        -w "$layout_name"
}

main() {
    local layout_name

    layout_name="$(stage_flashlayout_files)"

    if [ "$STAGE_ONLY" = "1" ]; then
        echo "Staged files only. Not flashing because STAGE_ONLY=1."
        return
    fi

    run_programmer "$layout_name"
}

main "$@"
