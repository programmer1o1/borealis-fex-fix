#!/bin/bash
set -euo pipefail

stock_sha=65034b05ff1ac4463c02c4ea32585357eb3b1632a0a759709f15a921647d3a23
driver_sha=ef0daa323ace6c936ca136e47842a78001cba4dba4af203562df3c42d4ad2c4a
driver_url=https://github.com/procrastinine/maclauncher-builds/releases/download/maclauncher-kosmickrisp/v27.0.0-devel-MCLv15/arm64/maclauncher-kosmickrisp-27.0.0-devel-MCLv15-arm64.tar.gz
here="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
cross_over="/Applications/CrossOver Preview.app/Contents/SharedSupport/CrossOver"
not_proton="$HOME/Library/Application Support/notproton/runners/crossover-27.0.0.41073-fex/CrossOver"

usage() {
    printf '%s\n' 'Usage: install.command [--crossover | --notproton | --runtime PATH] [--restore] [--archive FILE]'
}

fail() {
    printf '%s\n' "$*" >&2
    exit 1
}

hash() {
    /usr/bin/shasum -a 256 "$1" | /usr/bin/awk '{print $1}'
}

restore=0
archive=
targets=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --crossover) targets+=("$cross_over") ;;
        --notproton) targets+=("$not_proton") ;;
        --runtime)
            [[ $# -ge 2 ]] || fail 'Specify a CrossOver runtime directory.'
            targets+=("$2")
            shift ;;
        --restore) restore=1 ;;
        --archive)
            [[ $# -ge 2 ]] || fail 'Specify the upstream driver archive file.'
            archive="$2"
            shift ;;
        --help|-h) usage; exit 0 ;;
        *) usage >&2; fail "Unknown option $1" ;;
    esac
    shift
done

if [[ ${#targets[@]} -eq 0 ]]; then
    for runtime in "$cross_over" "$not_proton"; do
        if [[ -d "$runtime/lib/aarch64" ]]; then
            targets+=("$runtime")
        fi
    done
fi

[[ ${#targets[@]} -gt 0 ]] || fail 'No supported CrossOver Preview or NotProton FEX runtime was found.'
[[ "$(/usr/bin/uname -m)" = arm64 ]] || fail 'Run this installer from an Apple Silicon Terminal.'
if [[ "$restore" -eq 0 ]]; then
    macos_version="$(/usr/bin/sw_vers -productVersion)"
    [[ "${macos_version%%.*}" -ge 26 ]] || fail 'The bundled driver requires macOS 26 or later.'
fi

work="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/borealis-fex.XXXXXXXX")"
staging=''
cleanup() {
    if [[ -n "$staging" ]]; then
        /bin/rm -rf "$staging"
    fi
    /bin/rm -rf "$work"
}
trap cleanup EXIT

shim="$here/libMoltenVK.dylib"
if [[ "$restore" -eq 0 ]]; then
    [[ -f "$shim" ]] || fail 'Download and extract the installer ZIP from Releases.'
    /usr/bin/codesign --verify --strict "$shim"
    if [[ -z "$archive" ]]; then
        archive="$work/driver.tar.gz"
        /usr/bin/curl --fail --location --silent --show-error --retry 2 --output "$archive" "$driver_url"
    fi
    [[ "$(hash "$archive")" = "$driver_sha" ]] || fail 'The driver archive failed its SHA-256 check.'
    /usr/bin/tar -xzf "$archive" -C "$work"
    driver="$work/files/files"
    [[ -f "$driver/libvulkan_kosmickrisp.dylib" && -f "$driver/libvulkan.1.dylib" ]] ||
        fail 'The driver archive has an unexpected layout.'
    cat > "$driver/kosmickrisp_icd.json" <<'MANIFEST'
{
  "file_format_version": "1.0.1",
  "ICD": {
    "library_path": "./libvulkan_kosmickrisp.dylib",
    "api_version": "1.4.0"
  }
}
MANIFEST
fi

# Check every destination before changing any of them.
for runtime in "${targets[@]}"; do
    lib="$runtime/lib/aarch64"
    live="$lib/libMoltenVK.dylib"
    backup="$lib/libMoltenVK.codeweavers.dylib"
    [[ -w "$lib" && -f "$live" ]] || fail "Cannot write to the ARM64 runtime at $lib"
    if [[ -e "$backup" ]]; then
        [[ "$(hash "$backup")" = "$stock_sha" ]] || fail "Unexpected MoltenVK backup at $backup"
    fi
    if [[ "$restore" -eq 1 ]]; then
        if [[ "$(hash "$live")" != "$stock_sha" ]]; then
            [[ -f "$backup" ]] || fail "No verified MoltenVK backup at $backup"
            [[ -f "$shim" ]] && /usr/bin/cmp -s "$live" "$shim" ||
                fail "The active library at $live does not match this release."
        fi
    elif [[ "$(hash "$live")" != "$stock_sha" ]]; then
        [[ -f "$backup" ]] && /usr/bin/cmp -s "$live" "$shim" ||
            fail "Unsupported or already modified MoltenVK at $live"
    fi
    if [[ "$restore" -eq 0 && -e "$lib/kosmickrisp" ]]; then
        /usr/bin/diff -qr "$driver" "$lib/kosmickrisp" >/dev/null ||
            fail "A different KosmicKrisp installation already exists at $lib/kosmickrisp"
    fi
done

for runtime in "${targets[@]}"; do
    lib="$runtime/lib/aarch64"
    live="$lib/libMoltenVK.dylib"
    backup="$lib/libMoltenVK.codeweavers.dylib"
    if [[ "$restore" -eq 1 && "$(hash "$live")" = "$stock_sha" ]]; then
        printf 'MoltenVK is already active in %s\n' "$runtime"
        continue
    fi
    staging="$(/usr/bin/mktemp -d "$lib/.borealis-fex.XXXXXXXX")"
    if [[ "$restore" -eq 1 ]]; then
        /bin/cp -p "$backup" "$staging/library"
        /bin/mv -f "$staging/library" "$live"
        printf 'Restored MoltenVK in %s\n' "$runtime"
    else
        if [[ ! -e "$backup" ]]; then
            /bin/cp -p "$live" "$staging/backup"
            /bin/mv "$staging/backup" "$backup"
        fi
        if [[ ! -e "$lib/kosmickrisp" ]]; then
            /usr/bin/ditto "$driver" "$staging/driver"
            /bin/mv "$staging/driver" "$lib/kosmickrisp"
        fi
        if ! /usr/bin/cmp -s "$live" "$shim"; then
            /bin/cp -p "$shim" "$staging/library"
            /bin/mv -f "$staging/library" "$live"
        fi
        printf 'KosmicKrisp is active in %s\n' "$runtime"
    fi
    /bin/rmdir "$staging"
    staging=''
done

printf '%s\n' 'Relaunch games after changing the driver. For Project Borealis, use Steam launch options -vulkan -DP=Windows_Performance.'
