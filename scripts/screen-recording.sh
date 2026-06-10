# ffmpeg v6.1.1

tlrec() {
	# input from x11, external monitor (:1), start position at 1920,20, using nvidia gpu
	ffmpeg -f x11grab -video_size 1920x1060 -i :1+1920,20 -c:v h264_nvenc -preset p2 output.mp4
}


# List monitor
#echo $DISPLAY
#xrandr --listmonitors

# Check for encoders to make sure we use GPU
#ffmpeg -encoders 2>/dev/null | grep -E 'nvenc|vaapi|qsv'

# Check mic, prefer dsnoop
#arecord -L

# Record with external USB, add before output.mp4
# -f alsa -i dsnoop:CARD=GM300,DEV=0
