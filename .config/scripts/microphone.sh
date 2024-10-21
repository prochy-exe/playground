#!/bin/bash

status() {
	VOLUME=$(pamixer --default-source --get-volume-human)
	case $VOLUME in

		"muted") echo "{\"text\": \"   $(pamixer --default-source --get-volume)%\", \"tooltip\": \"   $(pamixer --default-source --get-volume)%\", \"class\": \"muted\"}" ;;
		*) echo "{\"text\": \"  ${VOLUME}\", \"tooltip\": \"  ${VOLUME}\", \"class\": \"unmuted\"}" ;;
	esac
}

listen() {
	status

	LANG=EN; pactl subscribe | while read event; do
		if echo "$event" | grep -q "source"; then
			status
		fi
	done
}

listen
