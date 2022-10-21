#! /bin/sh
### BEGIN INIT INFO
# Provides:          clash
# Required-Start:    $syslog $time $remote_fs
# Required-Stop:     $syslog $time $remote_fs
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Description:       Start clash daemon
### END INIT INFO

PATH=/bin:/usr/bin:/sbin:/usr/sbin

#Your ISP dns or public dns, like 1.2.4.8, 114.114.114.114
ISPDNS=119.29.29.29

#Project files path
PROJECT=/config/clash
DAEMON_CLASH=$PROJECT/bin/clash

#Process ID files path
PIDFILE_CLASH=/var/run/clash.pid

test -x $DAEMON_CLASH || exit 0

. /lib/lsb/init-functions

#Test if network ready (pppoe)
test_network() {
	curl --retry 1 --silent --connect-timeout 2 -I www.baidu.com  > /dev/null
	if [ "$?" != "0" ]; then
		echo 'network not ready, wait for 5 seconds ...'
		sleep 5
	fi
}

rules_add() {
	iptables -t nat -N CLASH
	iptables -t nat -A CLASH -d 0.0.0.0/8 -j RETURN
	iptables -t nat -A CLASH -d 10.0.0.0/8 -j RETURN
	iptables -t nat -A CLASH -d 127.0.0.0/8 -j RETURN
	iptables -t nat -A CLASH -d 169.254.0.0/16 -j RETURN
	iptables -t nat -A CLASH -d 172.16.0.0/12 -j RETURN
	iptables -t nat -A CLASH -d 192.0.0.0/24 -j RETURN
	iptables -t nat -A CLASH -d 192.0.2.0/24 -j RETURN
	iptables -t nat -A CLASH -d 192.88.99.0/24 -j RETURN
	iptables -t nat -A CLASH -d 192.168.0.0/16 -j RETURN
	iptables -t nat -A CLASH -d 198.18.0.0/15 -j RETURN
	iptables -t nat -A CLASH -d 198.51.100.0/24 -j RETURN
	iptables -t nat -A CLASH -d 203.0.113.0/24 -j RETURN
	iptables -t nat -A CLASH -d 224.0.0.0/4 -j RETURN
	iptables -t nat -A CLASH -d 233.252.0.0/24 -j RETURN
	iptables -t nat -A CLASH -d 240.0.0.0/4 -j RETURN
	iptables -t nat -A CLASH -d 255.255.255.255/32 -j RETURN
	iptables -t nat -A CLASH -p tcp -j REDIRECT --to-port 7892
	iptables -t nat -A PREROUTING -p tcp -j CLASH
	iptables -t nat -A PREROUTING -p udp --dport 53 -j DNAT --to 192.168.1.1
}

rules_flush() {
	iptables -t nat -F CLASH
	iptables -t nat -D PREROUTING -p udp --dport 53 -j DNAT --to 192.168.1.1
	iptables -t nat -D PREROUTING -p tcp -j CLASH
	iptables -t nat -X CLASH
}

case "$1" in
  start)

	test_network

	log_daemon_msg "Starting clash" "clash"
	start-stop-daemon -S -p $PIDFILE_CLASH --oknodo -b -m --startas $DAEMON_CLASH -- -d $PROJECT
	log_end_msg $?

	log_daemon_msg "Adding network rules" "iptables"
	rules_add
	log_end_msg $?

	log_daemon_msg "Updating DNS configuration" "dnsmasq"
	sed -i s/server=$ISPDNS/server=127.0.0.1#1053/ /etc/dnsmasq.d/my.conf
	[ 0 == `grep "^server" /etc/dnsmasq.d/my.conf|wc -l` ] && echo server=127.0.0.1#1053 >> /etc/dnsmasq.d/my.conf
	[ 0 == `grep "^no-resolv" /etc/dnsmasq.d/my.conf|wc -l` ] && echo no-resolv >> /etc/dnsmasq.d/my.conf
	service dnsmasq restart
	log_end_msg $?

    ;;

  stop)

	log_daemon_msg "Stopping clash" "clash"
	start-stop-daemon -K -p $PIDFILE_CLASH --oknodo
	log_end_msg $?

	log_daemon_msg "Deleting iptables rules" "flush iptables"
	rules_flush
	log_end_msg $?

	log_daemon_msg "Updating DNS configuration" "dnsmasq"
	sed -i s/server=127.0.0.1#1053/server=$ISPDNS/ /etc/dnsmasq.d/my.conf
	[ 0 == `grep "^server" /etc/dnsmasq.d/my.conf|wc -l` ] && echo server=$ISPDNS >> /etc/dnsmasq.d/my.conf
	service dnsmasq restart
	log_end_msg $?

    ;;

  force-reload|restart)
    $0 stop
    $0 start
    ;;

  status)

    status_of_proc -p $PIDFILE_CLASH $DAEMON_CLASH clash

    ;;

  *)
    echo "Usage: $PROJECT/clash.sh {start|stop|restart|force-reload|status}"
    exit 1
    ;;
esac

exit 0
