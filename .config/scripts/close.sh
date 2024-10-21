#! /bin/bash

CURRENT_WINDOW=$(xdotool getactivewindow getwindowclassname)
CURRENT_WINDOW_ID=$(xdotool getactivewindow )

if [[ $CURRENT_WINDOW == "Spotify" ]]; then
    spotify -t
elif [[ $CURRENT_WINDOW == "Carla2" ]]; then
    xdotool windowunmap $CURRENT_WINDOW_ID
else
    bspc node pointed -c
fi