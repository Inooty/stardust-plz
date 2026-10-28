#!/bin/sh
printf '\033c\033]0;%s\a' STARDUST PLZ
base_path="$(dirname "$(realpath "$0")")"
"$base_path/sdp-linux.x86_64" "$@"
