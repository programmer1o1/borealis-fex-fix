# KosmicKrisp installer for CrossOver Preview and NotProton FEX

Make MacLauncher’s KosmicKrisp the default Vulkan driver for Windows games running in the supported ARM64 Wine runtimes. This applies to games that use Vulkan directly and to Vulkan-based translation layers such as DXVK and VKD3D-Proton. Compatibility varies by game and translation-layer version.

## Quick install

1. Download and extract the [installer ZIP](https://github.com/programmer1o1/borealis-fex-fix/releases/latest/download/KosmicKrisp-FEX-Installer.zip).
2. Close the Windows games using the runner. Open Terminal, type `bash ` with a trailing space, drag the extracted `install.command` into Terminal, and press Return.
3. Relaunch your game in the CrossOver ARM64 bottle or with the NotProton FEX compatibility tool. Use the game’s usual launch options.

The installer requires Apple Silicon, macOS 26 or later, and a writable CrossOver Preview build 27.0.0.41073 or its matching NotProton FEX runner. It verifies the original ARM64 MoltenVK library by hash. Set up the FEX runner in NotProton first so its local copy exists. The installer selects both supported locations it finds. Use `--crossover` or `--notproton` to select one. A CrossOver update or NotProton runner reimport can replace the change.

The change applies to Wine’s ARM64 Vulkan path in the selected runtimes. Native macOS apps, Rosetta bottles, and D3DMetal keep their existing graphics paths.

## Restore MoltenVK

Run `bash /path/to/install.command --restore` from the extracted release. Add `--crossover` or `--notproton` to restore one runtime. The installer restores the verified original library and keeps the downloaded driver and backup for reinstallation.

## Tested example — Project Borealis Prologue

Borealis uses Unreal’s native Vulkan renderer with these Steam launch options.

```text
-vulkan -DP=Windows_Performance
```

On the tested Apple M4, MacLauncher’s KosmicKrisp passed the game’s Vulkan SM6 checks. The default graphics profile then triggered a Metal command queue timeout while loading Ravenholm. The performance profile disables features including Nanite tessellation and Virtual Shadow Maps and reached gameplay in both CrossOver and NotProton. Use those flags for Borealis and leave Steam open while playing.

## How it works

Wine loads a small ARM64 shim that forwards Vulkan calls to the Khronos loader and supplies a KosmicKrisp manifest. Explicit `VK_DRIVER_FILES` or `VK_ICD_FILENAMES` overrides still work. The installer downloads the pinned [MacLauncher 27.0.0-devel-MCLv15 ARM64 archive](https://github.com/procrastinine/maclauncher-builds/releases/tag/maclauncher-kosmickrisp/v27.0.0-devel-MCLv15/arm64) and checks its SHA-256 before unpacking it. The release contains the installer and shim.

To build the shim, extract the upstream archive and run this command from the repository with the path to its loader.

```sh
clang -arch arm64 -dynamiclib -mmacosx-version-min=26.0 loader-default.c \
  -Xlinker -reexport_library -Xlinker /path/to/files/files/libvulkan.1.dylib \
  -Wl,-rpath,@loader_path/kosmickrisp -Wl,-install_name,@rpath/libMoltenVK.dylib \
  -o libMoltenVK.dylib
```
