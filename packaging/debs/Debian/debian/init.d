#!/bin/sh
### BEGIN INIT INFO
# Provides:          rabbitmq
# Required-Start:    $remote_fs $network
# Required-Stop:     $remote_fs $network
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Description:       RabbitMQ broker
# Short-Description: Enable AMQP service provided by RabbitMQ broker
### END INIT INFO

PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
DAEMON=/usr/sbin/rabbitmq-multi
NAME=rabbitmq-server
DESC=rabbitmq-server
USER=rabbitmq
NODE_COUNT=1
ROTATE_SUFFIX=

test -x $DAEMON || exit 0

# Include rabbitmq defaults if available
if [ -f /etc/default/rabbitmq ] ; then
	. /etc/default/rabbitmq
fi

RETVAL=0
set -e
cd /

start_rabbitmq () {
      set +e
      su $USER -s /bin/sh -c "$DAEMON start_all ${NODE_COUNT}" > /var/log/rabbitmq/startup_log 2> /var/log/rabbitmq/startup_err
      case "$?" in
        0)
          echo SUCCESS;;
        1)
          echo TIMEOUT - check /var/log/rabbitmq/startup_\{log,err\};;
        *)
          echo FAILED - check /var/log/rabbitmq/startup_log, _err
          exit 1;;
      esac 
      set -e
}

stop_rabbitmq () {
    set +e
    su $USER -s /bin/sh -c "$DAEMON stop_all" > /var/log/rabbitmq/shutdown_log 2> /var/log/rabbitmq/shutdown_err
    if [ $? != 0 ] ; then
        echo FAILED - check /var/log/rabbitmq/shutdown_log, _err
        exit 0
    fi
    set -e
}

rotate_logs_rabbitmq() {
    set +e
    su $USER -s /bin/sh -c "$DAEMON rotate_logs_all ${ROTATE_SUFFIX}" 2>&1
    RETVAL=$?
    set -e

}

case "$1" in
  start)
	echo -n "Starting $DESC: "
	start_rabbitmq
	echo "$NAME."
	;;
  stop)
	echo -n "Stopping $DESC: "
	stop_rabbitmq
	echo "$NAME."
	;;
  rotate-logs)
    echo -n "Rotating log files for $DESC: "
    rotate_logs_rabbitmq
    ;;
  force-reload|restart)
	echo -n "Restarting $DESC: "
	stop_rabbitmq
	start_rabbitmq
	echo "$NAME."
	;;
  *)
	echo "Usage: $0 {start|stop|rotate-logs|restart|force-reload}" >&2
	RETVAL=1
	;;
esac

exit $RETVAL
