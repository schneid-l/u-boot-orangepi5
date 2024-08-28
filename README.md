# U-Boot build for Orange Pi 5

This repo provides pre-built SPI flash U-Boot v2024.07 binaries for the Orange Pi 5 (and variants) board.

## Supported boards

- Orange Pi 5
- Orange Pi 5B (use the same binary as the Orange Pi 5)
- Orange Pi 5 Plus

## Pre-built binaries

This U-Boot build uses pre-built `BL31` and `TPL` binaries provided by Rockchip from [rkbin](https://github.com/rockchip-linux/rkbin) repo.
For now the Arm Trusted Firmware (ATF) is not used as the rk3588 is not supported by the mainline ATF (waiting for [this change](https://review.trustedfirmware.org/c/TF-A/trusted-firmware-a/+/21840) to be merged).

This U-Boot build also uses [patches](https://github.com/armbian/build/tree/main/patch/u-boot/v2024.07) provided by Arm to support the rk3588 SoC.

I will update this repo as soon as a stable ATF version supporting rk3588 is released.

## Known issues

- The HDMI output is not working.
- Booting from a m.2 SATA drive is not working (NVMe is working).

Don't hesitate to open a Github issue if you encounter any other issue.

## Install

This repo only provides a version **made to be flashed on the SPI flash** of the Orange Pi 5 as its the recommended way to boot the board.

To do this you will need an [official distribution](http://www.orangepi.org/html/hardWare/computerAndMicrocontrollers/service-and-support/Orange-pi-5.html) provided by Orange Pi (or [Armbian](https://www.armbian.com/orangepi-5/)) booted from an SD card.

Once booted, download your **board specific** U-Boot binary from the [releases section](https://github.com/schneid-l/u-boot-orangepi5/releases):

```bash
# Orange Pi 5 (and Orange Pi 5B)
wget https://github.com/schneid-l/u-boot-orangepi5/releases/download/latest/u-boot-v2024.07-orangepi5-spi.bin

# Orange Pi 5 Plus
wget https://github.com/schneid-l/u-boot-orangepi5/releases/download/latest/u-boot-v2024.07-orangepi5-plus-spi.bin
```

We will assume that the SPI flash chip is `/dev/mtdblock0` (you can check this by using `lsblk`).

Reset the SPI flash:

```bash
devicesize=$(blockdev --getsz /dev/mtdblock0)
dd if=/dev/zero of=/dev/mtdblock0 bs=1M count=$devicesize status=progress && sync
```

Flash the U-Boot binary:

```bash
# Orange Pi 5 (and Orange Pi 5B)
dd if=u-boot-v2024.07-orangepi5-spi.bin of=/dev/mtdblock0 bs=1M status=progress && sync

# Orange Pi 5 Plus
dd if=u-boot-v2024.07-orangepi5-plus-spi.bin of=/dev/mtdblock0 bs=1M status=progress && sync
```

Reboot the board, _et voilà_!

## Build

Build is done using a Docker container to ensure reproducibility.

To build the U-Boot binary, you will need to have Docker installed on your machine.

Clone this repo:

```bash
git clone https://github.com/schneid-l/u-boot-orangepi5.git
cd orangepi5-u-boot
```

Build the U-Boot binary with Docker:

```bash
# Orange Pi 5 (and Orange Pi 5B)
docker build --platform="linux/arm64" --output type=local,dest=. . --build-arg DEFCONFIG=orangepi-5-rk3588s

# Orange Pi 5 Plus
docker build --platform="linux/arm64" --output type=local,dest=. . --build-arg DEFCONFIG=orangepi-5-plus-rk3588
```

The U-Boot binary will be available in the current directory.

Available build args:

- `U_BOOT_VERSION`: the U-Boot version to build (default: `v2024.07`)
- `DEFCONFIG`: the U-Boot defconfig to use (`_defconfig` is automatically appended, default: `orangepi-5-rk3588s`)
- `BOARD`: the board name (used in the output name, default: `orangepi5`)
- `NAME`: the binary output name (default: `u-boot-${U_BOOT_VERSION}-${NAME}-spi`)
- `SOURCE_DATE_EPOCH`: the source date epoch to use for reproducibility (default: the last commit date)

_As this image uses the rkbin provided BL31 and TPL binaries for rk3588, this build environment could be used to build U-Boot for any rk3588 board by passing the correct `DEFCONFIG` argument._

## License

The U-Boot source code is licensed under the GPL-2.0 license. So this repo too.
