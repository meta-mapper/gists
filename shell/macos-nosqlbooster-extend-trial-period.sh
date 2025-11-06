#!/bin/bash

# Config

RESOURCES_DIR="/Applications/NoSQLBooster for MongoDB.app/Contents/Resources"
TEMP_DIR="/tmp"
#
ASAR_FILE_NAME="app.asar"

################################################
# Do not edit below this line
################################################

ORIGINAL_ASAR_FILE="$RESOURCES_DIR/$ASAR_FILE_NAME"
TEMP_ASAR_FILE=$TEMP_DIR/$ASAR_FILE_NAME
#
TEMP_ASAR_X_DIR_NAME=$ASAR_FILE_NAME.x
TEMP_ASAR_X_DIR=$TEMP_DIR/$TEMP_ASAR_X_DIR_NAME

################################################
# First of all clean old cache if exists
################################################

printf "Cleaning old cache if exists\n"

rm -rf $TEMP_DIR/$ASAR_FILE_NAME*

sleep 1

################################################
# Copy asar file and its linked resources to temp directory
################################################

printf "\nCopying original '$ASAR_FILE_NAME' file to '$TEMP_DIR' directory\n"

# Linked resources, need for extraction
cp -r "$ORIGINAL_ASAR_FILE.unpacked" $TEMP_ASAR_FILE.unpacked

# Asar file
cp "$ORIGINAL_ASAR_FILE" $TEMP_ASAR_FILE

sleep 1

################################################
# Extract asar file now
################################################

printf "\nExtracting temp '$ASAR_FILE_NAME' to '$TEMP_ASAR_X_DIR_NAME' (Will attempt to install 'asar' package from NPM if not found)\n"

npx asar e $TEMP_ASAR_FILE $TEMP_ASAR_X_DIR

sleep 1

################################################
# Update stuff for extending trial period and removing limits
################################################

printf "\nUpdating some stuff in '$TEMP_ASAR_X_DIR_NAME' for extending trial period and removing limits\n"

# Update max trial days
perl -i -pe's/MAX_TRIAL_DAYS=150/MAX_TRIAL_DAYS=15000/' $TEMP_ASAR_X_DIR/shared/lmCore.js

# Update trial days
perl -i -pe's/TRIAL_DAYS=30/TRIAL_DAYS=3000/' $TEMP_ASAR_X_DIR/shared/lmCore.js

# Update max export rows limit
perl -i -pe's/TRIAL_EXPORT_ROWS_LIMIT=1e3/TRIAL_EXPORT_ROWS_LIMIT=1e10/' $TEMP_ASAR_X_DIR/shared/consts.js

# Update status bar text
perl -i -pe's/this\.fillLicStatusToStatusBar\(\)/\$\("#bottom-bar-lic-info"\)\.html\("Licensed to Manjeet"\)/' $TEMP_ASAR_X_DIR/frontend/appLayout/AppBottomBar.js

sleep 1

################################################
# Repack asar file
################################################

printf "\nRepacking '$ASAR_FILE_NAME' file from updated '$TEMP_ASAR_X_DIR_NAME'\n"

npx asar p $TEMP_ASAR_X_DIR $TEMP_ASAR_FILE

sleep 1

################################################
# Copy new asar file to original resources directory
################################################

printf "\nReplacing new '$ASAR_FILE_NAME' file with original one\n"

cp $TEMP_ASAR_FILE "$ORIGINAL_ASAR_FILE"

sleep 1

################################################

printf "\nDONE!!!\n"
