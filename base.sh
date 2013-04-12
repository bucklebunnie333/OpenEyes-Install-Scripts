#!/bin/bash

# OpenEyes
# 
# (C) Moorfields Eye Hospital NHS Foundation Trust, 2008-2011
# (C) OpenEyes Foundation, 2011-2012
# This file is part of OpenEyes.
# OpenEyes is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
# OpenEyes is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
# You should have received a copy of the GNU General Public License along with OpenEyes in a file titled COPYING. If not, see <http://www.gnu.org/licenses/>.
# 
# Initial author: Richard Meeking, 16th January 2012.
# 

. $OE_INSTALL_SCRIPTS_DIR/base.properties

#
# 
#
read_root_db_password() {
	echo "Reading in password for root database access. Please enter root database password:" >&2
	stty -echo
	read DB_PASSWORD
	echo "Again, please:"
	read DB_PASSWORD_CHECK
	if [ "$DB_PASSWORD_CHECK" != "$DB_PASSWORD" ]
	then
		stty echo
		log "Passwords do not match; quitting"
		exit 1
	fi
	stty echo
}

# 
# Create 
# 
# $1 - directory to create
# 
create_directory() {
	DIRECTORY=$1
	if [ ! -d  $DIRECTORY ]
	then
		sudo mkdir -p $DIRECTORY
		report_success $? "Created $DIRECTORY"
	else
		log "$DIRECTORY already exists, no need to create it."
	fi
}

# 
# Echoes information to STDOUT, and if logging is enabled writes to the specified log file.
# 
# $1 - the log message to write.
# 
log() {
	if [ $LOG_FILE_WRITE = "true" ]
	then
		if [ $FIRST_TIME_LOG = "true" ]
		then
			FIRST_TIME_LOG="false"
			mkdir $TMP_DIR
			echo "Writing to log file $LOG_FILE"
			echo "`date +"%a %Y-%m-%d %H:%M:%S"` Script started." >> $LOG_FILE
		fi
		echo "`date +"%a %Y-%m-%d %H:%M:%S"` $1" >> $LOG_FILE
	fi
	echo $1
}

# 
# Reports success if the value passed in is 0, else reports failure.
# The second argument dicates the message, which has ': [Success|Failure]
# appended to it.
# 
# $1 - an integer (typically $?), 0 for success.
# $2 - text information about the process invoked for success/failure.
# 
report_success() {
	if [ $1 -eq 0 ]
	then
		log "$2: Success"
	else
		log "$2: Failure"
		log "This error needs to be resolved before continuing."
		exit 1
	fi
}

# 
# Installs the specified packages, if the packages has not already been installed.
# 
install_packages() {
	log "Install packages : $INSTALL_PACKAGES"
	for package in $INSTALL_PACKAGES; do
		dpkg -s $package > /dev/null
		if [ $? -eq 0 ]
		then
			log "Not installing $package; $package is already installed."
		else
			log "Installing $package"
			if [ $package = "non-apt-php-pear" ]
			then
				install_pear
			elif [ $package = "mysql-server" ]
			then
				log "Setting MySQL root password using debconf-set-setlections..."
				echo mysql-server-5.1 mysql-server/root_password password $DB_PASSWORD | sudo debconf-set-selections
				echo mysql-server-5.1 mysql-server/root_password_again password $DB_PASSWORD | sudo debconf-set-selections
				export DEBIAN_FRONTEND=noninteractive
				# TODO the above 3 lines do not get enacted upon if DB_PASSWORD
				# has not been set, i.e. the install still prompts for a password
				sudo apt-get --quiet --yes install mysql-server
				report_success $? "mysql-server installed"
			else
				sudo -S apt-get --yes install $package
				report_success $? "$package installed"
			fi
		fi
	done
}

# 
# If the specified file passed in exists, report the error and quit.
# 
# $1 - a file to check to see if it exists.
# 
quit_if_file_exists() {
	if [ -f $1 ]
	then
		log "$1 already exists; remove this file before attempting"
		log "to continue (or, if possible, specify a different file)."
		exit 1
	fi
}

# 
# If the specified directory passed in exists, report the error and quit.
# 
# $1 - a directory to check to see if it exists.
# 
quit_if_dir_exists() {
	if [ -d $1 ]
	then
		log "$1 already exists; remove this directory before attempting"
		log "to continue (or, if possible, specify a different directory)."
		exit 1
	fi
}

# 
# Adds the specified user to the given group.
# 
# $1 the user to add to the group
# 
# $2 the group to add the user to
# 
add_user_to_group() {
	USER_TO_ADD=$1
	GROUP_TO_ADD=$2
	sudo grep -qs $GROUP_TO_ADD /etc/group
	if [ $? -ne 0 ]
	then
		log "'$GROUP_TO_ADD' group does not exist; creating it..."
		sudo groupadd $GROUP_TO_ADD
		report_success $? "Added group '$GROUP_TO_ADD'"
	fi
	groups $USER_TO_ADD | grep --quiet $GROUP_TO_ADD
	if [ $? -ne 0 ]
	then
		log "Adding this user to group '$GROUP_TO_ADD' for r/w purposes:"
		sudo sudo usermod -G $GROUP_TO_ADD -a $USER_TO_ADD
		log "Added user to $GROUP_TO_ADD"
		log "Note: you may need to log in and out for the changes"
		log "to take effect to be member of the specified group."
	else
		log "$USER_TO_ADD is already a member of $GROUP_TO_ADD."
	fi
}

#
# Adds the user to the necessary groups (APACHE_GROUP and OE_GROUP).
#
add_user_to_groups() {
	add_user_to_group $USER $OE_GROUP
	add_user_to_group $USER $APACHE_GROUP
}

# 
# Change site directory to be owned by root and group www-data,
# then chmod (recursively) r/w/x for www-data for the specified
# directory for the specified file/directory.
# 
# $1 - the directory or file to change the permissions for.
# 
change_permissions() {
	log "Changing ownership for $1 to r/w/x for www-data -"
	sudo chown -R root:www-data $1
	sudo chmod -R g+rwx $1
	report_success $? "Changed permissions for $1"
}

# 
# If the specified directory does not exist, quit
# with exit value 1 after reporting the directory does not exist.
# 
# $1 - the directory to check to see if exists.
#
check_dir_exists_or_quit() {
	if [ ! -d $1 ]
	then
		log "Directory $1 does not exist."
		exit 1
	fi
}

# 
# If the specified file does not exist, quit
# with exit value 1 after reporting the file does not exist.
# 
# $1 - the file to check to see if exists.
# 
check_file_exists_or_quit() {
	if [ ! -f $1 ]
	then
		log "File $1 does not exist."
		exit 1
	fi
}

# 
# 
# 
read_oe_db_password() {
	echo "Reading in password for user '$OE_DB_USER'. Please enter database password for user '$OE_DB_USER':" >&2
	stty -echo
	read DB_USER_PASSWORD
	echo "Again, please:"
	read DB_USER_PASSWORD_CHECK
	if [ "$DB_USER_PASSWORD_CHECK" != "$DB_USER_PASSWORD" ]
	then
		stty echo
		log "Passwords do not match; quitting"
		exit 1
	fi
	stty echo
}

#
# Used for when a git clone has just been performed to switch to
# a given branch and track it.
# 
# $1 - the branch name
# 
# $2 - the track name; not required
#
do_git_checkout() {
	if [ $GIT_CHECKOUT = "true" ]
	then
		if [ -z $2 ]
		then
			git checkout -b $1
			report_success $? "Git checkout for branch $1"
		else
			log "Switching to branch: '$1', tracking: '$2'"
			git checkout -b $1 --track $2
			report_success $? "Git checkout for branch $1, tracking $2"
		fi
	fi
}

# 
# 
# $1 - the repository to clone
# $2 - the directory to clone to
# 
do_git_clone() {
	log "Attempting to clone $1 to $2 (in directory $PWD)"
	git clone $1 $2
	report_success $? "Cloned $1 to $2"
}

# 
# Parse the details of the module, placing results in mod_name,
# mod_local_name, mod_repo, mod_branch and mod_migrate.
# 
# $1 - module in the format remote_module_name | local_module_name | git_repo | git_branch_name | migrate
# 
# See the module properties file for explanation of each part of the module configuration given above.
# 
parse_module_details() {
	module=$1
	mod_name=`echo $module | cut -d \| -f 1`
	mod_local_name=`echo $module | cut -d \| -f 2`
	mod_repo=`echo $module | cut -d \| -f 3`
	mod_branch=`echo $module | cut -d \| -f 4`
	mod_migrate=`echo $module | cut -d \| -f 5`
	if [ -z "$mod_local_name" ]
	then
		mod_local_name=$mod_name
		log "Module name is same as remote module repository name ($mod_local_name)."
	else
		log "Using different local module name: $mod_local_name, differs from $mod_name"
	fi
}
