. $OE_INSTALL_SCRIPTS_DIR/base.sh
. $OE_INSTALL_SCRIPTS_DIR/esb/mirth/mirth-install.properties

PID=1000001
GIVEN_NAME=Chey
FAMILY_NAME=Close

TMP_VFA_DIR=L
TMP_VFA_DIR=R

TEMPLATE_STEREO_DIR=$OE_INSTALL_SCRIPTS_DIR/dev/esb-data/kowa-stereo
TEMPLATE_VFA_DIR=$OE_INSTALL_SCRIPTS_DIR/dev/esb-data/zeiss-vfa
SAMPLE_STEREO_DIR=$OE_INSTALL_SCRIPTS_DIR/dev/esb-data/sample-stereo
SAMPLE_VFA_DIR=$OE_INSTALL_SCRIPTS_DIR/dev/esb-data/sample-vfa

# 
# 
# 
copy_sample_data() {
	if [ -d $SAMPLE_STEREO_DIR ]
	then
		for file in `ls $SAMPLE_STEREO_DIR/*.txt`
		do
			cp $file $OE_STEREO_TEXT_IN
			report_success $? "Copied $file to $OE_STEREO_TEXT_IN"
		done
		for file in `ls $SAMPLE_STEREO_DIR/*.jpg`
		do
			cp $file $OE_STEREO_IMAGES_IN
			report_success $? "Copied $file to $OE_STEREO_IMAGES_IN"
		done
	fi
}

# 
# 
# 
clean_sample_data() {
	if [ -d $SAMPLE_STEREO_DIR ]
	then
		rm -rf $SAMPLE_STEREO_DIR
		log "Removed $SAMPLE_STEREO_DIR"
	fi
	if [ -d $SAMPLE_VFA_DIR ]
	then
		rm -rf $SAMPLE_VFA_DIR
		log "Removed $SAMPLE_VFA_DIR"
	fi
}

# 
# 
# 
generate_sample_stereo_data() {
	mkdir -p $SAMPLE_STEREO_DIR;
	for file in `ls $TEMPLATE_STEREO_DIR/[1-2].jpg`; do
		SIDE='R'
		cp $file "$SAMPLE_STEREO_DIR/ID$PID-`basename $file .jpg`.jpg"
		report_success $? "Created $SAMPLE_STEREO_DIR/ID$PID-`basename $file .jpg`.jpg"
		PHOTO_ID=`basename $file .jpg`;
		cat $TEMPLATE_STEREO_DIR/template.txt | sed s/'_SIDE_'/$SIDE/ | sed s/'_PHOTOID_'/$PHOTO_ID/ | sed s/'_FAMILY_NAME_'/$FAMILY_NAME/ | sed s/'_GIVEN_NAME_'/$GIVEN_NAME/ | sed s/'_PID_'/$PID/ >> "$SAMPLE_STEREO_DIR/ID$PID-$PHOTO_ID.txt"
		report_success $? "Created $SAMPLE_STEREO_DIR/ID$PID-$PHOTO_ID.txt"
	done

	for file in `ls $TEMPLATE_STEREO_DIR/[3-4].jpg`; do
		SIDE='L'
		cp $file "$SAMPLE_STEREO_DIR/ID$PID-`basename $file .jpg`.jpg"
		report_success $? "Created $SAMPLE_STEREO_DIR/ID$PID-`basename $file .jpg`.jpg"
		PHOTO_ID=`basename $file .jpg`;
		cat $TEMPLATE_STEREO_DIR/template.txt | sed s/'_SIDE_'/$SIDE/ | sed s/'_PHOTOID_'/$PHOTO_ID/ | sed s/'_FAMILY_NAME_'/$FAMILY_NAME/ | sed s/'_GIVEN_NAME_'/$GIVEN_NAME/ | sed s/'_PID_'/$PID/ >> "$SAMPLE_STEREO_DIR/ID$PID-$PHOTO_ID.txt"
		report_success $? "Created $SAMPLE_STEREO_DIR/ID$PID-$PHOTO_ID.txt"
	done

}

# 
# 
# 
generate_sample_vfa_data() {
	
	TMP_VFA_DIR=$SAMPLE_VFA_DIR/tmp
	mkdir -p $SAMPLE_VFA_DIR/tmp

	# Create reverse images for the left eye:
	for file in `ls -r $TEMPLATE_VFA_DIR/*.jpg`; do convert -geometry 696x710 -black-threshold 75% -flop $file $TMP_VFA_DIR/left-`basename $file .jpg`.tif; log "Created $TMP_VFA_DIR/left-`basename $file .jpg`.tif"; done
	# Create non reversed TIFF images for the right eye:
	for file in `ls -r $TEMPLATE_VFA_DIR/*.jpg`; do convert -geometry 696x710 -black-threshold 75% $file $TMP_VFA_DIR/right-`basename $file .jpg`.tif; log "Created $TMP_VFA_DIR/right-`basename $file .jpg`.tif"; done

	# for file in *.jpg; do convert -black-threshold 0 -geometry 834x938 $file tif/`basename $file .jpg`.tif; done

	for file in `ls -r $TMP_VFA_DIR/*.tif`;
	do 
		composite -geometry +1351+640 $file $TEMPLATE_VFA_DIR/main_image_1.tif $TMP_VFA_DIR/TEST_`basename $file .tif`.jpg;
		report_success $? "Added sub image $TMP_VFA_DIR/TEST_`basename $file .tif`.jpg to $TEMPLATE_VFA_DIR/main_image_1.tif"
		convert $TMP_VFA_DIR/TEST_`basename $file .tif`.jpg $SAMPLE_VFA_DIR/TEST_`basename $file`;
		report_success $? "Created $SAMPLE_VFA_DIR/TEST_`basename $file`"
		rm $TMP_VFA_DIR/TEST_`basename $file .tif`.jpg
	done

	rm $TMP_VFA_DIR/left-hfa*.tif
	rm $TMP_VFA_DIR/right-hfa*.tif

	for file in `ls -r $SAMPLE_VFA_DIR/TEST_left*.tif`;
	do
		XML_SHORT_FILE=$SAMPLE_VFA_DIR/`basename $file .tif`.xml
		cp $TEMPLATE_VFA_DIR/Example_HFA_short.xml $XML_SHORT_FILE;
		sed -i s/_FAMILY_NAME/$FAMILY_NAME/ $XML_SHORT_FILE
		sed -i s/_GIVEN_NAME/$GIVEN_NAME/ $XML_SHORT_FILE
		sed -i s/_PATIENT_ID/$PID/ $XML_SHORT_FILE
		sed -i s/_FILE_REFERENCE/`basename $file`/ $XML_SHORT_FILE
		sed -i s/_LATERALITY/L/ $XML_SHORT_FILE
		report_success $? "Created $XML_SHORT_FILE"
	done;
	for file in `ls -r $SAMPLE_VFA_DIR/TEST_right*.tif`;
	do
		XML_SHORT_FILE=$SAMPLE_VFA_DIR/`basename $file .tif`.xml
		cp $TEMPLATE_VFA_DIR/Example_HFA_short.xml $XML_SHORT_FILE;
		sed -i s/_FAMILY_NAME/$FAMILY_NAME/ $XML_SHORT_FILE
		sed -i s/_GIVEN_NAME/$GIVEN_NAME/ $XML_SHORT_FILE
		sed -i s/_PATIENT_ID/$PID/ $XML_SHORT_FILE
		sed -i s/_FILE_REFERENCE/`basename $file`/ $XML_SHORT_FILE
		sed -i s/_LATERALITY/R/ $XML_SHORT_FILE
		report_success $? "Created $XML_SHORT_FILE"
	done;
}

# 
# Prints help information.
# 
print_help() {
  echo ""
  echo ""
  echo ""
  echo ""
  echo ""
  echo ""
  echo ""
  echo ""
  echo "Configuration options should be provided first, followed"
  echo "by installation targets which are executed in the order"
  echo "they are specified."
  echo ""
  echo "Configuration options:"
  echo "  -H <hos_num>: prefix for specifying a backup or restore;"
  echo "      the prefix is mandatory for restoring."
  echo "  -G <given_name>: prefix for specifying a backup or restore;"
  echo "      the prefix is mandatory for restoring."
  echo "  -F <family_name>: prefix for specifying a backup or restore;"
  echo "      the prefix is mandatory for restoring."
  echo ""
  echo "Script targets:"
  echo ""
  echo "  -c: Copy all files to the relevant ESB directories."
  echo "  -x: Remove sample data directories."
  echo "  -s: Generate Kowa stereo images and text files."
  echo "  -v: Generate Zeiss VFA images and XML files."
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
while getopts ":csvxhH:G:F:" opt; do
  case $opt in
    P)
      log "PID specified: $OPTARG" >&2
      PID="$OPTARG"
      ;;
    F)
      log "PID specified: $OPTARG" >&2
      GIVEN_NAME="$OPTARG"
      ;;
    G)
      log "PID specified: $OPTARG" >&2
      FAMILY_NAME="$OPTARG"
      ;;
    x)
      clean_sample_data
      ;;
    c)
      copy_sample_data
      ;;
    s)
      generate_sample_stereo_data
      ;;
    v)
      generate_sample_vfa_data
      ;;
    h)
      print_help
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      ;;
  esac
done
