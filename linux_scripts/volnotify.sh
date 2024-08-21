#/usr/bin/bash

USEPLAYERCTL=$1
if [[ $USEPLAYERCTL -eq 1 ]]
then
    FLOAT_VOL=$(playerctl -p spotify,vlc,mpv,jellyfin volume)
    VOL=$(echo "$FLOAT_VOL * 100" | bc | awk '{printf"%.0f\n",$1}')
else
    VOL="$(pamixer --get-volume)"
fi

if [[ $USEPLAYERCTL -eq 1 ]]
then
    notify-send --icon="audio-volume-high-symbolic" "$(playerctl -p spotify,vlc,mpv,jellyfin -l): $VOL%" -r 1 -u low -t 500
else
    notify-send --icon="audio-volume-high-symbolic" "$VOL%" -r 1 -u low -t 500
fi
