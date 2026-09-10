#!/bin/bash

set -e

D=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

if [ "$(whoami)" != 'root' ]; then
    echo 'Script needs to be run as root.'
    exit 1
fi

cd /boot/grub/themes/
rm -rf crossgrub
mkdir -p crossgrub
cd crossgrub
# Шрифты перечислены поимённо, а не по маске *.pf2. Причина: grub-mkconfig
# (/etc/grub.d/00_header:280-287) генерирует loadfont на КАЖДЫЙ .pf2 в
# каталоге темы, не проверяя, нужен ли он. По маске сюда попадали
# PixelFont30.pf2 (803 KB) и Monocraft22.pf2, на которые theme.txt не
# ссылается — GRUB читал их с vfat /boot при каждой загрузке впустую.
# Источник истины — строки *font в theme.txt: сейчас это только
# "Terminess Nerd Font Mono Regular" в размерах 22 и 28. Меняешь тему —
# сверь этот список с theme.txt.
cp "$D"/assets/*.png "$D"/theme.txt \
   "$D"/Terminess22.pf2 "$D"/Terminess28.pf2 .

echo Installed to /boot/grub/themes
