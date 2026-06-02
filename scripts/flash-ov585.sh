#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

SOURCE_DEPLOY_DIR="${SOURCE_DEPLOY_DIR:-$WORKSPACE_ROOT/build-ov585openstlinuxweston-stm32mp25-cargt-ov585/tmp-glibc/deploy/images/stm32mp25-cargt-ov585}"
FLASHLAYOUT_REL="${FLASHLAYOUT_REL:-flashlayout_ov585-cargt-image-dev/optee/FlashLayout_emmc_stm32mp257f-cargt-00395-00365v3-glt1011280800is1-optee.tsv}"
STM32_PROGRAMMER_DEFAULT="/mnt/c/Program Files/STMicroelectronics/STM32Cube/STM32CubeProgrammer/bin/STM32_Programmer_CLI.exe"
STM32_PORT="${STM32_PORT:-usb1}"
STM32_VERBOSITY="${STM32_VERBOSITY:-1}"
STAGE_DIR="${STAGE_DIR:-}"
DRY_RUN="${DRY_RUN:-0}"

find_programmer() {
    local programmer="${STM32_PROGRAMMER:-$STM32_PROGRAMMER_DEFAULT}"

    if [ -f "$programmer" ]; then
        printf '%s\n' "$programmer"
        return
    fi

    echo "ERROR: STM32CubeProgrammer CLI was not found:" >&2
    echo "  $programmer" >&2
    echo "Install STM32CubeProgrammer for Windows or set STM32_PROGRAMMER=/path/to/STM32_Programmer_CLI.exe." >&2
    exit 1
}

validate_flashlayout() {
    local root_dir="$1"
    local layout_rel="$2"
    local layout="$root_dir/$layout_rel"
    local missing=0

    if [ ! -f "$layout" ]; then
        echo "ERROR: flashlayout not found: $layout" >&2
        exit 1
    fi

    while read -r rel_path; do
        [ -z "$rel_path" ] && continue
        [ "$rel_path" = "none" ] && continue

        if [ ! -f "$root_dir/$rel_path" ]; then
            echo "ERROR: missing file referenced by flashlayout: $root_dir/$rel_path" >&2
            missing=1
        elif [ "$(stat -c '%s' "$root_dir/$rel_path")" -eq 0 ]; then
            echo "ERROR: empty file referenced by flashlayout: $root_dir/$rel_path" >&2
            missing=1
        fi
    done < <(awk 'NF >= 7 && $1 !~ /^#/ { print $7 }' "$layout" | sort -u)

    if [ "$missing" -ne 0 ]; then
        exit 1
    fi
}

stage_flashlayout_tree() {
    local source_root="$1"
    local stage_root="$2"
    local layout_rel="$3"

    mkdir -p "$stage_root/$(dirname "$layout_rel")"
    cp -L "$source_root/$layout_rel" "$stage_root/$layout_rel"

    while read -r rel_path; do
        [ -z "$rel_path" ] && continue
        [ "$rel_path" = "none" ] && continue

        mkdir -p "$stage_root/$(dirname "$rel_path")"
        cp -L "$source_root/$rel_path" "$stage_root/$rel_path"
    done < <(awk 'NF >= 7 && $1 !~ /^#/ { print $7 }' "$source_root/$layout_rel" | sort -u)
}

run_programmer() {
    local programmer="$1"
    local work_dir="$2"
    local layout_rel="$3"

    echo "Programmer:"
    echo "  $programmer"
    echo "Working directory:"
    echo "  $work_dir"
    echo "FlashLayout:"
    echo "  $layout_rel"
    echo "Port:"
    echo "  $STM32_PORT"
    echo

    if [ "$DRY_RUN" = "1" ]; then
        echo "DRY_RUN=1, not flashing."
        return
    fi

    cd "$work_dir"
    "$programmer" \
        --verbosity "$STM32_VERBOSITY" \
        -c port="$STM32_PORT" \
        -w "$layout_rel"
}

main() {
    local programmer
    local work_dir="$SOURCE_DEPLOY_DIR"

    validate_flashlayout "$SOURCE_DEPLOY_DIR" "$FLASHLAYOUT_REL"

    if [ -n "$STAGE_DIR" ]; then
        echo "Staging flashlayout files to:"
        echo "  $STAGE_DIR"
        echo
        stage_flashlayout_tree "$SOURCE_DEPLOY_DIR" "$STAGE_DIR" "$FLASHLAYOUT_REL"
        validate_flashlayout "$STAGE_DIR" "$FLASHLAYOUT_REL"
        work_dir="$STAGE_DIR"
    fi

    programmer="$(find_programmer)"
    run_programmer "$programmer" "$work_dir" "$FLASHLAYOUT_REL"
}

main "$@"
