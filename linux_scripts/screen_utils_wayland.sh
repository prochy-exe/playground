#!/bin/bash

usage () {
    echo "Screen Utils: a bash script used for screenshotting and screen recording"
    echo "Usage: "
    echo "  screen_utils.sh ![options] !r[audio options] ![input options] [--clipboard|c]"
    echo "  !=required"
    echo "  !r=required for recording, don't use otherwise"
    echo ""
    echo "Options:"
    echo "  ss|screenshot    take screenshot"
    echo "  sr|screenrecord  start screen recording"
    echo ""
    echo "Audio options: "
    echo "  --audio|a to record system audio using default PulseAudio output"
    echo "  --mic|mc to record microphone input"
    echo "  --both|b to record both microphone and system audio"
    echo "  --no-audio|n to record without audio"
    echo ""
    echo "Input options: "
    echo "  --fullscreen|f to select all monitors"
    echo "  --monitor|m(=monitor_options) to select a focused monitor, or specify a monitor using the monitor options"
    echo "  --select|s to select a region or window"
    echo ""
    echo "Monitor options: "
    echo "  {monitor_name} to select a monitor by name"
    echo "  {monitor_index} to select a monitor by index (doesn't always follow physical order)"
    echo "  primary to select the primary monitor"
    echo "  focused to select the active/focused monitor"
    echo ""
    echo "If c or --clipboard is specified the output will be copied to the clipboard"
    echo "In both cases the output will be saved to ~/Screenrecords/ or ~/Screenshots/ respectively"
    echo ""
    echo "Examples: "
    echo "  screen_utils.sh ss m=1 c      # Take screenshot of monitor 1 (index 0) and copy to clipboard"
    echo "  screen_utils.sh ss m        # Take screenshot of the focused monitor"
    echo "  screen_utils.sh sr both m     # Record the focused monitor with both microphone and system audio"
    echo "  screen_utils.sh sr mc m=1     # Record monitor 1 with microphone input"
}

timestamp() {
  date +"%Y-%m-%d_%H-%M-%S"
}

timestamp_partial() {
  date +"%Y-%m-%d"
}

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
    MONITOR_INFO=$(wlr-randr | grep -A1 -i "$1" | tail -n1 | awk '{print $1}')
    IFS='x' read -r WIDTH HEIGHT <<< "$MONITOR_INFO"
    POSITION=$(wlr-randr | grep -A1 -i "$1" | tail -n1 | awk '{print $2}' | sed 's/+/,/g')
    IFS=',' read -r X Y <<< "$POSITION"
}

# Function to get monitor by index using wlr-randr
get_monitor_by_index() {
    index="$(($1-1))"
    if [[ $index -lt 0 ]]; then
        echo "Invalid monitor index, must be greater than 0 (index starts at 1)"
        exit 1
    fi

    INDEX_NAME=$(wlr-randr | grep -oP '^[a-zA-Z0-9-]+' | sed -n "$(($index + 1))p")
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
    else 
        PRESEL_MONITOR=$1
        re='^[0-9]+$'
        if [[ "$PRESEL_MONITOR" == "focused" ]]; then
            SELECTED_MONITOR="$(get_focused_monitor)"
        elif [[ $PRESEL_MONITOR =~ $re ]]; then
            SELECTED_MONITOR="$(get_monitor_by_index $PRESEL_MONITOR)"
        fi
        if [[ "$?" != "0" ]]; then
            exit 1
        fi
        get_monitor_info "$SELECTED_MONITOR"
    fi
}

get_window_coordinates() {
    case "$ENVIRONMENT" in
        "sway")
            swaymsg -t get_tree | jq -r '.. | (.nodes? // empty)[] | select(.pid and .visible) | .rect | "\(.x),\(.y) \(.width)x\(.height)"'
            ;;
        "hyprland")
            ACTIVE_WORKSPACE=$(hyprctl activeworkspace | grep ID | awk '{print $3}')
            hyprctl clients -j | jq -r --argjson ACTIVE_WORKSPACE $ACTIVE_WORKSPACE '.[] | select(.workspace.id == $ACTIVE_WORKSPACE) | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"'
            ;;
        *)
            echo "Unsupported environment"
            exit 1
            ;;
    esac
}


copyfiletoclipboard() {
  echo -e "file:/$OUTPUT_FILE\n" | xclip -selection clipboard -t text/uri-list
}

screenrecord() {
    # Function to clean up before exiting
    cleanup() {
        echo "Cleaning up..."
        killall ffmpeg
        NOT_MESSAGE="Screenrecording finished and saved to $OUTPUT_FILE"
        echo $CLIPBOARD
        if [[ ! -z $CLIPBOARD ]]; then
            NOT_MESSAGE="Screenrecording finished, saved to $OUTPUT_FILE and copied to clipboard"
            copyfiletoclipboard
        fi
        notify-send Screenrecord "$NOT_MESSAGE"
    }

    TYPE=$1
    AUDIO=$2
    CLIPBOARD=$3

    OUTPUT_FILE="$HOME/Screenrecords/$(timestamp_partial)/"

    if [[ ! -d "$OUTPUT_FILE" ]]; then
        mkdir -p "$OUTPUT_FILE"
    fi

    case $AUDIO in
        --audio|a)
            # Record system audio using default PulseAudio output
            AUDIO_OPTIONS="-f pulse -i $(pactl info | grep 'Default Sink' | awk '{print $3}').monitor"
            AUDIO_TAG="_audio"
            ;;
        --mic|mc)
            # Record microphone audio using default PulseAudio input
            AUDIO_OPTIONS="-f pulse -i $(pactl info | grep 'Default Source' | awk '{print $3}')"
            AUDIO_TAG="_mic"
            ;;
        --both|b)
            # Create a combined audio output for both system and microphone
            SINK=$(pactl info | grep 'Default Sink' | awk '{print $3}').monitor
            SOURCE=$(pactl info | grep 'Default Source' | awk '{print $3}')
            AUDIO_OPTIONS="-f pulse -i $SINK -f pulse -i $SOURCE -filter_complex amix=inputs=2:duration=longest"
            AUDIO_TAG="_both"
            ;;
        --no-audio|n)
            AUDIO_OPTIONS=""
            AUDIO_TAG="_noaudio"
            ;;
        *)
            usage
            help_displayed=true
            ;;
    esac

    case $TYPE in
        --select|s)
            # Use slop to select a region or window
            REGION=$(slop -f "%x,%y,%w,%h,%i")
            IFS=',' read -r X Y WIDTH HEIGHT WINDOW_ID <<< "$REGION"

            if [ -z "$REGION" ]; then
                echo "No region selected."
                exit 1
            fi

            WINDOW_NAME=$(xdotool getwindowclassname $WINDOW_ID)
            if [[ "$?" == 0 ]]; then
                OUTPUT_FILE+="${WINDOW_NAME}_$(timestamp)${AUDIO_TAG}.mp4"
            else
                OUTPUT_FILE+="region_$(timestamp)${AUDIO_TAG}.mp4"
            fi

            ffmpeg -f x11grab -video_size ${WIDTH}x${HEIGHT} -i :0.0+${X},${Y} $AUDIO_OPTIONS -vsync vfr -c:v libx264 -preset ultrafast -tune zerolatency -c:a aac -b:a 192k "$OUTPUT_FILE" &
            ;;
        --fullscreen|f)
            SCREEN_SIZE=$(xdpyinfo | grep dimensions | awk '{print $2}')
            OUTPUT_FILE+="fullscreen_$(timestamp)${AUDIO_TAG}.mp4"
            ffmpeg -f x11grab -video_size $SCREEN_SIZE -i :0.0 $AUDIO_OPTIONS -vsync vfr -c:v libx264 -preset ultrafast -tune zerolatency -c:a aac -b:a 192k "$OUTPUT_FILE" &
            ;;
        --monitor|m)
            select_monitor
            OUTPUT_FILE+="monitor_${SELECTED_MONITOR}_$(timestamp)${AUDIO_TAG}.mp4"
            ffmpeg -f x11grab -video_size ${WIDTH}x${HEIGHT} -i :0.0+${X},${Y} $AUDIO_OPTIONS -vsync vfr -c:v libx264 -preset ultrafast -tune zerolatency -c:a aac -b:a 192k "$OUTPUT_FILE" &
            ;;
        *)
            if [[ "$help_displayed" != "true" ]]; then
                usage
                help_displayed=true
            fi
            ;;
    esac

    if [[ "$help_displayed" == "true" ]]; then
        exit 0
    fi

    echo $$ > /tmp/screenrecordpid

    # Trap signals and run the cleanup function
    trap cleanup SIGTERM SIGINT EXIT

    wait
}

screenrecord_type() {
    FR="Fullscreen screenrecord"
    FRC="Fullscreen screenrecord to clipboard"
    MR="Monitor screenrecord"
    MRC="Monitor screenrecord to clipboard"
    PR="Partial/Window screenrecord"
    PRC="Partial/Window screenrecord to clipboard"

    args=( "$@" )
    if [[ -z $args && "$is_cli" != "true" ]]; then
        type=$(printf "$FR\n$FRC\n$MR\n$MRC\n$PR\n$PRC" | rofi -dmenu -p "Screenrecord type" -hover-select -me-select-entry '' -me-accept-entry MousePrimary)

        if [[ -z $type ]]; then
            exit 0 
        fi

        if echo $type | grep -iqF monitor; then
            OPTIONS+="--monitor"
        elif echo $type | grep -iqF window; then
            OPTIONS+="--select"
        elif echo $type | grep -iqF fullscreen; then
            OPTIONS+="--fullscreen"
        fi

        AP="Record primary device only"
        AM="Record mic only"
        AA="Record mic and primary device"
        AN="Don't record audio"

        audio_mode=$(printf "$AP\n$AM\n$AA\n$AN" | rofi -dmenu -p "Audio mode" -hover-select -me-select-entry '' -me-accept-entry MousePrimary)

        case $audio_mode in
            "$AA") OPTIONS+=" --both" ;;
            "$AP") OPTIONS+=" --audio" ;;
            "$AM") OPTIONS+=" --mic" ;;
            "$AN") OPTIONS+=" --no-audio" ;;
        esac

        if echo $type | grep -iqF clipboard; then
            OPTIONS+=" --copy"
        fi
    else
        OPTIONS="${args[@]}"
    fi

    screenrecord $OPTIONS
}

screenshot() {
    TYPE=$1
    CLIPBOARD=$2

    OUTPUT_FILE="$HOME/Screenshots/$(timestamp_partial)/"

    if [[ ! -d "$OUTPUT_FILE" ]]; then
        mkdir -p "$OUTPUT_FILE"
    fi

    case $TYPE in
        --select|s)
            # Use slop to select a region or window
            REGION=$(slop -f "%x,%y,%w,%h,%i")
            IFS=',' read -r X Y WIDTH HEIGHT WINDOW_ID <<< "$REGION"

            if [ -z "$REGION" ]; then
                echo "No region selected."
                exit 1
            fi

            WINDOW_NAME=$(xdotool getwindowclassname $WINDOW_ID)
            if [[ "$?" == 0 ]]; then
                OUTPUT_FILE+="${WINDOW_NAME}_$(timestamp).png"
                maim -B -i $WINDOW_ID "$OUTPUT_FILE"
            else
                OUTPUT_FILE+="region_$(timestamp).png"
                maim -B -g ${WIDTH}x${HEIGHT}+${X}+${Y} "$OUTPUT_FILE"
            fi
            ;;
        --fullscreen|f)
            OUTPUT_FILE+="fullscreen_$(timestamp).png"
            maim -B "$OUTPUT_FILE" 
            ;;
        --monitor=*|m=*)
            MONITOR="${1#*=}"
            select_monitor "$MONITOR"
            OUTPUT_FILE+="monitor_${SELECTED_MONITOR}_$(timestamp).png"
            maim -B -g ${WIDTH}x${HEIGHT}+${X}+${Y} "$OUTPUT_FILE"
            ;;
        --monitor|m)
            if [[ "$is_cli" == "true" ]]; then
                select_monitor "focused"
            else
                select_monitor
            fi
            OUTPUT_FILE+="monitor_${SELECTED_MONITOR}_$(timestamp).png"
            maim -B -g ${WIDTH}x${HEIGHT}+${X}+${Y} "$OUTPUT_FILE"
            ;;
        *)
            usage
            ;;
    esac

    if [[ ! -z $CLIPBOARD ]]; then
        copyfiletoclipboard &
    fi

}

screenshot_type() {
    FS="Fullscreen screenshot"
    FSC="Fullscreen screenshot to clipboard"
    MS="Monitor screenshot"
    MSC="Monitor screenshot to clipboard"
    PS="Partial/Window screenshot"
    PSC="Partial/Window screenshot to clipboard"

    args=( "$@" )
    if [[ -z $args ]]; then
        if [[ "$is_cli" != "true" || "$dialog" == "true" ]]; then
            type=$(printf "$FS\n$FSC\n$MS\n$MSC\n$PS\n$PSC" | rofi -dmenu -p "Screenshot type" -hover-select -me-select-entry '' -me-accept-entry MousePrimary)
            if [[ -z $type ]]; then
                exit 0 
            fi

            if echo $type | grep -iqF monitor; then
                OPTIONS+="--monitor"
            elif echo $type | grep -iqF window; then
                OPTIONS+="--select"
            elif echo $type | grep -iqF fullscreen; then
                OPTIONS+="--fullscreen"
            fi

            if echo $type | grep -iqF clipboard; then
                OPTIONS+=" --copy"
            fi
        fi
    else 
        OPTIONS="${args[@]}"
    fi

    screenshot $OPTIONS
}

type_picker(){
    SS=Screenshot
    SR=Screenrecord

    type_pick=$(printf "$SS\n$SR" | rofi -dmenu -p "Screen Shot/Record" -hover-select -me-select-entry '' -me-accept-entry MousePrimary)

    case $type_pick in
        $SS) screenshot_type;;
        $SR) screenrecord_type;;
        *) exit 0;;
    esac
}

if [[ -f "/tmp/screenrecordpid" ]]; then
    kill -2 $(cat /tmp/screenrecordpid) > /dev/null
    if [[ "$?" == 0 ]]; then
        exit 0
    fi
    if [[ -f "/tmp/screenrecordpid" ]]; then
        rm /tmp/screenrecordpid
    fi
fi

if [[ ! -z $1 ]]; then
    is_cli=true
    if [[ $1 == "dialogs" || $1 == "d" ]]; then
        dialogs=true
        type_variable="$2"
        shift 2
        args=( "$@" )
    else
        shift 1
        args=( "$@" )
        type_variable="$1"
    fi
    if [[ "$type_variable" == "screenshot" || "$type_variable" == "ss" ]]; then
        screenshot_type "${args[@]}"
    elif [[ "$type_variable" == "screenrecord" || "$type_variable" == "sr" ]]; then
        screenrecord_type "${args[@]}"
    else
        if [[ "$dialogs" == "true" ]]; then
            type_picker
        else
            usage
        fi
    fi
else
    type_picker
fi


