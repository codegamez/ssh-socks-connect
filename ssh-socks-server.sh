#!/bin/bash -e

# script root directory
dir="$(dirname -- "$(which -- "$0" 2>/dev/null || realpath -- "./$0")")"

if [ ! -f "$dir/server.conf" ]; then
	echo "config file is not exist"
	echo "copy server-example.conf to server.conf and set your config"
	exit
fi

# config
. "$dir/server.conf"

# check user is root
if test "$(whoami)" != "root"; then
	echo "Please run as root"
	exit
fi

# create user group
groupadd -f "$user_group" &>/dev/null

raise_error_if_user_empty() {
	local user=$1
	if [ -z "$user" ]; then
		echo "user name is empty"
		exit
	fi
}

raise_error_if_user_exist() {
	local user=$1
	if id "$user" &>/dev/null; then
		echo "user name is exist"
		exit
	fi
}

raise_error_if_user_not_exist() {
	local user=$1
	if ! id "$user" &>/dev/null; then
		echo "user name is not exist"
		exit
	fi
}

raise_error_if_user_is_out_of_group() {
	local user=$1
	local user_groups
	user_groups=$(id -nG "$user")
	if [[ " $user_groups " != *" $user_group "* ]]; then
		echo "user name is not in $user_group group"
		exit
	fi
}

command=$1

if [ "$command" = "add-user" ]; then

	# get user name
	user=$2
	raise_error_if_user_empty "$user"
	raise_error_if_user_exist "$user"

	# add user
	useradd -M "$user"
	usermod -aG "$user_group" "$user"
	usermod --shell /bin/false "$user"
	passwd "$user"

	echo "user $user added successfully"

elif [ "$command" = "delete-user" ]; then

	# get user name
	user=$2
	raise_error_if_user_empty "$user"
	raise_error_if_user_not_exist "$user"
	raise_error_if_user_is_out_of_group "$user"

	# delete the user
	userdel "$user"

	echo "user $user deleted successfully"

elif [ "$command" = "show-users" ]; then
	
	# get the group users
	users=$(groupmems -g $user_group -l)
	
	echo "users: $users"

else

	echo "commands:"
	echo "  add-user [name]"
	echo "  delete-user [name]"
	echo "  show-users"

fi
