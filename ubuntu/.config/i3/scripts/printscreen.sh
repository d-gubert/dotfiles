#!/bin/zsh

FNAME=~/Pictures/Screenshots/Screenshot-$(date -Iseconds | cut -d'+' -f1).png
maim -s $FNAME
if [ $? -ne 0 ]; then
    exit 1
fi

xclip -selection clipboard -t image/png -i $FNAME
