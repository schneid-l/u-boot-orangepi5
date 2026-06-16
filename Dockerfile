# syntax=docker/dockerfile:1@sha256:87999aa3d42bdc6bea60565083ee17e86d1f3339802f543c0d03998580f9cb89

# ---------------------------------------------------------------------------
# Versions (single source of truth — declared as global ARGs and inherited by
# every stage). Renovate keeps these up to date; see .github/renovate.json5.
# ---------------------------------------------------------------------------

# renovate: datasource=github-tags depName=u-boot packageName=u-boot/u-boot versioning=loose
ARG U_BOOT_VERSION=v2026.04
# renovate: datasource=github-tags depName=arm-trusted-firmware packageName=ARM-software/arm-trusted-firmware versioning=loose
ARG ATF_VERSION=v2.15.0
# renovate: datasource=github-tags depName=optee_os packageName=OP-TEE/optee_os versioning=semver
ARG OPTEE_VERSION=4.10.0
# rkbin has no tags/releases, so it is pinned to an exact commit of `master`.
# renovate: datasource=git-refs depName=rkbin packageName=https://github.com/rockchip-linux/rkbin currentValue=master
ARG RKBIN_REF=ecb4fcbe954edf38b3ae037d5de6d9f5bccf81f4

# OP-TEE secure-world (BL32) payload: "off" (default) or "on", selected per build.
ARG OPTEE=off

# ---------------------------------------------------------------------------
# Base build environment. The base image is pinned by digest and kept current
# by Renovate (docker:pinDigests).
# ---------------------------------------------------------------------------
FROM ubuntu:26.04@sha256:f3d28607ddd78734bb7f71f117f3c6706c666b8b76cbff7c9ff6e5718d46ff64 AS base

ARG DEBIAN_FRONTEND=noninteractive

# Minimal toolchain to build U-Boot + binman for rk3588. Anything only needed
# by U-Boot's docs/test suite (sphinx, pytest, coccinelle, sdl2, ...) is left
# out on purpose to keep the image small and the build fast.
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean && \
    echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache && \
    apt-get update && apt-get install --no-install-recommends -y \
      bc \
      bison \
      build-essential \
      ca-certificates \
      curl \
      device-tree-compiler \
      flex \
      git \
      libgnutls28-dev \
      libssl-dev \
      lz4 \
      pkg-config \
      python3 \
      python3-dev \
      python3-pycryptodome \
      python3-pyelftools \
      python3-setuptools \
      swig \
      uuid-dev \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# Rockchip blobs (DDR init / TPL). Pinned to an exact rkbin commit.
# ---------------------------------------------------------------------------
FROM base AS rkbin
ARG RKBIN_REF
ARG RKBIN_SOURCE=https://github.com/rockchip-linux/rkbin/archive/${RKBIN_REF}.tar.gz

RUN mkdir -p /src /rkbin && \
    curl -fsSL "${RKBIN_SOURCE}" | tar -xz -C /src --strip-components=1 && \
    ddr="$(ls -1 /src/bin/rk35 | grep -E 'rk3588_ddr_lp4_2112MHz_lp5_2400MHz_v[0-9.]+\.bin' | sort -V | tail -n1)" && \
    test -n "${ddr}" && \
    cp "/src/bin/rk35/${ddr}" /rkbin/tpl.bin && \
    echo "${ddr}" | sed -E 's/.*_v([0-9.]+)\.bin/\1/' > /rkbin/ddr.version

# ---------------------------------------------------------------------------
# Arm Trusted Firmware (BL31)
# ---------------------------------------------------------------------------
FROM base AS arm-trusted-firmware
ARG ATF_VERSION
ARG ATF_SOURCE=https://github.com/ARM-software/arm-trusted-firmware/archive/refs/tags/${ATF_VERSION}.tar.gz

RUN mkdir -p /atf/src && \
    curl -fsSL "${ATF_SOURCE}" | tar -xz -C /atf/src --strip-components=1

WORKDIR /atf/src
RUN --mount=type=cache,target=/atf/src/build \
    CFLAGS=--param=min-pagesize=0 make -j"$(nproc)" DEBUG=0 PLAT=rk3588 bl31 && \
    cp build/rk3588/release/bl31/bl31.elf /atf/bl31.elf

# ---------------------------------------------------------------------------
# OP-TEE secure-world (BL32), built from source only when OPTEE=on. `tee-off`
# is an empty placeholder so the default build never pulls in the OP-TEE stage.
# ---------------------------------------------------------------------------
FROM base AS tee-off
RUN mkdir -p /optee

FROM base AS tee-on
ARG OPTEE_VERSION
ARG OPTEE_SOURCE=https://github.com/OP-TEE/optee_os/archive/refs/tags/${OPTEE_VERSION}.tar.gz

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install --no-install-recommends -y python3-cryptography

RUN mkdir -p /optee/src && \
    curl -fsSL "${OPTEE_SOURCE}" | tar -xz -C /optee/src --strip-components=1

WORKDIR /optee/src
RUN make -j"$(nproc)" PLATFORM=rockchip-rk3588 CFG_ARM64_core=y CFG_USER_TA_TARGETS=ta_arm64 CROSS_COMPILE64= O=out && \
    cp out/core/tee.elf /optee/tee.elf

# Resolves to tee-off or tee-on depending on the OPTEE build arg.
FROM tee-${OPTEE} AS tee

# ---------------------------------------------------------------------------
# U-Boot source
# ---------------------------------------------------------------------------
FROM base AS u-boot-source
ARG U_BOOT_VERSION
ARG U_BOOT_SOURCE=https://github.com/u-boot/u-boot/archive/refs/tags/${U_BOOT_VERSION}.tar.gz

RUN mkdir -p /u-boot/src && \
    curl -fsSL "${U_BOOT_SOURCE}" | tar -xz -C /u-boot/src --strip-components=1

# ---------------------------------------------------------------------------
# U-Boot build
# ---------------------------------------------------------------------------
FROM base AS u-boot-builder
ARG U_BOOT_VERSION
ARG ATF_VERSION
ARG RKBIN_REF
ARG OPTEE_VERSION
ARG SOURCE_DATE_EPOCH

ARG BOARD=orangepi5
ARG NAME=u-boot-${BOARD}-spi
ARG DEFCONFIG=orangepi-5-rk3588s

COPY --from=u-boot-source /u-boot/src /u-boot/src
COPY --from=rkbin /rkbin /rkbin
COPY --from=arm-trusted-firmware /atf /atf
COPY --from=tee /optee /optee

ENV ROCKCHIP_TPL=/rkbin/tpl.bin
ENV BL31=/atf/bl31.elf
ENV ARCH=arm64
# Honour reproducible-builds timestamp inside U-Boot itself.
ENV SOURCE_DATE_EPOCH=${SOURCE_DATE_EPOCH}

# When OP-TEE was built (OPTEE=on), /optee/tee.elf exists and is fed to binman.
WORKDIR /u-boot/src
RUN --mount=type=cache,target=/u-boot/build \
    if [ -f /optee/tee.elf ]; then export TEE=/optee/tee.elf; fi && \
    make O=/u-boot/build -j"$(nproc)" "${DEFCONFIG}_defconfig" && \
    make O=/u-boot/build -j"$(nproc)" HOSTLDLIBS_mkimage="-lssl -lcrypto"

WORKDIR /u-boot
RUN --mount=type=cache,target=/u-boot/build \
    mkdir -p out && \
    cp build/u-boot-rockchip-spi.bin "out/${NAME}.bin" && \
    if [ -f /optee/tee.elf ]; then optee="${OPTEE_VERSION}"; else optee="none"; fi && \
    printf '{\n  "board": "%s",\n  "u_boot_version": "%s",\n  "atf_version": "%s",\n  "rkbin_ref": "%s",\n  "rkbin_ddr_version": "v%s",\n  "optee_version": "%s",\n  "source_date_epoch": "%s"\n}\n' \
      "${BOARD}" "${U_BOOT_VERSION}" "${ATF_VERSION}" "${RKBIN_REF}" "$(cat /rkbin/ddr.version)" "${optee}" "${SOURCE_DATE_EPOCH}" \
      > "out/${NAME}.manifest.json"

# ---------------------------------------------------------------------------
# Final export stage — `--output type=local,dest=.` writes these files to the
# build context directory. No OCI image is published; releases ship the .bin.
# ---------------------------------------------------------------------------
FROM scratch AS u-boot
COPY --from=u-boot-builder /u-boot/out/* /
