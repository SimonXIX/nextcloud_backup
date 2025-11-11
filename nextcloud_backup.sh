#!/bin/bash
# @name: nextcloud_backup_push.sh
# @creation_date: 2025-11-11
# @license: The MIT License <https://opensource.org/licenses/MIT>
# @author: Simon Bowie <simonxix@simonxix.com>
# @purpose: Backs up the Copim project's Nextcloud instance 
# @acknowledgements:
# Nextcloud documentation at https://docs.nextcloud.com/server/21/admin_manual/maintenance/backup.html

############################################################
# variables                                                #
############################################################

DATE=$(date +'%Y-%m-%d')

############################################################
# subprograms                                              #
############################################################

License()
{
  echo 'Copyright 2025 Simon Bowie <simonxix@simonxix.com>'
  echo
  echo 'Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:'
  echo
  echo 'The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.'
  echo
  echo 'THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.'
}

Help()
{
   # Display Help
   echo "This script backs up a Nextcloud instance from a local machine to a remote server"
   echo
   echo "Syntax: nextcloud_backup_push.sh [-l|h|f]"
   echo "options:"
   echo "l     Print the MIT License notification."
   echo "h     Print this Help."
   echo "f     Perform a full backup"
   echo
}

Database_export()
{
    docker exec -it $DATABASE_CONTAINER mysqldump --single-transaction -u $DATABASE_USERNAME -p$DATABASE_PASSWORD $DATABASE > $LOCAL_DIRECTORY/nextcloud_database_$DATE.sql
}

Create_remote_backup_directory()
{
    echo "creating remote backup directory..."
    ssh -i $PRIVATE_KEY $REMOTE_USER@$REMOTE_HOST "mkdir -p $REMOTE_DIRECTORY/$DATE"
}

Backup_Nextcloud_config()
{
    echo "backing up config directory..."
    tar -czf - -C $LOCAL_CONFIG_DIRECTORY .
    tar -czf - -C $(dirname $LOCAL_CONFIG_DIRECTORY) $(basename $LOCAL_CONFIG_DIRECTORY) | \
    ssh -i $PRIVATE_KEY $REMOTE_USER@$REMOTE_HOST \
        "cat > $REMOTE_DIRECTORY/$DATE/nextcloud_config.tgz"
}

Backup_Nextcloud_database()
{
    echo "backing up database..."
    Database_export
    scp -i $PRIVATE_KEY $LOCAL_DIRECTORY/nextcloud_database_$DATE.sql \
        $REMOTE_USER@$REMOTE_HOST:$REMOTE_DIRECTORY/$DATE/
    rm -f $LOCAL_DIRECTORY/nextcloud_database_$DATE.sql
}

Backup_Nextcloud_data()
{
    echo "backing up data directory (this may take a while)..."
    tar -czf - -C $(dirname $LOCAL_DATA_DIRECTORY) $(basename $LOCAL_DATA_DIRECTORY) | \
    ssh -i $PRIVATE_KEY $REMOTE_USER@$REMOTE_HOST \
        "cat > $REMOTE_DIRECTORY/$DATE/nextcloud_data.tgz"
}

############################################################
############################################################
# main program                                             #
############################################################
############################################################

# retrieve variables from .env file (see .env.template for template)
source .env

# error message for no flags
if (( $# == 0 )); then
    Help
    exit 1
fi

# get the options
while getopts ":lhf" flag; do
   case $flag in
      l) # display License
        License
        exit;;
      h) # display Help
        Help
        exit;;
      f) # full backup
        Create_remote_backup_directory
        Backup_Nextcloud_config
        Backup_Nextcloud_database
        Backup_Nextcloud_data
        echo "backup successfully pushed to $REMOTE_HOST:$REMOTE_DIRECTORY/$DATE"
        exit;;
      \?) # invalid option
        Help
        exit;;
   esac
done