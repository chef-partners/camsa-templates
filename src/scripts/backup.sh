#!/bin/bash

#
# Script to run Automate and Chef server backups
#
# It will call the necessary command to create a backup of the relevant server
# and upload it to Azure Blob Storage. It will split up files that are too large
# to be uploaded in one go.
#
# Author: Russell Seymour
#

# VARIABLES -------------------------------------------------------------------


# Location of the configuration file that holds the storage account name,
# container name and access key
# If left empty the script will look in pre-determined locations
CONFIG_FILE=""

# Set the version of the API to use
STORAGE_API_VERSION="2018-03-28"

# Specify what is being backedup, Automate or Chef
# This changes what commands are run and where to look for files
BACKUP_TYPE=""

# Set the size of the chunk when a file needs to be split up
CHUNK_SIZE="256MB"

# Sepcify the log file
LOG_FILE="/var/log/managed_app/backup"

# Declare the working directory to use
WORKING_DIR="/tmp/backup"

DRY_RUN=0

# FUNCTIONS -------------------------------------------------------------------
function urlencode() {
	local LANG=C i c e=''
	for ((i=0;i<${#1};i++)); do
                c=${1:$i:1}
		[[ "$c" =~ [a-zA-Z0-9\.\~\_\-] ]] || printf -v c '%%%02X' "'$c"
                e+="$c"
	done
        echo "$e"
}

function signature() {
  # Set variables from parameters passed to the function
  request_method=$1
  blob_name=$2
  resource=$3
  content_length=$4
  content_type=$5
  x_ms_blob_type=$6

  # Determine the date for the header
  request_date=$(TZ=GMT date "+%a, %d %h %Y %H:%M:%S %Z")

  x_ms_date="x-ms-date:$request_date"
  x_ms_version="x-ms-version:$STORAGE_API_VERSION"

  # Create the signature string
  canonicalized_headers=""

  if [ ! "X$x_ms_blob_type" == "X" ]
  then
    canonicalized_headers="${x_ms_blob_type}\n"
  fi

  canonicalized_headers="${canonicalized_headers}${x_ms_date}\n${x_ms_version}"
  canonicalized_resources="/${STORAGE_ACCOUNT}/${CONTAINER_NAME}/${blob_name}\n${resource}"

  # Determine the string that requires signing
  string_to_sign="${request_method}\n\n\n${content_length}\n\n${content_type}\n\n\n\n\n\n\n${canonicalized_headers}\n${canonicalized_resources}"

  hex_key="$(echo -n $ACCESS_KEY | base64 -d -w0 | xxd -p -c256)"

  # Create the HMAC signature
  signature=$(printf "$string_to_sign" | openssl dgst -sha256 -mac HMAC -macopt "hexkey:$hex_key" -binary |  base64 -w0)

  # Create the authorization
  authorization="Authorization: SharedKey $STORAGE_ACCOUNT:$signature"
}

# Function to output information
# This will be to the screen and to syslog
function log() {
  message=$1
  tabs=$2
  level=$3
  
  if [ "X$level" == "X" ]
  then
    level="notice" 
  fi

  if [ "X$tabs" != "X" ]
  then
    tabs=$(printf '\t%.0s' {0..$tabs})
  fi

  echo -e "${tabs}${message}"

  # output logs to file
  if [ -f $LOG_FILE ]
  then
    timenow=`date -u`
    echo "[${timenow}] ${message}" >> $LOG_FILE
  fi

  logger -t "AUTOMATE_SETUP" -p "user.${level}" "$message"
}

# Execute commands and keep a log of the commands that were executed
function executeCmd()
{
  localcmd=$1

  if [ $DRY_RUN -eq 1 ]
  then
    echo $localcmd
  else
    # Output the command to STDOUT as well so that it is logged inline with the error that are being seen
    # echo $localcmd

    # if a command log does not exist create one
    if [ ! -f commands.log ]
    then
      touch commands.log
    fi

    # Output the commands to the log file
    echo $localcmd >> commands.log

    eval $localcmd

  fi
}

# ----------------------------------------------------------------------------

# Analyse the script arguments and configure the variables accordingly
while [[ $# -gt 0 ]]
do
  key="$1"

  case $key in

    -c|--config)
      CONFIG_FILE="$2"
    ;;

    -s|--chunk-size)
      CHUNK_SIZE="$2"
    ;;

    -t|--type)
      BACKUP_TYPE="$2"
    ;;

    -w|--working-dir)
      WORKING_DIR="$2"
    ;;

    -v|--api-version)
      STORAGE_API_VERSION="$2"
    ;;

  esac

  shift

done

# Ensure that the logfile directory exists
if [ ! -d `dirname $LOG_FILE` ]
then
  log "Creating log file directory"
  mkdir `dirname $LOG_FILE`
fi

# Determine the location of the configuration file, if it is empty
if [ "X$CONFIG_FILE" == "X" ]
then
  log "Determine configuration file location"

  locations=()
  locations+=("$HOME/.managed_app/backup_config")
  locations+=("/etc/managed_app/backup_config")

  # Iterate around the locations to find a file
  for location in ${locations[@]}
  do
    if [ -f $location ]
    then
      $CONFIG_FILE=$location
      break
    fi
  done
else

  if [ ! -f $CONFIG_FILE ]
  then
    log "Unable to locate configuration file: ${CONFIG_FILE}" "" "error"
    exit 1
  fi
fi

# Ensure a config_file has been specified
if [ "X$CONFIG_FILE" == "X" ]
then
  log "No configuration file found. Please specify one using the -c option or create one in a default location" "" "error"
  exit 1
fi

# Ensure that the backup type has been specified
if [ "X$BACKUP_TYPE" == "X" ]
then
  log "Please specify a backup type, either 'automate' or 'chef' using the -t option" "" "error"
  exit 2
fi

# Read in the configuration file
. $CONFIG_FILE

# Ensure that the working directory exists
if [ ! -d $WORKING_DIR ]
then
  log "Creating temporary working directory: ${WORKING_DIR}"
  mkdir -p $WORKING_DIR/files
fi

# Based on the backup type run the necessary commands and zip up the backups
# These will then be uploaded to Azure Storage
case $BACKUP_TYPE in
  automate)

      # Ensure jq is installed
      jq_exists=`which jq`
      if [ "X$jq_exists" == "X" ]
      then
        cmd="apt-get install jq -y"
        executeCmd "$cmd"
      fi

      # Run an automate backup, with the JSON output going to a file
      # This is so that the ID of the backup can be retrieved and thus the filename
      log "Running Automate Server backup"
      BACKUP_RESULTS_PATH="${WORKING_DIR}/backup_result.json"
      cmd="chef-automate backup create --result-json ${BACKUP_RESULTS_PATH} > /dev/null"
      executeCmd "$cmd"

      # Interrogate the results file to get the ID of the backup
      BACKUP_ID=`cat $BACKUP_RESULTS_PATH | jq -r ".result.backup_id"`

      # Create a tar file of the backup directory in the working directory
      BACKUP_PATH="${WORKING_DIR}/${BACKUP_ID}.tar.gz"
      log "Creating archive of backup: $BACKUP_PATH"
      cmd="tar -zcf ${BACKUP_PATH} -C /var/opt/chef-automate/backups ${BACKUP_ID}"
      executeCmd "$cmd"

      # Determine the filename to be used as the blob name
      blob_name="automate_`basename $BACKUP_PATH`"

    ;;

  chef)

      # Run Chef server backup
      log "Running Chef Server backup"
      cmd="chef-server-ctl backup -y"
      executeCmd "$cmd"

      # Determine the path to the backup fle
      BACKUP_FILE=`ls -1tr /var/opt/chef-backup | tail -1`
      BACKUP_PATH="/var/opt/chef-backup/${BACKUP_FILE}"

      # Determine the filename to be used as the blob name
      blob_name="`basename $BACKUP_PATH`"

    ;;

  *)

    log "Unrecognised backup type: ${BACKUP_TYPE}. Please specify 'automate' or 'chef' using the -t option"
    exit 3

esac

# Split the file up
log "Checking overall filesize"
cmd="split -b $CHUNK_SIZE $BACKUP_PATH $WORKING_DIR/files/"
executeCmd "$cmd"

# Variable sued to store the IDs of the block
block_ids=()

log "Uploading backup to Azure Blob Storage"
# Iterate around the files that have been created
for path in ${WORKING_DIR}/files/*
do

  # generate the block id
  block_id=`date +%s%N | base64 -w0`
  #block_id=$(urlencode $block_id)
  
  # Add the block Id to the overall id list
  block_ids+=("<Latest>${block_id}</Latest>")

  # Determine the length of the file
  content_length=`stat -c%s ${path}`

  # Create the necessary signature
  signature "PUT" $blob_name "blockid:${block_id}\ncomp:block" $content_length "" "x-ms-blob-type:BlockBlob"

  curl -X $request_method \
    -T $path \
    -H "$x_ms_date" \
    -H "$x_ms_version" \
    -H "$authorization" \
    -H "$x_ms_blob_type" \
    "https://${STORAGE_ACCOUNT}.blob.core.windows.net/${CONTAINER_NAME}/${blob_name}?comp=block&blockid=${block_id}"

done

# Join the block ids together to create the XML
printf -v latest "  %s\n" "${block_ids[@]}"

# Create the block list to commit the file
# Build up the body of the data
read -r -d '' body << EOF
<?xml version="1.0" encoding="utf-8"?>
<BlockList>
${latest}
</BlockList>
EOF

# Create the signature
signature "PUT" $blob_name "comp:blocklist" ${#body} "text/plain; charset=UTF-8"

curl -X "PUT" \
   -H "$x_ms_date" \
   -H "$x_ms_version" \
   -H "$authorization" \
   -H "Content-Type: text/plain; charset=UTF-8" \
   -d "$body" \
   "https://${STORAGE_ACCOUNT}.blob.core.windows.net/${CONTAINER_NAME}/${blob_name}?comp=blocklist"

# Finally remove the working directory
log "Removing temporary working directory"
rm -rf $WORKING_DIR
