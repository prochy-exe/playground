#!/usr/bin/sh
CURR_WORK=$(hyprctl monitors | grep active | awk '{print $3}')
MODE=$1

if [[ "$MODE" == "f" ]]; then
    if [[ "$CURR_WORK" == "5" ]]; then
        hyprctl dispatch workspace r~1
    else
        hyprctl dispatch workspace r+1
    fi
elif [[ "$MODE" == "b" ]]; then
    if [[ "$CURR_WORK" == "1" ]]; then
        hyprctl dispatch workspace r~5
    else
        hyprctl dispatch workspace r-1
    fi
fi