#!/bin/bash

# script root directory
script=$(realpath "$0")
dir=$(dirname "$script")

if [ ! -f "$dir/client.conf" ]; then
	echo "config file is not exist"
	echo "copy client-example.conf to client.conf and set your config"
	exit
fi

# config
. "$dir/client.conf"

# check socks port
if [[ $socks_port ]] && [ $socks_port -eq $socks_port ] 2>/dev/null; then
	if (($socks_port <= 1000 || $socks_port > 65535)); then
		echo "socks_port must be a decimal number between [1000-65535]"
		exit
	fi
else
	echo "socks_port must be a decimal number between [1000-65535]"
	exit
fi

# install sshpass
if ! command -v sshpass &>/dev/null; then
	apt install sshpass
fi

# proxy server address
if [ -n "$proxy_server_name" ]; then
	proxy_server="$proxy_server_name"
elif [ -n "$proxy_server_ip" ] && [ -n "$proxy_server_user" ]; then
	proxy_server="$proxy_server_user@$proxy_server_ip"
else
	proxy_server=""
fi

# target server address
if [ -n "$target_server_name" ]; then
	target_server="$target_server_name"
elif [ -n "$target_server_ip" ] && [ -n "$target_server_user" ]; then
	target_server="$target_server_user@$target_server_ip"
else
	target_server=""
fi

target_password_replacement="*****"

# create socks proxy command
if [ -n "$proxy_server" ]; then
	ssh_command="
		env SSHPASS=\"$proxy_server_pass\"
		sshpass -d \"$target_password_replacement\" ssh -fnNT
		-o LogLevel=quiet
		-o ServerAliveInterval=300
		-o ServerAliveCountMax=300
		-o ProxyCommand=\"sshpass -e ssh -fnNT -W %h:%p $proxy_server\"
		-D $socks_port
		$target_server
		$target_password_replacement<<<\"$target_server_pass\"
	"
else
	ssh_command="
		sshpass -d \"$password_replacement\" ssh -fnNT
		-o LogLevel=quiet
		-o ServerAliveInterval=300
		-o ServerAliveCountMax=300
		-D $socks_port
		$target_server
		$password_replacement<<<\"$target_server_pass\"
	"
fi
ssh_command=$(echo $ssh_command)

is_port_busy() {
	port_is_busy=$(lsof -i -P -n | grep $socks_port | head -1)
	if [ -n "$port_is_busy" ]; then
		true
	else
		false
	fi
}

is_port_socks() {
	port_is_socks=$(timeout 2 curl --socks5 127.0.0.1:$socks_port 8.8.8.8 2>&1 | grep "Unable to receive initial SOCKS5 response")
	if [ -z "$port_is_socks" ]; then
		true
	else
		false
	fi
}

# disconnect
if [ "$1" = "d" ] || [ "$1" = "c" ]; then

	echo "stopping..."

	is_service_active=$(ps -x | grep "$script service" | head -n-1 | head -n1)
	if [ -n "$is_service_active" ]; then
		echo "client service is stopped"
	fi

	pkill -f "$script service" &>/dev/null
	rm $dir/service.out &>/dev/null

	if is_port_busy; then
		if is_port_socks; then
			kill $(lsof -t -i:$socks_port)
			echo "socks server is stopped"
		else
			echo "port $socks_port is being used by another program"
			exit
		fi
	fi

	pkill -f "$script" &>/dev/null

fi

# connect
if [ "$1" = "c" ]; then

	echo "starting..."

	# create socks proxy
	eval $ssh_command
	
	# run client service
	nohup $script service &>$dir/service.out &
	echo "client service is running in background"
	
	# check status
	sleep 1
	if is_port_busy; then
		echo "socks server is running on port $socks_port"
	else
		echo "failed to start"
	fi

	exit
fi

# status
if [ "$1" = "s" ]; then

	echo "checking..."

	is_service_active=$(ps -x | grep "$script service" | head -n-1 | head -n1)
	if [ -n "$is_service_active" ]; then
		echo "client service is running in background"
	else
		echo "client service is not running"
	fi

	if is_port_busy; then
		if is_port_socks; then
			echo "socks server is running on port $socks_port"
		else
			echo "port $socks_port is being used by another program"
		fi
	else
		echo "socks server is not running"
	fi

	exit
fi

# service task
if [ "$1" = "service" ]; then

	while :; do

		sleep 5

		# check every n seconds for server status
		if is_port_busy; then
			if is_port_socks; then
				echo "[$(date)] socks server is running on port $socks_port"
				sleep 8
				continue
			else
				echo "[$(date)] port $socks_port is being used by another program"
				sleep 30
				continue
			fi
		fi

		# if server is down, run it again
		echo "[$(date)] starting..."
		eval $ssh_command
		sleep 1
		if is_port_busy; then
			echo "[$(date)] socks server is running on port $socks_port"
		else
			echo "[$(date)] failed to start"
		fi

	done

fi

# help
if [ "$1" != "c" ] &&
	[ "$1" != "d" ] &&
	[ "$1" != "s" ] &&
	[ "$1" != "service" ]; then
	echo "commands:"
	echo "  c			> connect"
	echo "  d			> disconnect"
	echo "  s			> check status"
fi
