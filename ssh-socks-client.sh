#!/bin/bash -e

# script root directory
dir="$(dirname -- "$(which -- "$0" 2>/dev/null || realpath -- "./$0")")"

if [ ! -f "$dir/client.conf" ]; then
	echo "config file is not exist"
	echo "copy client-example.conf to client.conf and set your config"
	exit
fi

# config
. "$dir/client.conf"

# select appropriate command
if [ -n "$outter_server_name" ] && [ -n "$inner_server_name" ]; then
	ssh_command="ssh -fnNT -D $socks_port -J $outter_server_name $inner_server_name"
else
	ssh_command="ssh -fnNT -D $socks_port -J $outter_server_user@$outter_server_ip $inner_server_user@$inner_server_ip"
fi

# disconnect
if [ "$1" = "d" ] || [ "$1" = "c" ]; then
	id=$(ps x | grep -F "$ssh_command" | head -n-1 | head -1 | awk '{print $1}')
	if [ -n "$id" ]; then
		kill "$id"
		echo "socks server is stopped"
	fi
fi

# connect
if [ "$1" = "c" ]; then
	echo $ssh_command
	$($ssh_command)
	echo "socks server is running on port $socks_port"
	exit
fi

# status
if [ "$1" = "s" ]; then
	row=$(ps x | grep -F "$ssh_command" | head -n-1 | head -1)
	if [ -n "$row" ]; then
		echo "$row"
		echo "socks server is running on port $socks_port"
	else
		echo "server is not running"
	fi
	exit
fi

# help
if [ "$1" != "c" ] && [ "$1" != "d" ] && [ "$1" != "s" ]; then
	echo "commands:"
	echo "  c		> connect"
	echo "  d		> disconnect"
	echo "  s		> check status"
fi
