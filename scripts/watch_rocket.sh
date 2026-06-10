#!/bin/zsh

# PROC_LIST_CMD=" | awk '{print substr(\$0, index(\$0, \$4))}'"

# typeset -A rocketProcesses=()
#
# function _WATCHRC_listProcs() {
# 	# Meteor starts up multiple process in development, but we're only interested in the output of 
# 	# ps aww -D %s -o pid=,ppid=,lstart=,command= | grep -e 'RocketChat.*main.js' | grep -v 'grep'
# 	ps aww -D %s -o pid=,ppid=,lstart=,command= | grep -i 'meteor' | grep -v 'grep'
# }
#
# function _WATCHRC_parseProcs() {
# 	listProc | while read line; do
# 		read pid
# 	done
# }

_WATCHRC_rcWatcherPath=/tmp/rc-watcher
_WATCHRC_pipe=$_WATCHRC_rcWatcherPath.pipe
_WATCHRC_status=$_WATCHRC_rcWatcherPath.status

function _WATCHRC_watchPipe() {
	local it=0
	local pid=$$

	echo "$(date +%Y-%m-%dT%H:%M:%SZ) STARTING WATCHER i=$it pid=$pid" > $_WATCHRC_rcWatcherPath.log
	echo "IDLE" > $_WATCHRC_status

	while true; do
		if [[ ! -e $_WATCHRC_pipe ]]; then
			echo "$(date +%Y-%m-%dT%H:%M:%SZ) ABORTING ($_WATCHRC_pipe is missing) i=$it pid=$pid" >> $_WATCHRC_rcWatcherPath.log
			# If the user wants to force the abortion of the watcher, they just need to delete the status file
			return 0;
		fi

		it=$((it + 1))

		echo "$(date +%Y-%m-%dT%H:%M:%SZ) STARTING LOOP i=$it pid=$pid" >> $_WATCHRC_rcWatcherPath.log
		awk '
			$1=="watcher#echo" { print substr($0, index($0, $2)); next }
			/SERVER RUNNING/   { print "SERVER RUNNING"; enableEnd=1 };
			NR==1              { print "SERVER STARTING"; enableEnd=1 };
			END                { if (enableEnd) print "IDLE (SERVER DOWN)"; }
			{ fflush() }
		' $_WATCHRC_pipe |\
		while read line; do
			if [[ "$line" == "STOP" ]]; then
				echo "$(date +%Y-%m-%dT%H:%M:%SZ) i=$it pid=$pid STOPPING WATCHER" >> $_WATCHRC_rcWatcherPath.log
				rm $_WATCHRC_pipe
				break 2
			fi

			echo "$(date +%Y-%m-%dT%H:%M:%SZ) i=$it pid=$pid $line" >> $_WATCHRC_rcWatcherPath.log

			echo $line > $_WATCHRC_status
			killall -USR1 i3status

			# if [[ "$line" == "starting" ]]; then
			# 	echo "STARTING" > $_WATCHRC_status
			# 	continue;
			# fi

			# local pid=$(lsof $_WATCHRC_pipe 2>&1 | awk '$1 == "tee"{ print $2 }')
			# _WATCHRC_watchProcess $pid 2>&1 &
		done

		sleep 1
	done

	rm $_WATCHRC_status
}

function _WATCHRC_start() {
	[ -e $_WATCHRC_pipe ] || mkfifo $_WATCHRC_pipe

	if [[ -f $_WATCHRC_status ]]; then
		return
	fi

	_WATCHRC_watchPipe < /dev/null
}

function _WATCHRC_watchProcess() {
	echo "watchProcess $@" >> $_WATCHRC_rcWatcherPath.log
	echo "UP" > $_WATCHRC_status

	while kill -0 $1 2> /dev/null; do
		sleep 1
	done

	echo "DOWN" > $_WATCHRC_status
	echo "watchProcess DOWN" >> $_WATCHRC_rcWatcherPath.log
}

function _WATCHRC_startAndPipeToRCWatcher() {
	local cmd=()

	if command -v unbuffer > /dev/null; then
		cmd+=('unbuffer')
	fi

	cmd+=("$@")

	"${cmd[@]}" | tee "$_WATCHRC_pipe"
}

if [[ "$1" == "start" ]]; then
	_WATCHRC_start
fi
