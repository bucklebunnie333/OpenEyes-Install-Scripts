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
# Initial author: Richard Meeking, 5th March 2013.
# 
# Utility script to backup/restore/nuke an existing OpenEyes installation - mainly the Apache site directory and MySQL database.

if [ ! -d "$OE_INSTALL_SCRIPTS_DIR" ]
then
	echo "Expected \$OE_INSTALL_SCRIPTS_DIR to be a directory;"
	echo "Set it correctly by calling"
	echo "  export OE_INSTALL_SCRIPTS_DIR [path]"
	echo "from your current shell, where [path] is the full path"
	echo "to the installation scripts directory."
	exit 1
fi

. $OE_INSTALL_SCRIPTS_DIR/base.sh

DATE=`date +"%y-%m-%d.%H%M%S"`
BACKUP_DIR=$TMP_DIR/backups

# 
# Backup an existing installation.
# 
backup() {

	log "Preparing to back up current OpenEyes installation..."

	if [ -z $PREFIX ]
	then
		PREFIX=$DATE
		log "No prefix specified; using date '$PREFIX'"
	fi
	if [ ! -d $BACKUP_DIR ]
	then 
		mkdir -p $BACKUP_DIR
	fi

	if [ -d "$BACKUP_DIR/$PREFIX-$OE_DIR" -o -d "$BACKUP_DIR/$PREFIX-$OE_DIR.sql" ]
	then
		log "Cannot back up using specified prefix - it already exists; try a different prefix (you used '$PREFIX')"
		exit 1
	fi
	read_root_db_password

	check_dir_exists_or_quit $BACKUP_DIR
	if [ -d $SITE_DIR/$OE_DIR ]
	then
	        log "Copying main site directory from $SITE_DIR/$OE_DIR to $BACKUP_DIR/$PREFIX-$OE_DIR"
		sudo cp -r $SITE_DIR/$OE_DIR $BACKUP_DIR/$PREFIX-$OE_DIR
		report_success $? "Copied $SITE_DIR/$OE_DIR to $BACKUP_DIR/$DATE-$OE_DIR"
	fi
	log "Attempting to dump openeyes database to $BACKUP_DIR under the name $PREFIX-$OE_DIR.sql"
	mysqldump -u root --password=$DB_PASSWORD openeyes > $BACKUP_DIR/$PREFIX-$OE_DIR.sql
	report_success $? "MySQL openeyes DB dumped"
	log "Backup complete. You can restore at any time after nuking (-n) by running:"
	log "    $0 -P $PREFIX -r"
}

# 
# Restore from the back up directory old files.
# Requires that the existing DB and site directory do
# not already exist.
# 
restore() {
	if [ -z "$PREFIX" ] 
	then
		log "Restore date not specified; use -P <PREFIX>"
		exit 1
	fi
	check_file_exists_or_quit $BACKUP_DIR/$PREFIX-$OE_DIR.sql
	check_dir_exists_or_quit $BACKUP_DIR/$PREFIX-$OE_DIR
	read_root_db_password
	if [ -d $SITE_DIR/$OE_DIR ]
	then
		log "You're trying to restore, but the openeyes site directory already exists. Perhaps nuke it or consider a different option."
		exit 1
	fi
	mysql -u root --password=$DB_PASSWORD -e "SHOW DATABASES LIKE 'openeyes'" | grep -q openeyes
	if [ 0 -eq $? ]
	then
		log "Cannot restore; database 'openeyes' already exists. Remove it before continuing."		
		exit 1
	fi

	log "Stopping Apache..."
	sudo /etc/init.d/apache2 stop
	mysql -u root --password=$DB_PASSWORD -e "create database openeyes"
	report_success $? "Database created"
	log "About to import data to database from $BACKUP_DIR/$PREFIX-$OE_DIR.sql - this may take a while..."
	mysql -u root --password=$DB_PASSWORD openeyes < $BACKUP_DIR/$PREFIX-$OE_DIR.sql
	report_success $? "Database imported from $BACKUP_DIR/$PREFIX-$OE_DIR.sql "
	sudo cp -r $BACKUP_DIR/$PREFIX-$OE_DIR $SITE_DIR/$OE_DIR
	report_success $? "Copied $BACKUP_DIR/$PREFIX-$OE_DIR to $SITE_DIR/$OE_DIR"

	sudo chown -R root:www-data $SITE_DIR/$OE_DIR
	report_success $? "chown'd site data"
	sudo chmod -R g+rwx $SITE_DIR/$OE_DIR
	report_success $? "chmod'd site data - group has r/w/x"
	log "Restarting Apache..."
	sudo /etc/init.d/apache2 start
	report_success $? "Apache started"
}

# 
# Drop the database, delete the openeyes site directory. 
# 
nuke() {
	read_root_db_password
	log "Stopping Apache - if the script does not complete, it will have to be manually restarted."
	sudo /etc/init.d/apache2 stop
	diff -r --brief $SITE_DIR $SITE_DIR/$OE_DIR > /dev/null 2>&1
	if [ $? -eq 0 ]
	then
		log "It appears as if \$OE_DIR has not been set, and possibly you're about to nuke $SITE_DIR. Is this really what you want?"
		exit 1
	fi
	sudo rm -rf $SITE_DIR/$OE_DIR
	report_success $? "Removed $SITE_DIR/$OE_DIR"
	mysql -u root --password=$DB_PASSWORD -e "drop database openeyes"
	report_success $? "Dropped MySQL database openeyes."
	log "Restarting Apache..."
	sudo /etc/init.d/apache2 start
}

# 
# Prints help information.
# 
print_help() {
  echo "Backup, restore or nuke an openeyes installation."
  echo "All files are backed up to and restored from \$BACKUP_DIR"
  echo "(currently set to $BACKUP_DIR)."
  echo "Each time a directory is backed up, it is backed up"
  echo "in \$BACKUP_DIR prefixed either with the date in the"
  echo "format yyyy-mm-dd.HHMMss-[name], or with the prefix"
  echo "specified using -P <PREFIX>, where [name]"
  echo "is the file being backed up."
  echo ""
  echo "For development, typically the process is one of"
  echo "backup (-b), then nuke (-n), at which point the main"
  echo "installation script can be used to get a new version"
  echo "of the sources, or optionally a restore (-r) can"
  echo "be used to restore an old copy (using -P)."
  echo ""
  echo "Configuration options should be provided first, followed"
  echo "by installation targets which are executed in the order"
  echo "they are specified."
  echo ""
  echo "Configuration options:"
  echo "  -P <PREFIX>: prefix for specifying a backup or restore;"
  echo "      the prefix is mandatory for restoring."
  echo ""
  echo "Script targets:"
  echo ""
  echo "  -b: Backup the site directory and MySQL database."
  echo "      specifying the date prefix to restore. Uses: -P,"
  echo "      although if not specified is prefixed with the"
  echo "      date format specified above."
  echo "  -r: Restore a previously backed up configuration,"
  echo "      specifying the date prefix to restore. Uses: -P,"
  echo "      which *must* be specified."
  echo "  -n: Nuke/delete the database and site directory."
  echo "      WARNING - make sure you've done a backup first,"
  echo "      and verify that the backup worked. Nuking sources"
  echo "      that have not been checked in to the repository"
  echo "      should not be nuked!"
  echo "  -h: Print this help then quit."
}

# 
# Main arg loop. Lower case letters are for commands to issue; upper-case
# letters are for configuration properties (e.g. -X <value>). Lower-case
# commands take no arguments; all upper-case configuration values should
# be specified first. The order of commands is the order they are
# executed in; so specifying -b -n will back up the site and database and
# then nuke the DB and sources.
# 
# Inspired by http://wiki.bash-hackers.org/howto/getopts_tutorial
# 
while getopts ":rbnhP:" opt; do
  case $opt in
    P)
      log "Prefix specified for restore/backup: $OPTARG" >&2
      PREFIX="$OPTARG"
      ;;
    r)
      restore
      ;;
    b)
      backup
      ;;
    n)
      nuke
      ;;
    h)
      print_help
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      ;;
  esac
done
