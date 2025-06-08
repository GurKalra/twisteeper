#!/bin/sh
echo -ne '\033c\033]0;minesweeper_tut\a'
base_path="$(dirname "$(realpath "$0")")"
"$base_path/Twisteeper.x86_64" "$@"
