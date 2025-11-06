#!/bin/bash

############# Editable variables #############

USER_GROUP="manjeet:manjeet"

VERSION="6.2.17";

##############################################

FILENAME="nosqlbooster4mongo-$VERSION.AppImage";
DIRECTORY="/tmp/NoSQL-Booster-$VERSION";

printf "\nCreating Directory for version $VERSION\n";
sleep 2;

mkdir -p $DIRECTORY;

printf "\nChanging to Directory for $VERSION\n";
sleep 2;

cd $DIRECTORY;

printf "\nDownloading NoSQL Booter via wget\n"
sleep 2

wget -c -O $FILENAME "https://s3.mongobooster.com/download/releasesv6/$FILENAME"

printf "\nMaking '$FILENAME' executeable\n"
sleep 2

chmod +x "$FILENAME"

printf "\nExtracting AppImage contents to './squashfs-root'\n"
sleep 2

"./$FILENAME" --appimage-extract

printf "\nChanging to resources directory for version $VERSION\n";
sleep 2;

cd squashfs-root/resources

printf "\nCreating backup of orignal 'app.asar' file\n"
sleep 2

cp app.asar app.asar.original

printf "\nExtracting app.asar file to app.asar.x (It will install npm asar package if not already exists)\n"
sleep 2

npx asar e app.asar app.asar.x

printf "\nUpdating some stuff to extend trial period and mutate trial limits\n"
sleep 2

# Update max trial days
perl -i -pe's/MAX_TRIAL_DAYS=150/MAX_TRIAL_DAYS=15000/' app.asar.x/shared/lmCore.js

# Update trial days
perl -i -pe's/TRIAL_DAYS=30/TRIAL_DAYS=3000/' app.asar.x/shared/lmCore.js

# Update max export rows limit
perl -i -pe's/TRIAL_EXPORT_ROWS_LIMIT=1e3/TRIAL_EXPORT_ROWS_LIMIT=1e10/' app.asar.x/shared/consts.js

# Update status bar text
perl -i -pe's/this\.fillLicStatusToStatusBar\(\)/\$\("#bottom-bar-lic-info"\)\.html\("Licensed to Manjeet"\)/' app.asar.x/frontend/appLayout/AppBottomBar.js


printf "\nRepacking to asar.app file from app.asar.x\n"
sleep 2

npx asar p app.asar.x app.asar

printf "\nChanging to NoSQL Booster version $VERSION root directory\n";
sleep 2;

cd ../

printf "\nFixing Permissions for NoSQL Booster $VERSION\n"
sleep 2;

chown -R $USER_GROUP ./

printf "\nLaunching NoSQL Booster now...\n";
sleep 2

./nosqlbooster4mongo --no-sandbox