#!/bin/bash

handle_event() {
  case $1 in
    openwindow* | closewindow*)
      # Get the active workspace ID
      WORKSPACE_ID=$(hyprctl activeworkspace | grep ID | awk '{print $3}')

      # Count the number of windows in the active workspace
      WINDOW_COUNT=$(hyprctl clients | grep "workspace: $WORKSPACE_ID" | wc -l)

      # Apply rule if there's only one window
      if [ "$WINDOW_COUNT" -eq 1 ]; then
          # Apply desired rules for one window
          hyprctl setprop tiled "nodim noblur norounding"
      else
          # Revert or apply different rules when there are multiple windows
          hyprctl setprop tiled "nodim 0 noblur 0 norounding 0"
      fi
      ;;
  esac
}

# Listen for events and pass them to the handler function
socat -U - UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock | while read -r line; do
  handle_event "$line"
done
