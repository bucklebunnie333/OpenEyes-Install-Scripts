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
# Script to download, install and configure software necesseary
# to run Open Eyes on Ubuntu 10.04 LTS. It is expected that
# callers of this script have access to a GIT hub account.
# 
# Run
#	 sh openeyes.sh -h
# for help on using this script.
# 
# For a vanilla Ubuntu install, run
#	 sh openeyes.sh -t -u
# To create default groups and upgrade system packages, then restart. Then run
#	 sh openeyes.sh -P "ssh git-core" -i -g
# and follow instructions for GIT keys. This will involve copying the contents of ~/.ssh/id_rsa.pub to your github account. Then run
#	 sh openeyes.sh -R -Q -a
# to install required packages and end up with an Apache server running OpenEyes. The -R and -Q options prompt for the root and OE user passwords for database admin/access (respectively).
# 

SCRIPT_DIR=`dirname $0`

. $SCRIPT_DIR/base.sh
. $SCRIPT_DIR/install.properties

# 
# Perform a system update and upgrade to get the latest packages.
# 
perform_update() {
	sudo apt-get update
	sudo apt-get -y upgrade
	if [ "$CONTINUE_AFTER_SYSTEM_UPGRADE" = "false" ]
	then
		log "It is important that you now restart your system, especially"
		log "if the upgrade was from a fresh vanilla install. You can stop"
		log "this from happening when running an upgrade by setting -C"
		log "to true."
		exit 1
	fi
}

# 
# Installs pear. The default Ubuntu version will not work,
# so a custom install is required.
# 
install_pear() {
	which pear
	if [ $? -ne 0 ]
	then
		log "Pear not installed; installing it now..."
		sudo -S wget http://pear.php.net/go-pear.phar
		report_success $? "Pear Downloaded"
		sudo -S php go-pear.phar
		sudo -S pear upgrade pear
		report_success $? "Pear upgraded"
		sudo pear channel-discover pear.phpunit.de
		sudo pear channel-discover pear.symfony-project.com
		sudo pear config-set auto_discover 1
		sudo -S pear install phpunit/PHPUnit
		report_success $? "PHPUnit installed"
		sudo -S pear install pear.phpunit.de/PHP_CodeCoverage
		report_success $? "PHP_CodeCoverage installed"
		sudo -S pear install pear.phpunit.de/PHPUnit_Selenium
		report_success $? "PHPUnit_Selenium installed"
		sudo -S pear install pear.phpunit.de/DBUnit
		report_success $? "PHPDBUnit installed"
	else
		log "Pear already installed; skipping installation."
	fi
}

# 
# If the 1st value equals 0, output "Success: $2"; else print out "Error: $3"
# 
# $1 - the value to check - 0 is true/success
# $2 - the message to print on success
# $3 - the message to print on failure
# 
quit_if_fail_db_call() {
	if [ $1 -eq 0 ]
	then
		log "$2"
	else
		log "$3"
		exit 1
	fi
}

# 
# Creates the OE user, main OE database and the OE test database.
# The user is given all privileges for the OE databases.
# 
db_admin() {
	databases="openeyes openeyestest"
	mysql -u root --password=$DB_PASSWORD -e "select user.User from user where user.User='$OE_USER'" mysql | grep -q $OE_USER
	if [ $? -ne 0 ]
	then
			log "OE database user does not exist; creating user now..."
			mysql -u root --password=$DB_PASSWORD -e "create user $OE_USER@'localhost' IDENTIFIED BY '$DB_USER_PASSWORD';"
			report_success $? "Creation of database user 'oe'"
	else
		log "OE database user already exists; skipping creation."
	fi
	for db in $databases; do
			mysql -u root --password=$DB_PASSWORD -e "create database if not exists $db"
			X=$?
			quit_if_fail_db_call $X "database '$db' exists." "Could not create database '$db'"
			mysql -u root --password=$DB_PASSWORD -e "use $db; grant all privileges on $db.* to $OE_USER@'localhost' identified by '$DB_USER_PASSWORD'"
			X=$?
			quit_if_fail_db_call $X "'$OE_USER' has necessary privileges for $db" "Privileges not granted to '$OE_USER' on $db"
	done
}

# 
# Creates the GIT keys required for repository access. User's are then
# expected to copy values to their GIT account in order to proceed
# beyond this step.
# 
create_git_keys() {
	log "Creating GIT keys" >&2
	SSH_DIR=~/.ssh
	if [ ! -d $SSH_DIR ]
	then
		mkdir $SSH_DIR
	fi
	check_dir_exists_or_quit $SSH_DIR
	cd $SSH_DIR
	report_success $? "Change to $SSH_DIR"
	log "Attempting to generate the key. This requires your email used with the GIT repository to identify yourself."
	log "Enter your email used to generate the key:"
	read email
	log "email entered: $email"
	ssh-keygen -t rsa -C $email
	result=$?
	report_success $result "SSH keygen"
	if [ result -neq 0 ]
	then
		log "SSH key generation failed. Quitting."
		exit 1
	fi
	# should read last command value to ensure success...
	log "Keys have been generated in the specified file. The contents of 'id_rsa.pub' now needs to be copied to your GIT account before continuing."
	log "Copy the contents to your GIT account and add the specified public key."
	cd -
}

# 
# Perform a WGET to get the YII code.
# 
download_yii_code() {
	file_to_get=$TMP_DIR/$YII_TAR_GZ
	repo_location=$YII_REPO/$YII_TAR_GZ
	quit_if_file_exists $file_to_get
	log "Downloading $repo_location"
	wget -O $file_to_get $repo_location
	if [ -f $file_to_get ]
	then
		log "Successfully downloaded $file_to_get."
	else
		log "Failed to download file $repo_location."
		exit 1
	fi
}

# 
# Extract the YII code to a temporary directory,
# then copy it to the site directory.
# 
extract_yii_code() {
	log "Extracting YII code..."
	check_dir_exists_or_quit $TMP_DIR
	cd $TMP_DIR
	check_file_exists_or_quit $YII_TAR_GZ
	yii_extract_dir=`basename $YII_TAR_GZ .zip`
	if [ `basename $YII_TAR_GZ .zip` = $YII_TAR_GZ ]
	then
		tar zxf $YII_TAR_GZ
		result=$?
		yii_extract_dir=`basename $YII_TAR_GZ .tar.gz`
	else
		unzip $YII_TAR_GZ
		result=$?
	fi
	report_success $result "Extracting $YII_TAR_GZ"
	check_dir_exists_or_quit $yii_extract_dir
	if [ -f $SITE_DIR/index.html ]
	then
		log "Backing up (and moving sideways) index.html to index.html.orig..."
		sudo mv $SITE_DIR/index.html $SITE_DIR/index.html.orig
		report_success $? "Moving $SITE_DIR/index.html to $SITE_DIR/index.html.orig"
	fi
	sudo cp -r $yii_extract_dir $SITE_DIR/
	report_success $? "Copying $yii_extract_dir to $SITE_DIR/"
	cd -
	check_dir_exists_or_quit $SITE_DIR
	cd $SITE_DIR
	if [ ! -d yii ]
	then
		log "Link for 'yii' does not exist; creating it now:"
		sudo ln -s $yii_extract_dir yii
		report_success $? "Linking $yii_extract_dir to $SITE_DIR/yii"
		if [ $? -eq 0 ]
		then
			log "Link successfully created in $SITE_DIR."
			change_permissions $SITE_DIR/$yii_extract_dir
		else
			log "Could not create symbolic link for 'yii' in $SITE_DIR."
			exit 1
		fi
	else
		log "Could not create symbolic link to yii; link exists."
	fi
	change_permissions $SITE_DIR/$yii_extract_dir
	cd -
}

# 
# Get a GIT clone of the specified OE code.
# 
download_oe_code() {
	log "Downloading OE repository: $OE_REPO"
	oe_download=$TMP_DIR/$OE_DIR
	if [ -d $oe_download ]
	then
		DATE=`date +"%y-%m-%d.%H%M%S"`
		log "Download already exists; moving old download to $oe_download-$DATE"
		mv $oe_download $oe_download-$DATE
	fi
	do_git_clone $OE_REPO $oe_download
	cd $oe_download
	do_git_checkout $GIT_BRANCH $GIT_TRACK
	cd -
}

# 
# Configure OE PHP files.
# 
configure_oe_code() {
	log "Configuring OE (copying from download area to site directory)..."
	check_dir_exists_or_quit $TMP_DIR/$OE_DIR
	sudo cp -r $TMP_DIR/$OE_DIR $SITE_DIR
	report_success $? "Copying $TMP_DIR/$OE_DIR to $SITE_DIR"
	sudo cp $SITE_DIR/openeyes/index.example.php $SITE_DIR/openeyes/index.php
	report_success $? "$SITE_DIR/openeyes/index.example.php copied to $SITE_DIR/openeyes/index.php"
	SITE_OE_CONFIG_DIR=$SITE_DIR/$OE_DIR/protected/config
	#report_success $? "Copying $CONF_DIR/common.php to $SITE_OE_CONFIG_DIR/common.php"
	#sudo cp $CONF_DIR/php/openeyes/common.sample.php $SITE_OE_CONFIG_DIR/local/common.php
	#report_success $? "Copying $SITE_OE_CONFIG_DIR/local/common.sample.php to $SITE_OE_CONFIG_DIR/local/common.php"
	sudo sed -i 's/_OE_PASSWORD_/'$DB_USER_PASSWORD'/g' $SITE_OE_CONFIG_DIR/core/common.php
	report_success $? "Substituted _OE_PASSWORD_ in file $SITE_OE_CONFIG_DIR/core/common.php"
	sudo sed -i "s/'username' => 'oe'/'username' => '$OE_USER'/g" $SITE_OE_CONFIG_DIR/core/common.php
	report_success $? "Substituted DB user 'oe' for $OE_USER in file $SITE_OE_CONFIG_DIR/core/common.php"
	sudo cp $SITE_OE_CONFIG_DIR/local/common.sample.php $SITE_OE_CONFIG_DIR/local/common.php
	report_success $? "Copied $SITE_OE_CONFIG_DIR/local/common.sample.php to $SITE_OE_CONFIG_DIR/local/common.php"
	sudo sed -i "s/'username' => 'root'/'username' => '$OE_USER'/g" $SITE_OE_CONFIG_DIR/local/common.php
	report_success $? "Substituted DB user 'oe' for $OE_USER in file $SITE_OE_CONFIG_DIR/local/common.php"
	sudo sed -i "s/'password' => ''/'password' => '$DB_USER_PASSWORD'/g" $SITE_OE_CONFIG_DIR/local/common.php
	report_success $? "Substituted empty password in file $SITE_OE_CONFIG_DIR/local/common.php"
	RUNTIME_DIR=$SITE_DIR/openeyes/protected/runtime
	if [ ! -d $RUNTIME_DIR ]
	then
		sudo mkdir $RUNTIME_DIR
		sudo chown root:www-data $RUNTIME_DIR
		sudo chmod -R g+wrx $RUNTIME_DIR
	else
		log "Directory protected/runtime directory already exists - no need to create."
	fi

	change_permissions $SITE_DIR/$OE_DIR
	report_success $? "Changed permissions for $SITE_DIR/$OE_DIR"
}

# 
# Check of the files are the same. If they are not,
# copy the given local file (arg 1) to the destintion
# supplied (arg 2). The if files are the same,
# print message (arg 3), if files are different
# print message (arg 4). If the destination file does
# not exist, a message detailing this is given.
# 
# $1 - the local file to copy if files are not the same
# $2 - the destination file to copy the file to
# $3 - the message to output if files are the same
# $4 - the message to output if files are different
# 
copy_files_if_different() {
	LOCAL_FILE=$1
	DEST_FILE=$2
	MESSAGE_FILES_SAME=$3
	MESSAGE_FILES_DIFFERENT=$4
	diff --brief $LOCAL_FILE $DEST_FILE
	if [ $? -ne 0 ]
	then
		if [ ! -f $DEST_FILE ]
		then
			log "Files does not exist: $DEST_FILE"
		fi
		sudo -S cp $LOCAL_FILE $DEST_FILE
		report_success $? "$LOCAL_FILE to $DEST_FILE"
		log $MESSAGE_FILES_DIFFERENT
	else
		log $MESSAGE_FILES_SAME
	fi
	
}

# 
# Configure Apache, MySQL and PHP.
# 
configure_system_files() {
	log "Configuring system packages"
	MYSQL_CONF=/etc/mysql/my.cnf
	check_file_exists_or_quit $MYSQL_CONF
	if [ $(grep -c "lower_case_table_names=1" $MYSQL_CONF) -ne 0 ]
	then
		log "MYSQL config contains correct config - 'lower_case_table_names' - leaving file untouched."
	else
		log "MYSQL does not contain 'lower_case_table_names' - appending to file..."
		NEWLINE=`printf "\n"`
		#echo $NEWLINE | sudo tee --append $MYSQL_CONF
		#DATA="# `date`: adding to mysql config..."
		#echo $DATA | sudo tee --append $MYSQL_CONF
		#DATA="lower_case_table_names=1"
		#echo $DATA | sudo tee --append $MYSQL_CONF

		sudo sed -i '/^\[mysqld\]/a \
lower_case_table_names=1' $MYSQL_CONF
		report_success $? "$MYSQL_CONF appended to"
		log "Restarting MySQL for the changes to take effect..."
		sudo /etc/init.d/mysql restart
		report_success $? "MySQL restarted"
	fi

	PHP_CONF=$PHP_CONF_DIR/php.ini

	if [ $(grep -c "^error_reporting = E_ALL | E_STRICT" $PHP_CONF) -gt 0 ]
	then
		log "PHP config already contains OpenEyes-specific error reporting - leaving file untouched."
	else
		log "Updating PHP config file $PHP_CONF -"
		log "PHP config does not contain 'error_reporting' with correct values; performing substitution..."
		sudo sed -i 's/^error_reporting = .*/error_reporting = E_ALL | E_STRICT/g' $PHP_CONF
		if [ $? -ne 0 ]
		then
			log "Failed to perform 'sed' regex substitution (error_reporting) for PHP configuration $PHP_CONF"
			exit 1
		else
			log "Substitution successful for 'error_reporting' in ($PHP_CONF)."
		fi
	fi

	if [ $(grep -c "^error_log = \/var\/log\/php.log" $PHP_CONF) -gt 0 ]
	then
		log "PHP config already contains OpenEyes-specific logging - leaving file untouched."
	else
		log "Updating PHP config file $PHP_CONF -"
		log "PHP config does not contain 'error_log' with correct values; performing substitution..."
		sudo sed -i 's/^;error_log = php_errors.log/error_log = \/var\/log\/php.log/g' $PHP_CONF
		if [ $? -ne 0 ]
		then
			log "Failed to perform 'sed' regex substitution (error_log) for PHP configuration $PHP_CONF"
			exit 1
		else
			log "Substitution successful for 'error_log' in ($PHP_CONF)."
		fi
	fi

	LOCAL_APACHE_CONF_DIR=$CONF_DIR/sys/apache
	copy_files_if_different $LOCAL_APACHE_CONF_DIR/httpd.conf $APACHE_CONF_DIR/httpd.conf "httpd.conf up to date." "Apache config - using custom OE-compatible httpd.conf."

	copy_files_if_different $LOCAL_APACHE_CONF_DIR/apache2.conf $APACHE_CONF_DIR/apache2.conf "apache2.conf up to date." "Apache config missing - using custom OE-compatible apache2.conf."

	copy_files_if_different $LOCAL_APACHE_CONF_DIR/000-default $APACHE_CONF_DIR/sites-enabled/000-default "000-default up to date." "Apache config - using custom OE-compatible 000-default."

	copy_files_if_different $LOCAL_APACHE_CONF_DIR/rewrite.load $APACHE_CONF_DIR/mods-enabled/rewrite.load "rewrite.load up to date." "Apache config override - using custom OE-compatible rewrite.load."

}

# 
# Perform YII DB migration, restarting apache when done.
# 
migrate() {
	log "Migrating YII"
	check_dir_exists_or_quit $SITE_DIR/$OE_DIR/protected
	cd $SITE_DIR/$OE_DIR/protected
	if [ $AUTO_MIGRATE = "true" ]
	then
		echo 'yes' | ./yiic migrate
	else
		./yiic migrate
	fi
	./yiic migrate
	report_success $? "YII Migration"
	if [ $PHP_TESTS = "true" ]
	then
		log "Running PHP unit tests..."
		./yiic migrate --connectionID=testdb
		report_success $? "YII Migration test database creation"
		check_dir_exists_or_quit tests
		cd tests
		phpunit unit
		log "PHP unit testing complete."
	fi

	cd -

	sudo /etc/init.d/apache2 restart
}

# 
# 
# 
print_help() {
	echo "Install, configure and update OpenEyes."
	echo ""
	echo "All upper-case arguments specify configurable options;"
	echo "lower-case options are used for installation targets."
	echo ""
	echo "Configuration options (specified before any installation targets):"
	echo ""
	echo "  -P \"<package_list>\": list of packages to install, enclosed"
	echo "     in quotes, separated by spaces; defaults to (in the"
	echo "     specified order):"
	for package in $INSTALL_PACKAGES;
	do
    echo "      $package"
	done
	echo "  -A <true|false>: migrate without question; defaults to true"
	echo "  -C <true|false>: continue after upgrade (-u); defaults to false"
	echo "  -Y <repo>: YII repository; defaults to $YII_REPO"
	echo "  -G <file>: YII download file (usually .tar.gz); defaults to"
	echo "     $YII_TAR_GZ"
	echo "  -O <oe_repo>: specify the OE repository to use; default is"
	echo "     $OE_REPO"
	echo "  -T <true|false>: set to true to run PHP unit tests during the"
	echo "     migration phase (see -m); default is false."
	echo "  -S <site_dir>: the site directory to deploy PHP projects to;"
	echo "     defaults to $SITE_DIR"
	echo "  -D <tmp_dir>: temporary directory to download to; default"
	echo "     is $TMP_DIR"
	echo "  -Q Read user database password (via prompt) to be entered by"
	echo "     user. This is the password for the OE user,"
	echo "     used in calling PHP scripts. If not set, the empty"
	echo "     password is used."
	echo "  -R Read root database password (via prompt) to be entered by"
	echo "     user. This is the password for the database administrator"
	echo "     when installed. If not set, the empty password is used."
	echo "  -L <log_file>: log file to write to; default is "
	echo "     $LOG_FILE"
	echo "  -W <true|false>: write to log file; defaults to $LOG_FILE_WRITE"
	echo "  -N <arg>: set the network proxy to use."
	echo ""
	echo "Installation targets:"
	echo ""
	echo "If -a is specified, all targets in the following list are executed"
	echo "in the order they appear below that appear *after* the -a listing."
	echo "User's should ensure user groups (-t), git key creation (-g),"
	echo "and an upgrade (-u) and system restart have occurred before running -a."
	echo ""
	echo "All installation targets must be preceeded by configuration options."
	echo "So specifying '-y -G yii-1.1.8.r3324.tar.gz' would be invalid; the call"
	echo "must be '-G yii-1.1.8.r3324.tar.gz -y'. That is, configuration options"
	echo "(in this case -G) before installation options (-y)."
	echo ""
	echo "Installation targets are executed in the order they are specified."
	echo "So specifying -c -s would configure OE and then system packages in that"
	echo "order."
	echo ""
	echo "The following targets specify a 'depends' list of targets required"
	echo "to be executed before the specifed target, and a 'uses'"
	echo "list that describes which (upper case) configuration"
	echo "options are used with that target. Uses options are always optional."
	echo "Note that dependencies are transitive; for example, -m"
	echo "depends on -c, which depends on -o, which in turn depends"
	echo "on -g. The entire list of dependencies must have been installed for"
	echo "invoction of target -m to succeed (-g, -o, -c in that order)."
	echo ""
	echo "Regardless of options used, calling -g (git keys) is mandatory before"
	echo "performing any aspects of the installation."
	echo ""
	echo "All options marked with an asterix require an internet connection; the"
	echo "asterix is not required for invocation."
	echo ""
	echo "  -t: Add user to necessary groups (Apache and OpenEyes users)."
	echo "    Log out or restart to add groups."
	echo "* -u: upgrade OS with latest package updates after adding the user to the"
	echo "    groups required for OE to run (www-data and $OE_GROUP). Does not require"
	echo "    dependencies (other than a fresh Ubuntu 10.04 LTS install)."
	echo "    A fresh restart is required after performing the upgrade."
	echo "    (unless -C true is specified). Uses: -C"
	echo "  -g: create GIT SSH keys for OE repository access (only used for fresh"
	echo "    installations - if keys exist, skip this target). If specified"
	echo "    before any other calls (such as installation), make sure you"
	echo "    call '-P \"ssh git-core\" -i -g' to install ssh and git-core"
	echo "    packages first. The '-i' MUST go before the '-g' and"
	echo "    the '-P \" ssh git-core\"' MUST go before the '-i'."
	echo "    Users will be requested to input information regarding keys."
	echo "* -a: install ALL components in the following options, in the order"
	echo "    they appear. Use when installing fresh on a vanilla Ubuntu"
	echo "    install. Depends: -u, -g, -t. Uses: all options relevant"
	echo "    the following list of targets - see below (-i, -d etc.)."
	echo "    NOT specifying -R or -Q will leave the admin and user database"
	echo "    passwords blank and is *NOT GOOD PRACTICE*."
	echo "* -i: install required packages (default packages or those specified"
	echo "    using -P). Note that the MySQL root password is required at this"
	echo "    stage. Depends: -u. Uses: -P, -R"
	echo "  -d: create OE databases and user, including test DB. Use -R"
	echo "    for password prompt for root create access, and -Q to specify"
	echo "    the password for the '$OE_USER' DB user (or omit either to leave"
	echo "    blank). Depends: -i. Uses: -Q, -R"
	echo "* -y: download YII code, specified with the YII repo and YII file options"
	echo "    -Y and -G. Depends: -i. Uses: -Y, -G"
	echo "  -e: extract YII code from the file specifed using -G and install it to"
	echo "    the site directory (-S). Depends: -y. Uses: -G, -S"
	echo "* -o: download OE code from $OE_REPO,"
	echo "    unless the repository was specified using -O, and store it"
	echo "    in -D <tmp_dir>. Environmental variables \$GIT_BRANCH"
	echo "    ($GIT_BRANCH) and \$GIT_TRACK ($GIT_TRACK)"
	echo "    will be used to determine how to branch/track the sources."
	echo "    Depends: -g, -i. Uses: -O, -D"
	echo "  -c: configure OE code - copy appropriate files PHP configuration"
	echo "    files into protected/config. Specifying -Q will prompt the user"
	echo "    to enter a password for the 'oe' DB user; not specifying -Q"
	echo "    password will leave the password empty."
	echo "    Depends: -o. Uses: -Q"
	echo "  -s: configure system files (PHP ini files, apache config files etc)"
	echo "    Depends: -i"
	echo "  -m: Perform OE YII migration then restart apache. If -T is set to"
	echo "    true, the PHP unit tests are run (this can take a long time)."
	echo "    Depends: -e, -c, -s, -d. Uses: -Q, -T"
}

# 
# Main arg loop. Lower case letters are for commands to issue; upper-case
# letters are for configuration properties (e.g. -X <value>). Lower-case
# commands take no arguments; all upper-case configuration values should
# be specified first. The order of commands is the order they are
# executed in; so specifying -g -d will create GIT keys then create databases,
# in that order.
#
# Inspired by http://wiki.bash-hackers.org/howto/getopts_tutorial
# 
while getopts ":guitdayeocsmhRQL:W:P:Y:G:S:O:D:T:Z:U:C:N:" opt; do
	case $opt in
		A)
			log "Auto migrate set to: $OPTARG"
			AUTO_MIGRATE="$OPTARG"
			;;
		W)
			echo "Write to log file? $OPTARG" >&2
			LOG_FILE_WRITE="$OPTARG"
			;;
		L)
			LOG_FILE="$OPTARG"
			echo "Log file set to: $OPTARG" >&2
			;;
		P)
			log "New package list specified: $OPTARG" >&2
			INSTALL_PACKAGES="$OPTARG"
			;;
		R)
			read_root_db_password
			;;
		Q)
			read_oe_db_password
			;;
		Y)
			log "New YII repository specified: $OPTARG" >&2
			YII_REPO="$OPTARG"
			;;
		G)
			log "New YII TAR GZ file specified: $OPTARG" >&2
			YII_TAR_GZ="$OPTARG"
			;;
		S)
			log "New sites dir specified: $OPTARG" >&2
			SITE_DIR="$OPTARG"
			;;
		O)
			log "New OE download repository specified: $OPTARG" >&2
			OE_REPO="$OPTARG"
			;;
		D)
			log "New temp directory specified: $OPTARG" >&2
			TMP_DIR="$OPTARG"
			;;
		T)
			log "Run tests: $OPTARG" >&2
			PHP_TESTS="$OPTARG"
			;;
		N)
			log "Network proxy set to: $OPTARG" >&2
			NETWORK_PROXY="$OPTARG"
			export http_proxy=$NETWORK_PROXY
			;;
		C)
			log "Continue after upgrade is set to: $OPTARG" >&2
			CONTINUE_AFTER_SYSTEM_UPGRADE="$OPTARG"
			;;
		g)
			create_git_keys
			;;
		a)
			mkdir $TMP_DIR
			install_packages
			db_admin
			download_yii_code
			extract_yii_code
			download_oe_code
			configure_oe_code
			configure_system_files
			migrate
			;;
		t)
			add_user_to_groups
			;;
		u)
			perform_update
			;;
		i)
			install_packages $INSTALL_PACKAGES
			;;
		d)
			db_admin
			;;
		y)
			mkdir $TMP_DIR
			download_yii_code
			;;
		e)
			mkdir $TMP_DIR
			extract_yii_code
			;;
		o)
			mkdir $TMP_DIR
			download_oe_code
			;;
		c)
			mkdir $TMP_DIR
			configure_oe_code
			;;
		s)
			configure_system_files
			;;
		m)
			migrate
			;;
		h)
			print_help
			;;
		\?)
			echo "Invalid option: -$OPTARG" >&2
			;;
	esac
done
