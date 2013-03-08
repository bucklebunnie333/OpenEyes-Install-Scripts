Introduction
============

These scripts show are used to install OpenEyes EPR for Ubuntu 10.04 LTS. In particular, the script `install.sh` is the main script to be called for installation. `base.sh` contains utility function calls that are used across other scripts.

Each `.sh` file typically contains a referenced `.properties` file - these files contain environmental variables used for the install. By default they can be left as is and are required only for fine-tuning more complex installations.

Getting Help and Logging
========================

The `install.sh` script can display help; simply run

	sh install.sh -h

to display help information.

The shell scripts also log a lot of their information as the install progresses; the install script is written to the directory `.openeyes-install` by default, in a file named `oe-install.log`. To watch the log as the process installs, from a separate terminal or console the following command can be issued once the install begins:

	tail -f .openeyes-install/oe-install.log

Create Groups and Upgrade 
=========================

Before proceeding with the actual installation, it is necessary to create the correct groups that the user will belong to and update and upgrade the Ubuntu distribution to the latest version. This can be achieved by executing the following from a terminal or command prompt:

	sh install.sh -t -u

Since `-t` adds the user to two different groups, the sudo password must be entered. Once entered, it will not be needed to be re-entered again.

The new groups will not be added until the user logs out.

The `-u` will perform an upgrade. This will take some time.

At the end of this process, the following message will be issued:

	It is important that you now restart your system, especially
	if the upgrade was from a fresh vanilla install.

Restart using the following command:

	sudo shutdown -r now

Once logged in again, verify the user's groups - at the command prompt or in a terminal, type:

	groups

the output of which should include the `www-data` group and the `openeyes` group:

	dev adm dialout cdrom www-data plugdev lpadmin admin sambashare openeyes

Create GIT keys
===============

In order to access the git repository, run the following command:

	sh install.sh -P "ssh git-core" -i -g

Again, sudo password will be prompted for - enter it and follow instructions. You'll need to enter your email for the key -

	Attempting to generate the key. This requires your email used with the GIT repository to identify yourself.
	Enter your email used to generate the key:

After entering the email to be used, a passphrase will be prompted for - press `<ENTER>` to enter a blank passphrase. Now copy the contents of `~/.ssh/id_rsa.pub` to the github account used to access OpenEyes. How to do this is not documented here and can be found on the github pages.

Install Main Packages and OpenEyes
==================================

The next step is to run

	 sh install.sh -Q -R -a

The `-R` is used in the installation of MySQL - and will be the root password used. The -Q is the option to specify the openeyes database user (all calls to the OpenEyes database are performed by this user and never by root).

This will apply the migration without asking the user; to be prompted for the migration, add the `-A` option with the value _false_, thus:

	sh install.sh -Q -R -A false -a

The `-a` command performs the following targets in order:

	-i: install all required packages (LAMP stack etc.);
	-d: create necessary databases and database users, including permissions;
	-y: download YII; 
	-e: extract and configure YII permissions (user permissions etc.);
	-o: clone OpenEyes from the GIT repository;
	-c: configure OpenEyes;
	-s: configure system files; and (finally)
	-m: migrate the OpenEyes database

Note that the following message will be displayed for cloning OpenEyes:

	Downloading OE repository: git@github.com:openeyes/OpenEyes.git
	Initialized empty Git repository in /home/dev/.openeyes-install/openeyes/.git/
	The authenticity of host 'github.com (207.97.227.239)' can't be established.
	RSA key fingerprint is 16:27:ac:a5:76:28:2d:36:63:1b:56:4d:eb:df:a6:48.
	Are you sure you want to continue connecting (yes/no)?

Answer yes to this question then press `<ENTER>`.

Finally, YII will attempt to migrate the OpenEyes database schemas:

	Migrating YII

	Yii Migration Tool v1.0 (based on Yii v1.1.10)

	Creating migration history table "tbl_migration"...done.
	Total 105 new migrations to be applied:
	    m120223_000000_consolidation
	    m120223_071223_tweak_available_event_types
	    m120302_000000_add_patient_date_of_death
	    m120302_092216_pas_patient_assignment
	    ...
	    m130117_105611_multiple_specialties
	    m130121_100122_proc_icce
	    m130301_094914_ozurdex_proc

	Apply the above migrations? [yes|no]

By deafult the 'yes' will be supplied by the script - to override this and set auto-migrate to false, ensure `-A false` is set. Otherwise, answer yes then press `<ENTER>` If the migration is unsuccessful an error will be reported either way.

Testing the Installation
========================

Browse to `http://localhost` (or wherever the installation host is located) in order to test the installation. A page with log on and password fields should be displayed with appropriate Moorfields skinning.

Installing Modules
==================

Two aspects of modular installation are covered here - core modules and sample data.

Core Modules
------------

This section describes how to install some of the easily configurable modules for OpenEyes. In particular, easily configurable modules require minimal configuration, with at most a single migration to ensure the module works. An example of an easily configurable module without need of a migration is the `EyeDraw` module. Examples of modules requiring simple migration are `OphCiExamination` and `OphDrPrescription`.

*NOTE* - module installation covers installing the `Sample` data project - it is recommended to install sample data _before_ installing the main modules specified from using `-i`. Sample data installation is covered below.

Help for module installation can be achieved by invoking the module installation script with `-h`:

	bash modules.sh -h

To install all default OpenEyes modules, simply run

	bash modules.sh -i

Although the `module.properties` file contains a default list of modules ready for use with OpenEyes, these can also be hand-crafted, using the `-M [modules]` option, where `[modules]` takes the format

	module_name|git_repository|git_branch|migrate;[other_modules]

Surrounded with quotes.  Note that `migrate` is not required and defaults to _true_ - that is, all modules are migrated by default and not requiring the user to answer 'yes' or 'no'. Ensure `migrate` is set to _false_ to prevent migration. Other modules take the same format, and are separated by a semi-colon. For example, to install module OphCiExamination and Sample from the main OpenEyes github site, with branch release/1.3-moorfields, the script would be invoked using

	bash modules.sh -M "OphCiExamination|git@github.com:openeyes|release/1.3-moorfields;Sample|git@github.com:openeyes|release/1.3-moorfields" -i

By default, migration will happen automatically (without waiting for the user to enter yes/no); this can be changed using the `-A false` option, as with the main installation (described above). So

	bash modules.sh -A false -i

would prompt the user each time a migration would be performed for individual modules.

Installing Sample Data
----------------------

The Moorfields sample data can be installed by calling

	bash modules.sh -s

This installs records for randomly generated patient names.

Issues: git hangs
-----------------

It is not uncommon for the process to hang, occassionally, when performing installation of core modules and/or sample data. Typically the installation will just stay at one stage and not progress:

	NAME: OphDrPrescription, REPO: git@github.com:openeyes, BRANCH: release/1.2-moorfields
	Attempting to clone git@github.com:openeyes/OphDrPrescription.git to OphDrPrescription (in directory /var/www/openeyes/protected/modules)
	Cloning into 'OphDrPrescription'...

If this happens, simply `CTRL-C` the process and re-run it. Modules that are already installed will be skipped.

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
