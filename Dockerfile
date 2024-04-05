# syntax=docker/dockerfile:1

FROM ubuntu:22.04 AS base

ARG SOURCE_DATE_EPOCH
ARG DEBIAN_FRONTEND=noninteractive

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean; \
    echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache && \
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone && \
    apt-get update && apt-get install --no-install-recommends -y \
    bc \
    bison \
    build-essential \
    ca-certificates \
    coccinelle \
    curl \
    device-tree-compiler \
    dfu-util \
    efitools \
    flex \
    gdisk \
    git \
    graphviz \
    imagemagick \
    liblz4-tool \
    libgnutls28-dev \
    libguestfs-tools \
    libncurses-dev \
    libpython3-dev \
    libsdl2-dev \
    libssl-dev \
    lz4 \
    lzma \
    lzma-alone \
    openssl \
    pkg-config \
    python3 \
    python3-asteval \
    python3-coverage \
    python3-filelock \
    python3-pkg-resources \
    python3-pycryptodome \
    python3-pyelftools \
    python3-pytest \
    python3-pytest-xdist \
    python3-sphinxcontrib.apidoc \
    python3-sphinx-rtd-theme \
    python3-subunit \
    python3-testtools \
    python3-virtualenv \
    swig \
    uuid-dev \
    && rm -rf /var/lib/apt/lists/*

FROM base AS u-boot-downloader

ARG SOURCE_DATE_EPOCH
ARG U_BOOT_VERSION=v2024.04
ARG U_BOOT_SOURCE=https://source.denx.de/u-boot/u-boot/-/archive/${U_BOOT_VERSION}/u-boot-${U_BOOT_VERSION}.tar.gz

RUN mkdir -p /u-boot && \
    curl -L ${U_BOOT_SOURCE} | tar -xz -C /u-boot --strip-components=1

FROM base AS rkbin-downloader

ARG SOURCE_DATE_EPOCH
ARG RKBIN_SOURCE=https://github.com/rockchip-linux/rkbin/archive/refs/heads/master.tar.gz

RUN mkdir -p /src && \
    mkdir -p /rkbin && \
    curl -L ${RKBIN_SOURCE} | tar -xz -C /src --strip-components=1 && \
    cp /src/bin/rk35/$(ls -1 /src/bin/rk35 | grep -E 'rk3588_ddr_lp4_2112MHz_lp5_2400MHz_v[0-9.]+.bin' | tail -n 1) /rkbin/tpl.bin && \
    cp /src/bin/rk35/$(ls -1 /src/bin/rk35 | grep -E 'rk3588_bl31_v[0-9.]+.elf' | tail -n 1) /rkbin/bl31.bin

FROM base AS u-boot-builder

ARG SOURCE_DATE_EPOCH

COPY --from=u-boot-downloader /u-boot /u-boot/src
COPY --from=rkbin-downloader /rkbin /rkbin

ARG U_BOOT_VERSION=v2024.04
ARG BOARD=orangepi5
ARG NAME=u-boot-${U_BOOT_VERSION}-${BOARD}-spi
ARG DEFCONFIG=orangepi-5-rk3588s

ENV ROCKCHIP_TPL=/rkbin/tpl.bin
ENV BL31=/rkbin/bl31.bin
ENV ARCH=arm64

WORKDIR /u-boot/src
RUN --mount=type=cache,target=/u-boot/build \
    make O=/u-boot/build -j$(nproc) ${DEFCONFIG}_defconfig && \
    make O=/u-boot/build -j$(nproc) HOSTLDLIBS_mkimage="-lssl -lcrypto"

WORKDIR /u-boot
RUN --mount=type=cache,target=/u-boot/build \
    mkdir -p out && \
    cp -r build/u-boot-rockchip-spi.bin out/${NAME}.bin

FROM scratch AS u-boot

ARG SOURCE_DATE_EPOCH

ARG U_BOOT_VERSION=v2024.04
ARG BOARD=orangepi5
ARG IMAGE_NAME="${BOARD}-u-boot-${U_BOOT_VERSION}"
ARG IMAGE_TITLE="Orange Pi 5 U-Boot ${U_BOOT_VERSION}"
ARG IMAGE_DESCRIPTION="U-Boot ${U_BOOT_VERSION}} for Orange Pi 5"
ARG IMAGE_SOURCE="https://github.com/si0ls/u-boot-orangepi5"
ARG IMAGE_AUTHORS="Louis S. <louis@schne.id>"
ARG IMAGE_VENDOR="Denx Software Engineering"
ARG IMAGE_VERSION=$U_BOOT_VERSION

LABEL org.opencontainers.image.name $IMAGE_NAME
LABEL org.opencontainers.image.title $IMAGE_TITLE
LABEL org.opencontainers.image.description $IMAGE_DESCRIPTION
LABEL org.opencontainers.image.source $IMAGE_SOURCE
LABEL org.opencontainers.image.authors $IMAGE_AUTHORS
LABEL org.opencontainers.image.vendor $IMAGE_VENDOR
LABEL org.opencontainers.image.version $IMAGE_VERSION

COPY --from=u-boot-builder /u-boot/out/* /
