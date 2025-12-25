#!/bin/zsh

max=$(brightnessctl max)
step=$((max / 20))  # 5% of max

if [ "$1" = "up" ]; then
    brightnessctl set "+${step}"
else
    brightnessctl set "${step}-"
fi
