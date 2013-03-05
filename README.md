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

	dev adm dialout cdrom **www-data** plugdev lpadmin admin sambashare **openeyes**

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

Answer yes then press `<ENTER>` If the migration is unsuccessful an error will be reported.

Testing the Installation
========================

Browse to `http://localhost` (or wherever the installation host is located) in order to test the installation. A page with log on and password fields should be displayed with appropriate Moorfields skinning.
