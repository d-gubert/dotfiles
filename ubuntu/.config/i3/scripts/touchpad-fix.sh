#!/bin/zsh

inputid=$(xinput list | awk '/Touch/{idx=match($0, "id=[0-9]+");id=substr($0,idx+3,RLENGTH-3);print id}')

xinput set-prop $inputid "libinput Tapping Enabled" 1
xinput set-prop $inputid "libinput Natural Scrolling Enabled" 1
