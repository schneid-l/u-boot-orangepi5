# U-Boot build for Orange Pi 5

This repo provides pre-built SPI flash U-Boot binaries for the Orange Pi 5 (and variants) board.

> [!WARNING]
> These binaries are **built and released fully automatically** whenever U-Boot, ATF, OP-TEE or rkbin publish a new version — **nobody boots them on real hardware before release**, so a successful boot is **not guaranteed**. This is the deliberate trade-off for always-fresh builds; in practice the upstream projects are stable, and flashing U-Boot to SPI is recoverable. If a binary doesn't boot, see [Recovery](#recovery-unbrick) below.

## Supported boards

- Orange Pi 5
- Orange Pi 5B (use the same binary as the Orange Pi 5)
- Orange Pi 5 Plus
- Orange Pi 5 Max
- Orange Pi 5 Ultra

## Pre-built binaries

This U-Boot build uses pre-built `TPL` binaries provided by Rockchip from [rkbin](https://github.com/rockchip-linux/rkbin) repo.

## Known issues

These were observed on **older** U-Boot releases and may no longer apply — the repo now tracks the latest mainline U-Boot, where rk3588 support has improved considerably. Please verify against the current release and report what you find.

- HDMI output may not work from within U-Boot (the booted OS drives HDMI normally).
- Booting from an m.2 SATA drive may not work (NVMe works).
- Network may not work from within U-Boot on the Orange Pi 5 Plus.

Don't hesitate to open a GitHub issue if you encounter any other issue.

## Install

This repo only provides a version **made to be flashed on the SPI flash** of the Orange Pi 5 as its the recommended way to boot the board.

To do this you will need an [official distribution](http://www.orangepi.org/html/hardWare/computerAndMicrocontrollers/service-and-support/Orange-pi-5.html) provided by Orange Pi (or [Armbian](https://www.armbian.com/orangepi-5/)) booted from an SD card.

Once booted, download your **board specific** U-Boot binary from the [latest release](https://github.com/schneid-l/u-boot-orangepi5/releases/latest):

```bash
# Orange Pi 5 (and Orange Pi 5B)
wget https://github.com/schneid-l/u-boot-orangepi5/releases/latest/download/u-boot-orangepi5-spi.bin

# Orange Pi 5 Plus
wget https://github.com/schneid-l/u-boot-orangepi5/releases/latest/download/u-boot-orangepi5-plus-spi.bin

# Orange Pi 5 Max
wget https://github.com/schneid-l/u-boot-orangepi5/releases/latest/download/u-boot-orangepi5-max-spi.bin

# Orange Pi 5 Ultra
wget https://github.com/schneid-l/u-boot-orangepi5/releases/latest/download/u-boot-orangepi5-ultra-spi.bin
```

You can verify a download against the `SHA256SUMS` file attached to the release (`sha256sum -c SHA256SUMS`), and a CycloneDX SBOM (`sbom.cdx.json`) lists every component baked in. See [Verify the binaries](#verify-the-binaries) for signature verification.

> [!NOTE]
> An **experimental `-optee` variant** is published next to each board (e.g. `u-boot-orangepi5-optee-spi.bin`). It bundles the OP-TEE secure world (BL32, built from [OP-TEE OS](https://github.com/OP-TEE/optee_os)) for TrustZone-based features. The standard binary above is recommended; only use the `-optee` build if you need OP-TEE, and test it on your board first.

We will assume that the SPI flash chip is `/dev/mtdblock0` (you can check this by using `lsblk`).

Reset the SPI flash:

```bash
devicesize=$(blockdev --getsz /dev/mtdblock0)
dd if=/dev/zero of=/dev/mtdblock0 bs=512k count=$devicesize status=progress && sync
```

Flash the U-Boot binary:

```bash
# Orange Pi 5 (and Orange Pi 5B)
dd if=u-boot-orangepi5-spi.bin of=/dev/mtdblock0 bs=512k status=progress && sync

# Orange Pi 5 Plus
dd if=u-boot-orangepi5-plus-spi.bin of=/dev/mtdblock0 bs=512k status=progress && sync
```

Reboot the board, _et voilà_!

## Recovery (unbrick)

Flashing U-Boot to the SPI is recoverable — the board still boots from an SD card even with a bad SPI image.

- **Re-flash or wipe the SPI:** boot the official (or Armbian) image from an SD card and repeat the steps above, or wipe the SPI with `dd if=/dev/zero of=/dev/mtdblock0 ...` and write a known-good binary.
- **If the board won't boot at all:** put it into **MaskROM mode** and re-flash with [`rkdeveloptool`](https://github.com/rockchip-linux/rkdeveloptool) (or Rockchip's RKDevTool on Windows). See the [Orange Pi official wiki](http://www.orangepi.org/orangepiwiki/index.php/Orange_Pi_5) and the community [Armbian "Maskrom / erase SPI" guide](https://forum.armbian.com/topic/26418-maskrom-erase-spi/).

## Verify the binaries

Every released binary is signed and carries [SLSA build provenance](https://slsa.dev/), so you can verify it was built by this repository's CI from this source.

Verify the provenance attestation with the GitHub CLI:

```bash
gh attestation verify u-boot-orangepi5-spi.bin --repo schneid-l/u-boot-orangepi5
```

Or verify the [cosign](https://docs.sigstore.dev/) signature (download the matching `.cosign.bundle` from the release):

```bash
cosign verify-blob \
  --bundle u-boot-orangepi5-spi.bin.cosign.bundle \
  --certificate-identity-regexp '^https://github.com/schneid-l/u-boot-orangepi5/' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  u-boot-orangepi5-spi.bin
```

Each release also ships a `*.manifest.json` recording the exact U-Boot, ARM Trusted Firmware and rkbin versions that went into the binary.

## Build

Build is done using a Docker container to ensure reproducibility.

To build the U-Boot binary, you will need to have Docker installed on your machine.

Clone this repo:

```bash
git clone https://github.com/schneid-l/u-boot-orangepi5.git
cd u-boot-orangepi5
```

Build the U-Boot binary with Docker:

```bash
# Orange Pi 5 (and Orange Pi 5B)
docker build --platform=linux/arm64 --output type=local,dest=. \
  --build-arg BOARD=orangepi5 --build-arg DEFCONFIG=orangepi-5-rk3588s .

# Orange Pi 5 Plus
docker build --platform=linux/arm64 --output type=local,dest=. \
  --build-arg BOARD=orangepi5-plus --build-arg DEFCONFIG=orangepi-5-plus-rk3588 .
```

The U-Boot binary (`u-boot-${BOARD}-spi.bin`) and a `*.manifest.json` describing the exact versions used will be available in the current directory.

Available build args:

- `U_BOOT_VERSION`: the U-Boot release tag to build (default: latest stable, kept up to date by Renovate)
- `ATF_VERSION`: the ARM Trusted Firmware release tag (default: latest stable, kept up to date by Renovate)
- `RKBIN_REF`: the rkbin commit to pull the Rockchip DDR/TPL blob from (default: a pinned `master` commit, kept up to date by Renovate)
- `OPTEE`: set to `on` to build and bundle the OP-TEE secure world (BL32); `off` by default
- `OPTEE_VERSION`: the [OP-TEE OS](https://github.com/OP-TEE/optee_os) release to build when `OPTEE=on` (default: latest stable, kept up to date by Renovate)
- `DEFCONFIG`: the U-Boot defconfig to use (`_defconfig` is automatically appended, default: `orangepi-5-rk3588s`)
- `BOARD`: the board name, used in the output filename (default: `orangepi5`)
- `NAME`: the binary output name (default: `u-boot-${BOARD}-spi`)
- `SOURCE_DATE_EPOCH`: Unix timestamp for [reproducible builds](https://reproducible-builds.org/) (optional; CI pins a fixed value)

_As this image bundles the rkbin-provided DDR/TPL blob and an ARM-Trusted-Firmware-built BL31 for rk3588, this build environment can build U-Boot for any rk3588 board by passing the correct `DEFCONFIG` argument._

## Automation

This repo is self-updating:

- [Renovate](https://docs.renovatebot.com/) watches the U-Boot and ARM Trusted Firmware release tags and the rkbin `master` commit (all pinned in the [Dockerfile](Dockerfile)), and the GitHub Actions used by the pipeline.
- When a new version appears, Renovate opens a PR; once CI builds both boards successfully, the PR is auto-merged.
- A merge to `main` builds the binaries and publishes a new signed release automatically, tagged with the U-Boot version.

In short: a new upstream U-Boot, ATF or rkbin release ends up as a signed GitHub release with no manual steps.

To avoid spending CI minutes on untrusted contributions, the build only runs for pushes to `main`, Renovate PRs, PRs from the repository owner, and PRs labelled `build` (maintainers can add the label to run CI on an external PR). Build layers are cached on `ghcr.io`, shared across branches, so a build validated in a PR is reused unchanged once it lands on `main`.

## License

The U-Boot source code is licensed under the GPL-2.0 license. So this repo too.
