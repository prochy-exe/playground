#!/bin/bash

echo " No Media"
playerctl -p spotify,vlc,mpv,jellyfin metadata -f '{{status}} {{playerName}}: {{title}}' -F 2>/dev/null | while read event; do
    out=$(playerctl -p spotify,vlc,mpv,jellyfin metadata -f '{{status}} {{playerName}}: {{title}}' 2>/dev/null)
    if [[ -z $out ]]; then
	    echo "  No Media"
    else
	echo $out | sed 's/Paused/ /; s/Playing/ /; s/Stopped/ /;'
    fi
done
