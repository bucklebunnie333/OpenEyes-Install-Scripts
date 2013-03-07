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
SCRIPT_DIR=`dirname $0`
. $SCRIPT_DIR/base.properties

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
# Create the temporary directory that sources will be downloaded to.
# 
create_tmp_dir() {
	if [ ! -d $TMP_DIR ]
	then
		mkdir $TMP_DIR
		log "Created $TMP_DIR"
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
			create_tmp_dir
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
# Adds the current user to www-data
# 
add_user_to_apache_group() {
	groups $USER | grep --quiet www-data
	if [ $? -ne 0 ]
	then
		log "Adding this user to group 'www-data' for r/w purposes:"
		sudo sudo usermod -G www-data -a $USER
		log "Added user to www-data"
		log "Note: you may need to log in and out for the changes"
		log "to take effect to be member of the specified group."
	else
		log "$USER is already a member of www-data."
	fi
}

#
# Adds the user to the $OE_GROUP group.
#
add_user_to_oe_group() {
	groups $USER | grep --quiet $OE_GROUP
	if [ $? -ne 0 ]
	then
		log "'$OE_GROUP' group does not exist; creating it..."
		sudo groupadd $OE_GROUP
		report_success $? "Added group '$OE_GROUP'"
		sudo usermod -a -G $OE_GROUP $USER
		report_success $? "Added $USER to group '$OE_GROUP'"
		log "Note: you may need to log in and out for the changes"
		log "to take effect to be member of the specified group."
	else
		log "$USER is already a member of $OE_GROUP."
	fi
}

#
# Adds the user to the www-data and $OE_GROUP groups.
#
add_user_to_groups() {
	add_user_to_oe_group
	add_user_to_apache_group
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
	echo "Reading in password for user '$OE_USER'. Please enter database password for user '$OE_USER':" >&2
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
