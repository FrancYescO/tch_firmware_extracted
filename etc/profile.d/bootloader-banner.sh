#!/bin/sh
echo -en "\nBootloader: "
bl_version=$(uci get env.var.bootloader_version)
[[ -n "$bl_version" ]] && echo $bl_version || echo "Unknown"
echo
