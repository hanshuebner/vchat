#!/sbin/sh

#
# sshd startup: Startup and kill script for the secure shell server
#

PATH=/sbin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin:/usr/contrib/bin
HOME=/home/hans
export PATH HOME

case "$1" in

    "start_msg") echo "Starting vchat subsystem" ;;

    "start") sudo -u hans screen -S vchat -m -d -c /home/vchat/etc/screenrc && exit 0
	     exit 2 ;;

    "stop_msg") echo "Terminating vchat subsystem" ;;

    "stop") PIDS=`sudo -u hans screen -list | grep 'vchat.*detached' | sed -e 's/\..*//'`
	    [ -z "$PIDS" ] && exit 0
	    kill $PIDS
	    sleep 5
	    kill -9 $PIDS
		;;

esac

exit 0;
