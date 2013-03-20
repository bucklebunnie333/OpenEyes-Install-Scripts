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

. $OE_INSTALL_SCRIPTS_DIR/base.sh
. $OE_INSTALL_SCRIPTS_DIR/java/java-utils.properties



# 
# Adapted from http://www.webupd8.org/2012/01/install-oracle-java-jdk-7-in-ubuntu-via.html
# (and in turn directed from https://help.ubuntu.com/community/Java)
# 
# Installs the Oracle JDK.
# 
install_java() {
	sudo add-apt-repository ppa:webupd8team/java
	report_success $? "sudo add-apt-repository ppa:webupd8team/java"
	sudo apt-get update
	report_success $? "sudo apt-get update"
	sudo apt-get install oracle-java7-installer
	report_success $? "sudo apt-get install oracle-java7-installer"
	sudo apt-get install oracle-java7-set-default
	report_success $? "sudo apt-get install oracle-java7-set-default"
}

# 
# Exports the Maven path.
# 
export_maven_path() {
	export MAVEN_HOME=$MAVEN_INSTALL_DIR/$MAVEN_EXTRACTED_DIR_NAME
	report_success $? "Exported MAVEN_HOME as $MAVEN_INSTALL_DIR/$MAVEN_EXTRACTED_DIR_NAME"
	export PATH=$PATH:$MAVEN_HOME/bin
	report_success $? "Exported MAVEN_HOME as $MAVEN_HOME/bin"
}

# 
# Adapted from http://lukieb.wordpress.com/2011/02/15/installing-maven-3-on-ubuntu-10-04-lts-server/
# 
# Installs Maven, used to build the java sources.
# 
install_maven() {
	wget $MAVEN_DOWNLOAD_DIR/$MAVEN_TAR_GZ -O $TMP_DIR/$MAVEN_TAR_GZ
	report_success $? "Downloaded Maven"
	wget $MAVEN_MD5_DIR/$MAVEN_MD5_FILE -O $TMP_DIR/$MAVEN_MD5_FILE
	# TODO check checksum!
	cd $TMP_DIR
	tar -zxvf $MAVEN_TAR_GZ
	report_success $? "Extracted Maven"
	sudo cp -r $MAVEN_EXTRACTED_DIR_NAME $MAVEN_INSTALL_DIR
	report_success $? "Copied Maven to $MAVEN_INSTALL_DIR"
	export_maven_path
	cd -
}

# 
# Compiles all necessary java Maven projects for use with ESB; fails
# if the sources cannot be built.
# 
compile_and_install_maven_sources() {
	# TODO ultimately these will obtained via git
	export_maven_path
	cd $SCRIPT_DIR/conf/mirth/java-src/imageutils
	mvn clean install
	report_success $? "Image utilities installed"
	cd -
	cd $SCRIPT_DIR/conf/mirth/java-src/encodeutils
	mvn clean install
	report_success $? "Encode utilities installed"
	cd -
}

