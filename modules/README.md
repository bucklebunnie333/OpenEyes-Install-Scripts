Export Installation Script Directory
====================================

Before running any scripts, the main installation directory where the scripts were downloaded to needs to be set.

This can be achieved on bash-compatible shells by exporting the `OE_INSTALL_SCRIPTS_DIR` to the directory where the scripts are located. Say, for example, the scripts were located in `/home/dev/Openeyes-Install-Scripts`; then the command to export the installation directory would be:

	export OE_INSTALL_SCRIPTS_DIR=/home/dev/Openeyes-Install-Scripts

Also, the directory can be exported when in the root directory of the installation script project by running

	export OE_INSTALL_SCRIPTS_DIR=`pwd`

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

	remote_module_name|local_module_name|git_repository|git_branch|migrate;[other_modules]

Surrounded with quotes.  `local_module_name` is optional, and used only when the remote and local names are different (like EyeDraw for example, that uses a local name of eyedraw). If not using `local_module_name`, supply no spaces between the pipes used to configure the module name. Note that `migrate` is not required and defaults to _true_ - that is, all modules are migrated by default and not requiring the user to answer 'yes' or 'no'. Ensure `migrate` is set to _false_ to prevent migration. Other modules take the same format, and are separated by a semi-colon. For example, to install module OphCiExamination and Sample from the main OpenEyes github site (using a local name of _sample_ for the _Sample repository), with branch release/1.3-moorfields, the script would be invoked using

	bash modules.sh -M "OphCiExamination||git@github.com:openeyes|release/1.3-moorfields;Sample|sample|git@github.com:openeyes|release/1.3-moorfields" -i

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

