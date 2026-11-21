# Project Borealis FEX fix

Use MacLauncher’s KosmicKrisp as the default Vulkan driver for CrossOver Preview and NotProton FEX, then run Project Borealis Prologue with its performance device profile.

## Quick install

1. Download and extract the [installer ZIP](https://github.com/programmer1o1/borealis-fex-fix/releases/latest/download/Borealis-FEX-Fix.zip).
2. Close the Windows games using the runner. Open Terminal, type `bash ` with a trailing space, drag the extracted `install.command` into the Terminal window, and press Return.
3. Set Project Borealis Prologue’s Steam launch options to:

   ```text
   -vulkan -DP=Windows_Performance
   ```

4. Launch using the CrossOver ARM64 bottle or NotProton FEX compatibility tool. Leave Steam running while playing.

The installer requires Apple Silicon, macOS 26 or later, and a writable CrossOver Preview build 27.0.0.41073 or its matching NotProton FEX runner. It verifies the original ARM64 MoltenVK library by hash. Open or configure the runner in NotProton first so its local copy exists. The installer selects both matching locations by default. Run `bash /path/to/install.command --crossover` or `bash /path/to/install.command --notproton` to select one. An update or runner reimport can replace the change.

## Restore MoltenVK

Run `bash /path/to/install.command --restore` from the extracted release. Add `--crossover` or `--notproton` to restore one runtime. This restores the original library from the verified backup. The downloaded driver files and backup stay alongside it for reinstallation.

## What changes

The ARM64 library loaded by Wine for Vulkan becomes a small shim that forwards Vulkan calls to the Khronos loader and supplies the bundled KosmicKrisp manifest by default. Explicit `VK_DRIVER_FILES` or `VK_ICD_FILENAMES` overrides still work. The installer downloads the pinned [MacLauncher 27.0.0-devel-MCLv15 ARM64 archive](https://github.com/procrastinine/maclauncher-builds/releases/tag/maclauncher-kosmickrisp/v27.0.0-devel-MCLv15/arm64) and checks its SHA-256 before unpacking it. The release contains the installer and shim. The vendor runtimes and game files stay on your machine.

On Apple M4, this driver lets the game pass the Vulkan SM6 checks. The performance profile disables features including Nanite tessellation and Virtual Shadow Maps. The default profile triggered a Metal command queue timeout during the Ravenholm load on the tested M4. The performance profile reached gameplay in both CrossOver and NotProton. The exact render pass that timed out is unknown.

The shim source is in `loader-default.c`. To build it, extract the upstream archive and run this command from the repository, substituting the path to its loader:

```sh
clang -arch arm64 -dynamiclib -mmacosx-version-min=26.0 loader-default.c \
  -Xlinker -reexport_library -Xlinker /path/to/files/files/libvulkan.1.dylib \
  -Wl,-rpath,@loader_path/kosmickrisp -Wl,-install_name,@rpath/libMoltenVK.dylib \
  -o libMoltenVK.dylib
```
