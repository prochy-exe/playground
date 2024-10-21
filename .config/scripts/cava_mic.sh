#!/bin/bash

# Set the bar characters
bar="▁▂▃▄▅▆▇█"
dict="s/;//g;"

# Creating "dictionary" to replace index with bar characters
i=0
while [ $i -lt ${#bar} ]; do
    dict="${dict}s/$i/${bar:$i:1}/g;"
    i=$((i + 1))
done

# Define the FIFO pipe location
pipe="/tmp/cava_mic.fifo"

# Clean up existing FIFO pipe if it exists
if [ -p $pipe ]; then
    unlink $pipe
fi
mkfifo $pipe

# Write cava configuration
config_file="/tmp/cava_mic_config"
echo "
[general]
bars = 10

[input]
method = pulse
source = Mic

[output]
method = raw
raw_target = $pipe
data_format = ascii
ascii_max_range = 7
" > "$config_file"

# Run cava in the background
cava -p "$config_file" &

# Reading data from the FIFO
while read -r cmd; do
    echo $cmd | sed $dict
done < $pipe
