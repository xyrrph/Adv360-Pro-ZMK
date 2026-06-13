#!/usr/bin/env bash

set -eu

PWD=$(pwd)
TIMESTAMP="${TIMESTAMP:-$(date -u +"%Y%m%d%H%M")}"
COMMIT="${COMMIT:-$(echo xxxxxx)}"

# legacy版をビルドする場合は CLIQUE を空にする (引数なしの場合はClique版をビルド)
if [ "${BUILD_TYPE:-}" = "legacy" ]; then
    CLIQUE=""
else
    CLIQUE=1
fi
FIRMWARE_SUFFIX=${CLIQUE:+-clique}

# West Build (left)
west build -s zmk/app -p -d build/left -b adv360_left ${CLIQUE:+-S studio-rpc-usb-uart} -- -DZMK_CONFIG="${PWD}/config" ${CLIQUE:+-DCONFIG_ZMK_STUDIO=y}
# Adv360 Left Kconfig file
grep -vE '(^#|^$)' build/left/zephyr/.config
# Rename zmk.uf2
cp build/left/zephyr/zmk.uf2 "./firmware/${TIMESTAMP}-${COMMIT}-left${FIRMWARE_SUFFIX}.uf2"

# Build right side if selected
if [ "${BUILD_RIGHT}" = true ]; then
    # West Build (right)
    west build -s zmk/app -p -d build/right -b adv360_right -- -DZMK_CONFIG="${PWD}/config"
    # Adv360 Right Kconfig file
    grep -vE '(^#|^$)' build/right/zephyr/.config
    # Rename zmk.uf2
    cp build/right/zephyr/zmk.uf2 "./firmware/${TIMESTAMP}-${COMMIT}-right${FIRMWARE_SUFFIX}.uf2"
fi
