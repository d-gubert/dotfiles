#!/bin/bash

# Simple file upload test with memory monitoring
# Used to test memory consumption during file uploads in Rocket.Chat
#
# Usage: ./upload-test.sh [SIZE_MB] [CHANNEL_NAME]
SIZE_MB=${1:-100}
CHANNEL=${2:-GENERAL}
FILE="/tmp/test-${SIZE_MB}mb.bin"

get_memory() {
    local pid=$(ps aux | grep "node.*main.js" | grep -v grep | awk '{print $2}' | tail -1)
    if [ -n "$pid" ]; then
        ps -o rss= -p $pid 2>/dev/null | awk '{print $1/1024}'
    else
        echo "0"
    fi
}

# Create file if needed
if [ ! -f "$FILE" ]; then
    echo "Creating ${SIZE_MB}MB file..."
    dd if=/dev/zero of="$FILE" bs=1M count=$SIZE_MB 2>/dev/null
fi

# Login
echo "Logging in..."
LOGIN=$(curl -s -X POST "http://localhost:3000/api/v1/login" \
    -H "Content-Type: application/json" \
    -d '{"user":"rocketchat.internal.admin.test","password":"rocketchat.internal.admin.test"}')
	# -d '{"user":"dgubert","password":"1"}')

TOKEN=$(echo $LOGIN | jq -r '.data.authToken')
USER_ID=$(echo $LOGIN | jq -r '.data.userId')

if [ "$TOKEN" = "null" ]; then
    echo "Login failed"
    exit 1
fi

# Start monitoring
MONITOR_LOG="/tmp/memory-$$.log"
> $MONITOR_LOG
(while true; do echo "$(date +%s),$(get_memory)" >> $MONITOR_LOG; sleep 0.2; done) &
MONITOR_PID=$!

# Get room ID (try as room ID first, then as room name)
ROOM=$(curl -s -X GET "http://localhost:3000/api/v1/rooms.info?roomId=$CHANNEL" \
    -H "X-Auth-Token: $TOKEN" \
    -H "X-User-Id: $USER_ID" 2>/dev/null)
ROOM_ID=$(echo $ROOM | jq -r '.room._id' 2>/dev/null)

# If not found by ID, try by name
if [ "$ROOM_ID" = "null" ] || [ -z "$ROOM_ID" ]; then
    ROOM=$(curl -s -X GET "http://localhost:3000/api/v1/rooms.info?roomName=$CHANNEL" \
        -H "X-Auth-Token: $TOKEN" \
        -H "X-User-Id: $USER_ID")
    ROOM_ID=$(echo $ROOM | jq -r '.room._id')
fi

if [ "$ROOM_ID" = "null" ] || [ -z "$ROOM_ID" ]; then
    echo "Channel '$CHANNEL' not found"
    exit 1
fi

# See if there are apps installed
APPS=$(curl -s -X GET "http://localhost:3000/api/apps/installed" \
        -H "X-Auth-Token: $TOKEN" \
		-H "X-User-Id: $USER_ID")
INSTALLED=$(echo $APPS | jq -r 'if (.apps | length > 0) then "apps installed" else "no apps" end')

echo $INSTALLED

# Upload
echo "Uploading ${SIZE_MB}MB file to channel '$CHANNEL' (ID: $ROOM_ID)..."
BEFORE=$(get_memory)
echo curl -s -X POST "http://localhost:3000/api/v1/rooms.media/$ROOM_ID" \
    -H "X-Auth-Token: $TOKEN" \
    -H "X-User-Id: $USER_ID" \
    -F "file=@$FILE;filename=test-file"
time curl -s -X POST "http://localhost:3000/api/v1/rooms.media/$ROOM_ID" \
    -H "X-Auth-Token: $TOKEN" \
    -H "X-User-Id: $USER_ID" \
    -F "file=@$FILE;filename=test-file"

echo "Upload finished, waiting 2s for GC..."
sleep 2
AFTER=$(get_memory)

# Stop monitoring
kill $MONITOR_PID 2>/dev/null
PEAK=$(cat $MONITOR_LOG | cut -d',' -f2 | sort -n | tail -1)
RATIO=$(awk -v peak="$PEAK" -v baseline="$BEFORE" -v size="$SIZE_MB" 'BEGIN {printf "%.2f", (peak-baseline)/size}')

echo ""
echo "Memory Usage:"
echo "  Before: ${BEFORE} MB"
echo "  Peak:   ${PEAK} MB"
echo "  After:  ${AFTER} MB"
echo "  Ratio:  ${RATIO}x"
echo ""

# Check if under 4GB
if (( $(awk -v p="$PEAK" 'BEGIN {print (p>4096)?1:0}') )); then
    echo "⚠️  Exceeded 4GB limit!"
else
    echo "✓  Stayed under 4GB"
fi

