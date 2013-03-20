#!/bin/bash

# Copyright Plus10 Technologies, 2012
# 
# Initial author: Richard Meeking, 16th January 2012.
# 
# Script to download, install and configure software necesseary
# to run Opene Eyes Mirth channels on Ubuntu 10.04 LTS.
# 
# Ensure `install.sh' has been invoked successfully first.
# 
# Run
#   sh mirth-install.sh -h
# for help on using this script.
# 

. $OE_INSTALL_SCRIPTS_DIR/base.sh
. $OE_INSTALL_SCRIPTS_DIR/esb/mirth/mirth-install.properties
# Required to install java and maven:
. $OE_INSTALL_SCRIPTS_DIR/java/java-utils.sh

# 
# Create necessary image directories
# 
get_full_path() {
	FULL_MIRTH_PATH=$OE_BASE_GALLERIES_DIR/$1
}

# 
# Create necessary image directories
# 
create_image_directories() {

	create_directory $OE_STEREO_TEXT_IN
	create_directory $OE_STEREO_IMAGES_IN
	create_directory $OE_STEREO_IMAGES_OUT
	create_directory $OE_STEREO_IMAGES_ERR
	create_directory $OE_STEREO_TEXT_OUT
	create_directory $OE_STEREO_TEXT_ERR

	create_directory $OE_VFA_TEXT_IN
	create_directory $OE_VFA_IMAGES_IN
	create_directory $OE_VFA_IMAGES_OUT
	create_directory $OE_VFA_IMAGES_ERR
	create_directory $OE_VFA_IMAGES_HOLDING
	create_directory $OE_VFA_TEXT_OUT
	create_directory $OE_VFA_TEXT_ERR

	# Now link the necessary directories within OpenEyes
	# This is used to link the galleries created by the ESB
	# within the images directory internal to OpenEyes;
	# the linked galleries will contain the encoded patient
	# directory and image information.
	IMAGE_LINK_DIR=$SITE_DIR/$OE_DIR/images
	DIR_OE_STEREO_IMAGES_OUT=`basename $OE_STEREO_IMAGES_OUT`
	if [ ! -d $IMAGE_LINK_DIR/$DIR_OE_STEREO_IMAGES_OUT ]
	then
		sudo ln -s $OE_BASE_GALLERIES_DIR/$DIR_OE_STEREO_IMAGES_OUT $IMAGE_LINK_DIR/$DIR_OE_STEREO_IMAGES_OUT
		report success $? "Linked $OE_STEREO_IMAGES_OUT to directory $IMAGE_LINK_DIR/$DIR_OE_STEREO_IMAGES_OUT"
	fi
	DIR_OE_VFA_IMAGES_OUT=`basename $OE_VFA_IMAGES_OUT`
	if [ ! -d $IMAGE_LINK_DIR/$DIR_OE_VFA_IMAGES_OUT ]
	then
		sudo ln -s $OE_VFA_IMAGES_OUT $IMAGE_LINK_DIR/$DIR_OE_VFA_IMAGES_OUT
		report success $? "Linked $OE_VFA_IMAGES_OUT to directory $IMAGE_LINK_DIR/$DIR_OE_VFA_IMAGES_OUT"
	fi

	log "About to change permissions in $OE_BASE_GALLERIES_DIR/ for group $OE_GROUP"
	sudo chown -R root:$OE_GROUP $OE_BASE_GALLERIES_DIR
	report_success $? "Chown'd $OE_BASE_GALLERIES_DIR for group '$OE_GROUP'"
	sudo chmod -R g+rwx $OE_BASE_GALLERIES_DIR
	report_success $? "Chmod'd $OE_BASE_GALLERIES_DIR for group r/w/x"

}

# 
# 
# 
download_esb() {
	mkdir -p $MIRTH_DOWNLOAD_DIR
	wget $MIRTH_HTTP_DOWNLOAD/$MIRTH_INSTALLER_FILE -O $MIRTH_DOWNLOAD_DIR/$MIRTH_INSTALLER_FILE
	report_success $? "$MIRTH_HTTP_DOWNLOAD/$MIRTH_INSTALLER_FILE downloaded to $MIRTH_DOWNLOAD_DIR"
}

# 
# Installs the ESB.
# 
install_esb() {
	sudo sh $MIRTH_DOWNLOAD_DIR/$MIRTH_INSTALLER_FILE -q -dir $MIRTH_INSTALL_DIR
	report_success $? "Mirth installed"
}

# 
# Copies compiled (.jar) libraries to Mirth, failing on error.
# 
copy_java_projects_to_esb_lib() {
	sudo cp $SCRIPT_DIR/conf/mirth/java-src/encodeutils/target/encodeutils-1.0-SNAPSHOT.jar $MIRTH_LIB_DIR
	report_success $? "Copied Java encode utilities library to $MIRTH_LIB_DIR"
	sudo cp $SCRIPT_DIR/conf/mirth/java-src/imageutils/target/imageutils-1.0-SNAPSHOT.jar $MIRTH_LIB_DIR
	report_success $? "Copied Java image utilities library to $MIRTH_LIB_DIR"
}

# 
# Create directory for logging for Mirth.
# 
create_esb_logging_dir() {
	sudo mkdir $LOG_DIR
	sudo touch $LOG_DIR/$LOG_FILE
	sudo chown -R root:$OE_GROUP $LOG_DIR
	sudo chmod g+rw $LOG_DIR/$LOG_FILE
}

# 
# Start the ESB; fails of the ESB cannot be started.
# 
start_esb() {
	sudo /etc/init.d/mcservice start
	report_success $? "Started Mirth"
}

# 
# Stops the ESB; fails if the ESB cannot be stopped.
# 
stop_esb() {
	sudo /etc/init.d/mcservice stop
	report_success $? "Stopped Mirth"
}

#
# Make changes to the *.xml.in files based on properties and copy
# them to *.xml equivalents
# 
pre_process_mirth_config() {
	ls conf/mirth/channels/*.xml  > /dev/null 2>&1
	if [ $? -eq 0 ]
	then
		log "Removing post-processed XML files"
		rm conf/mirth/channels/*.xml
	else
		log "Performing substitution based on Mirth properties."
	fi
	
	for file in conf/mirth/channels/*.xml.in
	do
		NEW_FILE=`echo $file|awk -F".in" '{print $1}'`
		cp $file $NEW_FILE
		substitute_mirth_properties $NEW_FILE
	done	
	
}

# 
# Substitute one expression for another in a given file.
# 
# $1 the term to search for;
# $2 the text to replace the search term for if successful;
# $3 the file to apply the substitution for
# 
perform_substitution() {
	SEARCH_TERM=$1
	REPLACEMENT=$2
	MIRTH_XML_FILE=$3
	grep -qs $SEARCH_TERM $MIRTH_XML_FILE
	if [ $? -eq 0 ]
	then
		sed -i "s#$SEARCH_TERM#$REPLACEMENT#g" $MIRTH_XML_FILE
		log "Replaced $SEARCH_TERM with $REPLACEMENT in $MIRTH_XML_FILE"
	fi
}

#
# $1 - the file to make substitutions in.
#
substitute_mirth_properties() {
	MIRTH_XML_FILE=$1
	if [ -z $OE_DB_PASSWORD ]
	then
		log "DB password not specified; reading from stdin:"
		read_root_db_password
		OE_DB_PASSWORD=$DB_PASSWORD
	fi
	perform_substitution _OE_DB_PASSWORD_ $OE_DB_PASSWORD $MIRTH_XML_FILE
	perform_substitution _OE_DB_USER_ $OE_DB_USER $MIRTH_XML_FILE
	perform_substitution _OE_DB_HOST_ $OE_DB_HOST $MIRTH_XML_FILE
	perform_substitution _OE_DB_PORT_ $OE_DB_PORT $MIRTH_XML_FILE
	perform_substitution _OE_DB_NAME_ $OE_DB_NAME $MIRTH_XML_FILE
	perform_substitution _OE_STEREO_TEXT_IN_ $OE_STEREO_TEXT_IN $MIRTH_XML_FILE
	perform_substitution _OE_STEREO_IMAGES_IN_ $OE_STEREO_IMAGES_IN $MIRTH_XML_FILE
	perform_substitution _OE_STEREO_IMAGES_OUT_ $OE_STEREO_IMAGES_OUT $MIRTH_XML_FILE
	perform_substitution _OE_STEREO_TEXT_OUT_ $OE_STEREO_TEXT_OUT $MIRTH_XML_FILE
	perform_substitution _OE_STEREO_IMAGES_ERR_ $OE_STEREO_IMAGES_ERR $MIRTH_XML_FILE
	perform_substitution _OE_STEREO_TEXT_ERR_ $OE_STEREO_TEXT_ERR $MIRTH_XML_FILE
	perform_substitution _OE_VFA_TEXT_IN_ $OE_VFA_TEXT_IN $MIRTH_XML_FILE
	perform_substitution _OE_VFA_TEXT_OUT_ $OE_VFA_TEXT_OUT $MIRTH_XML_FILE
	perform_substitution _OE_VFA_IMAGES_IN_ $OE_VFA_IMAGES_IN $MIRTH_XML_FILE
	perform_substitution _OE_VFA_IMAGES_OUT_ $OE_VFA_IMAGES_OUT $MIRTH_XML_FILE
	perform_substitution _OE_VFA_IMAGES_HOLDING_ $OE_VFA_IMAGES_HOLDING $MIRTH_XML_FILE
	perform_substitution _OE_VFA_IMAGES_ERR_ $OE_VFA_IMAGES_ERR $MIRTH_XML_FILE
	perform_substitution _OE_VFA_TEXT_ERR_ $OE_VFA_TEXT_ERR $MIRTH_XML_FILE
	perform_substitution _OE_DB_SERVICE_BUS_DISC_FILES_ $OE_DB_SERVICE_BUS_DISC_FILES $MIRTH_XML_FILE
	perform_substitution _OE_DB_SERVICE_BUS_DISC_INFO_ $OE_DB_SERVICE_BUS_DISC_INFO $MIRTH_XML_FILE
	perform_substitution _OE_DB_SERVICE_BUS_VFA_FILES_ $OE_DB_SERVICE_BUS_VFA_FILES $MIRTH_XML_FILE
	perform_substitution _OE_DB_SERVICE_BUS_VFA_XML_INFO_ $OE_DB_SERVICE_BUS_VFA_XML_INFO $MIRTH_XML_FILE
	perform_substitution _OE_DB_SERVICE_BUS_FILE_AUDIT_ $OE_DB_SERVICE_BUS_FILE_AUDIT $MIRTH_XML_FILE
	perform_substitution _OE_DB_URL_ $OE_DB_URL $MIRTH_XML_FILE
	perform_substitution _OE_DB_DRIVER_ $OE_DB_DRIVER $MIRTH_XML_FILE
	perform_substitution _OE_LOG_DIR_ $OE_LOG_DIR $MIRTH_XML_FILE
	perform_substitution _OE_MIRTH_LOG_FILE_ $OE_MIRTH_LOG_FILE $MIRTH_XML_FILE
}

#
# Prepare the Mirth XML files based on Mirth properties
# and deploy them to the Mirth server. All channels are
# forceably deployed, over-writing the old channel.
# Global scripts and code templates are also deployed.
#
deploy() {
	pre_process_mirth_config
	if [ ! -d $TMP_DIR/mirth ]
	then
		mkdir $TMP_DIR/mirth
	fi
	
	cp conf/mirth/channels/*.xml $TMP_DIR/mirth
	MIRTH_TMP_CONFIG_DIR=$TMP_DIR/mirth
	cd $MIRTH_TMP_CONFIG_DIR

	start_esb
	
	log "Sleeping for $MIRTH_SLEEP seconds to give time for the Mirth service to start..."
	sleep $MIRTH_SLEEP
	log "Sleep finished - attempting to load channels and deploy them"

	if [ -f $MIRTH_CHANNELS_DEPLOY_FILE ]
	then
		rm $MIRTH_CHANNELS_DEPLOY_FILE
		log "Removing previous channel file"
	fi

	for file in $MIRTH_CHANNELS
	do
		echo "import $MIRTH_TMP_CONFIG_DIR/$file force" >> $MIRTH_CHANNELS_DEPLOY_FILE
		log "Adding file '$MIRTH_TMP_CONFIG_DIR/$file' to imports..."
	done

	for file in $MIRTH_CODE_TEMPLATES
	do
		echo "importcodetemplates $MIRTH_TMP_CONFIG_DIR/$file" >> $MIRTH_CHANNELS_DEPLOY_FILE
		log "Adding file '$MIRTH_TMP_CONFIG_DIR/$file' to code template scripts..."
	done

	for file in $MIRTH_GLOBAL_SCRIPTS
	do
		echo "importscripts $MIRTH_TMP_CONFIG_DIR/$file" >> $MIRTH_CHANNELS_DEPLOY_FILE
		log "Adding file '$MIRTH_TMP_CONFIG_DIR/$file' to global scripts..."
	done
	echo "deploy" >> $MIRTH_CHANNELS_DEPLOY_FILE

	echo "Adding channels and deploying"
	cd /opt/mirthconnect
	sudo -E java -cp mirth-cli-launcher.jar \
		-jar mirth-cli-launcher.jar \
		-a https://$MIRTH_IP \
		-u admin \
		-p $MIRTH_PASSWORD \
		-s $MIRTH_TMP_CONFIG_DIR/$MIRTH_CHANNELS_DEPLOY_FILE
	report_success $? "Channels successfully deployed"
}

# 
# Undeploy the Mirth channels - that is, stop them then
# remove them.
# 
undeploy() {
	cp conf/mirth/channels/*.xml $TMP_DIR/mirth
	MIRTH_TMP_CONFIG_DIR=$TMP_DIR/mirth
	cd $MIRTH_TMP_CONFIG_DIR

	start_esb
	
	log "Sleeping for $MIRTH_SLEEP seconds to give time for the Mirth service to start..."
	sleep $MIRTH_SLEEP
	log "Sleep finished - attempting to stop channels"
	
	if [ -f $MIRTH_CHANNELS_UNDEPLOY_FILE ]
	then
		rm $MIRTH_CHANNELS_UNDEPLOY_FILE
		log "Removing previous channel file"
	fi

	for file in $MIRTH_CHANNELS
	do
		CHANNEL_NAME=`basename $file .xml`
		echo "channel stop \"$CHANNEL_NAME\"" >> $MIRTH_CHANNELS_UNDEPLOY_FILE
		log "Adding 'channel stop \"$CHANNEL_NAME\"' to undeploy file $MIRTH_CHANNELS_UNDEPLOY_FILE..."
	done

	for file in $MIRTH_CHANNELS
	do
		CHANNEL_NAME=`basename $file .xml`
		echo "channel remove \"$CHANNEL_NAME\"" >> $MIRTH_CHANNELS_UNDEPLOY_FILE
		log "Adding 'channel remove \"$CHANNEL_NAME\"' to undeploy file $MIRTH_CHANNELS_UNDEPLOY_FILE..."
	done

	echo "resetstats" >> $MIRTH_CHANNELS_UNDEPLOY_FILE
	log "Adding 'clear and 'resetstats'' to undeploy file $MIRTH_CHANNELS_UNDEPLOY_FILE..."

	echo "Stopping channels and undeploying them all..."
	cd /opt/mirthconnect
	sudo -E java -cp mirth-cli-launcher.jar \
		-jar mirth-cli-launcher.jar \
		-a https://$MIRTH_IP \
		-u admin \
		-p $MIRTH_PASSWORD \
		-s $MIRTH_TMP_CONFIG_DIR/$MIRTH_CHANNELS_UNDEPLOY_FILE
	report_success $? "Channels successfully undeployed"
}

# 
# 
# 
print_help() {
	echo "Configure OpenEyes for use with Mirth ESB."
	echo "Note that the associated OpenEyes PHP module"
	echo "should have been migrated first."
	echo ""
	echo "All upper-case arguments specify configurable options;"
	echo "lower-case options are used for installation targets."
	echo ""
	echo "Configuration options (specified before any installation targets):"
	echo ""
	echo "  -D \"<database_password>\": DB password. Default is '$OE_DB_PASSWORD'."
	echo "  -P \"<password>\": Password for connecting to Mirth."
	echo "     Default is '$MIRTH_PASSWORD'."
	echo "  -L \"<lib_dir>\": Directory for copying Java modules to."
	echo "     Default is $MIRTH_LIB_DIR"
	echo "  -M \"<mirth_install_dir>\": Directory for Installing Mirth."
	echo "     Default is $MIRTH_INSTALL_DIR"
	echo ""
	echo "Installation targets:"
	echo ""
	echo "All installation targets must be preceeded by configuration options."
	echo "So specifying -a -D /var/www would be invalid; the call"
	echo "must be -D /var/wwww -a. That is, configuration options"
	echo "(in this case -D) before installation options (-a)."
	echo ""
	echo "Installation targets are executed in the order they are specified."
	echo "So specifying -c -m would configure OE and system packages in that"
	echo "order."
	echo ""
	echo "The following targets specify a 'depends' list of targets required"
	echo "to be executed before the specifed target, and a 'uses'"
	echo "list that describes which (upper case) configuration"
	echo "options are used with that target. Uses options are always optional."
	echo "Note that dependencies are transitive; so all previous targets"
	echo "must have been succesfully completed before installing the specified"
	echo "target in order for invoction of the target to succeed."
	echo ""
	echo "All options marked with an asterix require an external connection; the"
	echo "asterix is not required for invocation."
	echo ""
	echo "  -u: Undeploy OpenEyes channels. Depends: -d. Uses: -P"
	echo "* -a: Install all targets following this one, in the order they appear."
	echo "      Uses: all configuration options relevant to any of the given targets."
	echo "* -j: Install Java."
	echo "* -g: Get Mirth as the file $MIRTH_INSTALLER_FILE from"
	echo "      $MIRTH_HTTP_DOWNLOAD and copy"
	echo "      it to $MIRTH_DOWNLOAD_DIR"
	echo "  -i: Install Mirth and create logging directories. Depends: -j, -g"
	echo "* -m: Install Maven. Depends: -j"
	echo "* -s: Compile and install Java sources for image and encode utilities,"
	echo "      copying the libraries to $MIRTH_LIB_DIR when complete."
	echo "      Depends: -m, -i"
	echo "  -c: Create ESB file input and output for OpenEyes channels"
	echo "      to watch and transfer data to."
	echo "  -d: Deploy OpenEyes channels. Needs an external connection if the"
	echo "      ESB is located on another host. Depends: -s, -c. Uses: -D, -P"
	echo "  -h: Print this message then quit."
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
while getopts ":ajgcidumshP:L:D:M:" opt; do
	case $opt in
		P)
			MIRTH_PASSWORD="$OPTARG"
			log "Mirth password defined by user (-P)"
			;;
		L)
			MIRTH_LIB_DIR="$OPTARG"
			log "Mirth library directory specified: $MIRTH_LIB_DIR"
			;;
		D)
			OE_BASE_DIR="$OPTARG"
			log "OE Base dir set to: $OE_BASE_DIR" >&2
			;;
		a)
			install_java
			download_esb
			install_esb
			create_esb_logging_dir
			install_maven
			compile_and_install_maven_sources
			copy_java_projects_to_esb_lib
			create_system_directories
			deploy
			;;
		j)
			install_java
			;;
		c)
			create_image_directories
			;;
		g)
			download_esb
			;;
		i)
			install_esb
			create_esb_logging_dir
			;;
		d)
			deploy
			;;
		u)
			undeploy
			;;
		j)
			install_java
			;;
		m)
			install_maven
			;;
		s)
			compile_and_install_maven_sources
			copy_java_project	s_to_esb_lib
			;;
		h)
			print_help
			;;
		\?)
			echo "Invalid option: -$OPTARG" >&2
			;;
		esac
	done
exit


