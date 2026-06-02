# oe-scripts
Environment scripts for OpenSTLinux to use with Openembedded.

## OV585 flashing

Build the image first:

```sh
source ./layers/meta-st/meta-st-ov585/scripts/envsetup.sh
bitbake ov585-cargt-image-dev
```

Flash the eMMC image from WSL using the Windows STM32CubeProgrammer CLI:

```sh
./layers/meta-st/meta-st-ov585/scripts/flash-windows-bundle.sh
```

This stages the FlashLayout and referenced image files into `flash-ov585-bundle/` at the workspace root before invoking STM32CubeProgrammer. That avoids problems with Windows tools resolving WSL symlinks or absolute Linux paths.

The direct Linux/WSL variant is also available:

```sh
./layers/meta-st/meta-st-ov585/scripts/flash-ov585.sh
```

The script expects the Windows programmer binary at:

```text
/mnt/c/Program Files/STMicroelectronics/STM32Cube/STM32CubeProgrammer/bin/STM32_Programmer_CLI.exe
```

Set `STM32_PROGRAMMER=/path/to/STM32_Programmer_CLI.exe` to override that path.

## CARGT dev board boot mode

Only `01` and `10` are normally relevant for OV585 programming and eMMC boot.

| BOOT_MODE[1:0] | Boot Configuration | Notes |
| --- | --- | --- |
| 00 | Boot from Internal Fuses | |
| 01 | Serial Downloader | Production programming |
| 10 | USDHC1 8-bit eMMC 5.1 | Recommended setting |
| 11 | USDCH2 4-bit SD | Default setting |

For DFU/programming, use the USB port closest to the Ethernet jack.
