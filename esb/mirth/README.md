Export Installation Script Directory
====================================

Before running any scripts, the main installation directory where the scripts were downloaded to needs to be set.

This can be achieved on bash-compatible shells by exporting the `OE_INSTALL_SCRIPTS_DIR` to the directory where the scripts are located. Say, for example, the scripts were located in `/home/dev/Openeyes-Install-Scripts`; then the command to export the installation directory would be:

	export OE_INSTALL_SCRIPTS_DIR=/home/dev/Openeyes-Install-Scripts

Also, the directory can be exported when in the root directory of the installation script project by running

	export OE_INSTALL_SCRIPTS_DIR=`pwd`

Using the `mirth-install` Scripts
=================================

The `mirth-install` script is used to download and install Mirth, as well as other components used to buld and deploy Mirth channels. Mirth requires Java to run, this it is necessary to also install this on the OS.

Mirth also performs several image manipulation routines while capturing data from imported patient images; however, since Mirth does not provide the necessary code to do this, several Java adapters, that are written and compiled and then deployed with Mirth, are also used. This requires that the sources are built from scratch using a build tool named `Maven`.

Help for Mirth installation can be invoked by calling

	sh esb/mirth/mirth-install.sh -h

The entire process can be invoked by calling

	sh esb/mirth/mirth-install.sh -a

which will:

	- install Java;
	- download MirthConnect and install it, creating necessary system log directories;
	- install Apache Maven
	- compile and install Java sources for various utility libraries used by Mirth channels;
	- configure Mirth channels, based on properties;
	- deploy the Mirth channels to the Mirth server

Channels can be undeployed at any time by calling

	sh esb/mirth/mirth-install.sh -u

Note that the Mirth channels are `.xml` files that are uploaded to the Mirth server and then deployed. During development, when the sources are edited in-situ on the server, they need to be exported back to the localhost in order to be checked in. *However*, the `.xml` files are produced from copying `.xml.in` files to it's corresponding `.xml` file using the script. As such, in order to export the downloaded `.xml` files *back* to `.xml.in` files, use the *revert* command:

	sh esb/mirth/mirth-install.sh -r

this will take XML files exported from Mirth to the localhost and turn them back in to `.xml.in` files which can then be diff'd and commited back to the repository.


