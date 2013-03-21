Export Installation Script Directory
====================================

Before running any scripts, the main installation directory where the scripts were downloaded to needs to be set.

This can be achieved on bash-compatible shells by exporting the `OE_INSTALL_SCRIPTS_DIR` to the directory where the scripts are located. Say, for example, the scripts were located in `/home/dev/Openeyes-Install-Scripts`; then the command to export the installation directory would be:

  export OE_INSTALL_SCRIPTS_DIR=/home/dev/Openeyes-Install-Scripts

Also, the directory can be exported when in the root directory of the installation script project by running

  export OE_INSTALL_SCRIPTS_DIR=`pwd`

Using the `dev-utils` Scripts
=======================

The `dev-utils.sh` script is used for dealing with sources that have been committed and enable a developer to quickly switch between old and new versions of their sources.

*Never* invoke this sript on sources that contain changes; always ensure all changes have been committed before using these utilities.

The typical build cycle for using these scripts is _backup_ - _nuke_ - _restore_. An existing Apache site directory and SQL database can be backed up by calling

	sh dev-utils.sh -b

which will back the Apache site directory and do an SQL dump to the backup directory. For example:

	sh dev-utils.sh -b
	Writing to log file /home/devel/.openeyes-install/oe-install.log
	Preparing to back up current OpenEyes installation...
	No prefix specified; using date '13-03-08.105442'
	Reading in password for root database access. Please enter root database password:
	Again, please:
	Copying main site directory from /var/www/openeyes to /home/devel/.openeyes-install/backups/13-03-08.105442-openeyes
	[sudo] password for devel: 
	Copied /var/www/openeyes to /home/devel/.openeyes-install/backups/13-03-08.105442-openeyes: Success
	Attempting to dump openeyes database to /home/devel/.openeyes-install/backups under the name 13-03-08.105442-openeyes.sql
	MySQL openeyes DB dumped: Success
	Backup complete. You can restore at any time after nuking (-n) by running:
	dev-utils.sh -P 13-03-08.105442 -r

This can be verified by taking a look at the files and directories given in the above output - here only a directory listing is given, although script callers should make a more informed verification:

	$ ls -ltrh ~/.openeyes-install/backups/
	drwxr-xr-x 1 root root   23 Mar  8 10:54 13-03-08.105442-openeyes
	-rw-r--r-- 1 devel devel  20M Mar  8 10:55 13-03-08.105442-openeyes.sql

Note the backup can also be called with the `-P <PREFIX>` option - in which case, the date specified above (13-03-08.105442) can be replaced a (more meaningful) user-defined prefix.

At this point the developer requires to use the other install scripts to get other latest sources for (possibly) different repositories and branches; in order to do this, however, the SQL database and main site directory need to be removed. With them backed up, the _nuke_ option can be called:

	sh dev-utils.sh -n

which outputs:

	$ sh dev-utils.sh -n
	Reading in password for root database access. Please enter root database password:
	Again, please:
	Stopping Apache - if the script does not complete, it will have to be manually restarted.
	Writing to log file /home/devel/.openeyes-install/oe-install.log
	Removed /var/www/openeyes: Success
	Dropped MySQL database openeyes.: Success
	Restarting Apache...
	 * Starting web server apache2
	Warning: DocumentRoot [/var/www/openeyes] does not exist
	Warning: DocumentRoot [/var/www/openeyes] does not exist
	httpd (pid 30329) already running

Ignore the warnings; this is because Apache is restarted (in case there are other sites running with it).

At some point the user might want to restore their database - in which case a _nuke_ would have to be performed. To restore, simply call

	sh dev-utils.sh -P <PREFIX> -r

where `<PREFIX>` is the prefix specified when performing the backup; if no prefix was specified, then it will be the date called when the backup was created. From the above example, the `<PREFIX>` will be `13-03-08.105442`. Here's a restore in action:

	$ sh dev-utils.sh -P 13-03-08.105442 -r
	Writing to log file /home/devel/.openeyes-install/oe-install.log
	Prefix specified for restore/backup: 13-03-08.105442
	Reading in password for root database access. Please enter root database password:
	Again, please:
	Stopping Apache...
	 * Stopping web server apache2
	Warning: DocumentRoot 	[/var/www/openeyes] does not exist
	Warning: DocumentRoot [/var/www/openeyes] does not exist
	 ... waiting [ OK ]
	Database created: Success
	About to import data to database from /home/devel/.openeyes-install/backups/13-03-08.105442-openeyes.sql - this may take a while...
	Database imported from /home/devel/.openeyes-install/backups/13-03-08.105442-openeyes.sql : Success
	Copied /home/devel/.openeyes-install/backups/13-03-08.105442-openeyes to /var/www/openeyes: Success
	chown'd site data: Success
	chmod'd site data - group has r/w/x: Success
	Restarting Apache...
	 * Starting web server apache2 [ OK ] 
	Apache started: Success

Again, the warnings can be ignored.

These development scripts can (and should) be used in conjunction with the main install script when switching to various repositories and branches for development of OpenEyes. 
