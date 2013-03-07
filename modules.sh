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
# Initial author: Richard Meeking, 24th July 2012.

SCRIPT_DIR=`dirname $0`

. $SCRIPT_DIR/base.sh
. $SCRIPT_DIR/modules.properties

#
# Install all modules given in the properties file;
# this involves cloning the module with a given
# branch, adding the module to the correct configuration
# file and migrating the module. Failure at any point
# will bomb out.
# 
# 
install_base_modules() {
	mods=$(echo $MODULES | tr ";" "\n")

	for module in $mods
	do
				parse_module_details $module
		if [ -d $SITE_DIR/$OE_DIR/protected/modules/$mod_name ]
		then
			log "It looks like module $mod_name already exists; skipping this one."
		else
			cd $SITE_DIR/$OE_DIR/protected/modules/
			log "NAME: $mod_name, REPO: $mod_repo, BRANCH: $mod_branch"
			do_git_clone $mod_repo/$mod_name.git $mod_name
			cd $SITE_DIR/$OE_DIR/protected/modules/$mod_name
			do_git_checkout $mod_branch
			if [ $mod_migrate = "false" ]
			then
				log "No migration for module $mod_name"
			else
				# implication? If migrating, needs to be added to config too?
				add_module_to_config $mod_name
				migrate_module $mod_name
			fi
		fi
	done
}

# 
# Parse the details of the module, placing results in $mod_name,
# mod_repo, mod_branch and mod_migrate.
# 
# $1 - module in the format module_name | git_repo | git_branch_name | migrate
# 
parse_module_details() {
	module=$1
	mod_name=`echo $module | cut -d \| -f 1`
	mod_repo=`echo $module | cut -d \| -f 2`
	mod_branch=`echo $module | cut -d \| -f 3`
	mod_migrate=`echo $module | cut -d \| -f 4`
}

#
# Migrates the module using the yiic command. If AUTO_MIGRATE
# is set to 'true', no questions will be asked to perform the
# migration and it will happen automatically - use with care!
#
migrate_module() {
	cd $SITE_DIR/$OE_DIR/protected
	log "About to run migration - this may take some time..."
	if [ $AUTO_MIGRATE = 'true' ]
	then
		echo 'yes' | ./yiic migrate --migrationPath=application.modules.$mod_name.migrations
	else
		./yiic migrate --migrationPath=application.modules.$mod_name.migrations
	fi
	report_success $? "$mod_name migrated"
}

# 
# Adds the specified module 
# 
# $1 - modulename; this is the name added to the 'modules' section of the OpenEyes configuration file.
#
add_module_to_config() {
	SITE_OE_CONFIG_DIR=$SITE_DIR/openeyes/protected/config
	grep "// DO NOT EDIT OR REMOVE THIS LINE" $SITE_OE_CONFIG_DIR/local/common.php
	if [ $? -eq 1 ]
	then
		log "local/common.php does not contain text for regex insertion of module name. Adding it now..."
		sed -i "s/'modules' => array(/'modules' => array(\n\/\/ DO NOT EDIT OR REMOVE THIS LINE/g" $SITE_OE_CONFIG_DIR/local/common.php
		report_success $? "Added line '// DO NOT EDIT OR REMOVE THIS LINE' to $SITE_OE_CONFIG_DIR/local/common.php"
	else
		log "local/common.php already appears to contain module insertion code - leaving file untouched."
	fi

	grep $1 $SITE_OE_CONFIG_DIR/local/common.php
	if [ $? -eq 1 ]
	then
		log "local/common.php does not appear to have a module entry; adding it now..."
		sed -i "s/DO NOT EDIT OR REMOVE THIS LINE/DO NOT EDIT OR REMOVE THIS LINE\n\t\t\'$1\',/g" $SITE_OE_CONFIG_DIR/local/common.php
		report_success $? "Added '$1' to $SITE_OE_CONFIG_DIR/local/common.php"
	else
		log "local/common.php already appears to have a module entry for '$1' - leaving file untouched."
	fi
}

#
# Install sample MEH data. Uses the same branch and tracking
# names as the main repository in the properties files.
#
install_sample() {
	read_root_db_password
	cd $SITE_DIR/openeyes/protected/modules
	log "Installing sample patient data..."
	parse_module_details $MODULE_SAMPLE_DATA
	do_git_clone $mod_repo/$mod_name.git $mod_name
	cd $mod_name
	do_git_checkout $$mod_branch
	log "Importing patient data to database - this may take a while..."

	mysql -u root --password=$DB_PASSWORD -D openeyes < sql/openeyes.sql
	report_success $? "Example patient data imported"
	change_permissions $SITE_DIR/openeyes/protected/modules
}

# 
# 
# 
print_help() {
	echo "Install, configure and update OpenEyes modules. Expects an existing"
	echo "OpenEyes installation to be in place."
	echo ""
	echo "All options marked with an asterix require an internet connection,"
	echo "unless the repository is local; asterix is not required for invocation."
	echo ""
	echo "Configuration options MUST preceed installation targets and targets"
	echo "are executed in the order they are specified."
	echo ""
	echo "Configuration options:"
	echo ""
	echo "	-A <true|false>: auto-migrate without question; defaults to true"
	echo "	-M <modules>: overrides the \$MODULES variable in the properties file,"
	echo "		 and uses the same format:"
	echo "			 module_name|git_repo|git_branch_name|migrate;<other module definitions>"
	echo "		 where module name is the name of the module (as a repository name, for"
	echo "		 example, OphCiExamination), git_repo is the location of the git repository"
	echo "		 to download the module from, git_branch is the remote branch to use and"
	echo "		 migrate is an optional true/false value (defaults to true) on whether to"
	echo "		 run a migration for the module or not. Multiple modules can be defined"
	echo "		 by separating the module specifications with a semi-colon."
	echo ""
	echo "Installation targets:"
	echo ""
	echo "* -s: install sample data module and import to DB. Uses: -R"
	echo "* -i: install all modules specified either my -M or by the modules"
	echo "			listed in the module properties file."
	echo "	-h: Print this message then quit."
}

# 
# Main arg loop. Lower case letters are for commands to issue; upper-case
# letters are for configuration properties (e.g. -X <value>). Lower-case
# commands take no arguments; all upper-case configuration values should
# be specified first. The order of commands is the order they are
# executed in; so specifying -s -i will install sample data then
# the modules, in that order.
#
# Inspired by http://wiki.bash-hackers.org/howto/getopts_tutorial
# 
while getopts ":ishM:A:" opt; do
	case $opt in
		A)
			log "Auto migrate set to: $OPTARG"
			AUTO_MIGRATE="$OPTARG"
			;;
		M)
			log "Modules specified: $OPTARG"
			log "Note this overrides the modules given in the properties file."
			MODULES="$OPTARG"
			;;
		i)
			install_base_modules
			;;
		s)
			install_sample
			;;
		h)
			print_help
			;;
		\?)
			echo "Invalid option: -$OPTARG" >&2
			;;
	esac
done
