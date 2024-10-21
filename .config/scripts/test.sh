#!/bin/bash

get_focused_monitor() {
    # Get the current mouse coordinates using slurp
    read MOUSE_X MOUSE_Y <<< $(slurp -f "%x %y" -o)

    # Loop through outputs (monitors) and find the one containing the mouse position
    while IFS= read -r line; do
        if [[ $line =~ ^([a-zA-Z0-9-]+)\ ([0-9]+)x([0-9]+)\+([0-9]+)\+([0-9]+) ]]; then
            MONITOR_NAME=${BASH_REMATCH[1]}
            WIDTH=${BASH_REMATCH[2]}
            HEIGHT=${BASH_REMATCH[3]}
            X=${BASH_REMATCH[4]}
            Y=${BASH_REMATCH[5]}

            # Check if mouse is within the bounds of this monitor
            if (( MOUSE_X >= X && MOUSE_X <= X + WIDTH && MOUSE_Y >= Y && MOUSE_Y <= Y + HEIGHT )); then
                echo $MONITOR_NAME
                return
            fi
        fi
    done <<< "$(wlr-randr)"

    exit 1
}

# Function to get monitor information (width, height, position) using wlr-randr
get_monitor_info() {
    MONITOR_INFO=$(wlr-randr --json | jq -r --arg MONITOR_NAME "$1" '.[] | select(.name == $MONITOR_NAME)')
    X=$(echo "$MONITOR_INFO" | jq -r '.position.x')
    Y=$(echo "$MONITOR_INFO" | jq -r '.position.y')
    WIDTH=$(echo "$MONITOR_INFO" | jq -r '.modes.[] | select(.current == true) | .width')
    HEIGHT=$(echo "$MONITOR_INFO" | jq -r '.modes.[] | select(.current == true) | .height')
}

# Function to get monitor by index using wlr-randr
get_monitor_by_index() {
    index="$(($1-1))"
    MONITOR_COUNT=$(wlr-randr --json | jq -r '. | length - 1')
    REAL_MONITOR_COUNT=$(wlr-randr --json | jq -r '. | length')
    if [[ $index -lt 0 ]]; then
        echo "Invalid monitor index, must be greater than 0 (index starts at 1)"
        exit 1
    fi

    if [[ $index -gt $MONITOR_COUNT ]]; then
        echo "Invalid monitor index, you have only $REAL_MONITOR_COUNT monitors"
        exit 1
    fi

    INDEX_NAME=$(wlr-randr --json | jq -r --argjson INDEX $index '.[$INDEX] | .name')
    if [ -z "$INDEX_NAME" ]; then
        echo "Monitor $index not found"
        exit 1
    fi
    echo "$INDEX_NAME"
}

# Main function for selecting a monitor
select_monitor() {
    if [ -z "$1" ]; then
        # Use rofi to select a monitor
        MONITORS=$(wlr-randr | grep -oP '^[a-zA-Z0-9-]+')
        SELECTED_MONITOR=$(echo "$MONITORS" | rofi -dmenu -p "Select Monitor:" -hover-select -me-select-entry '' -me-accept-entry MousePrimary)

        if [ -z "$SELECTED_MONITOR" ]; then
            echo "No monitor selected."
            exit 1
        fi
        get_monitor_info "$SELECTED_MONITOR"
        MON_INF="$X,$Y $WIDTH"x"$HEIGHT"
    else 
        PRESEL_MONITOR=$1
        re='^[0-9]+$'
        if [[ "$PRESEL_MONITOR" == "focused" ]]; then
            SELECTED_MONITOR="$(get_focused_monitor)"
        elif [[ $PRESEL_MONITOR =~ $re ]]; then
            SELECTED_MONITOR="$(get_monitor_by_index $PRESEL_MONITOR)"
        fi
        echo "Selected monitor: $SELECTED_MONITOR"
        if [[ "$?" != "0" ]]; then
            exit 1
        fi
        get_monitor_info "$SELECTED_MONITOR"
        MON_INF="$X,$Y $WIDTH"x"$HEIGHT"
    fi
    echo "$MON_INF"
}

select_monitor "$1"