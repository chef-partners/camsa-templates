#!/usr/bin/env bash

#
# Script to download and configure Chef server as per the settings
# that are passed to it from the ARM template
#
# This is part of the Azure Managed App configuration
#

# Specify the operation of the script
MODE=""

# Declare and initialise variables
CHEF_SERVER_VERSION=""
CHEF_USER_NAME=""
CHEF_USER_FULLNAME=""
CHEF_USER_EMAILADDRESS=""
CHEF_USER_PASSWORD=""
CHEF_ORGNAME=""
CHEF_ORG_DESCRIPTION=""

AUTOMATE_SERVER_FQDN=""
CHEF_SERVER_FQDN=""

FUNCTION_BASE_URL=""
CONFIGSTORE_FUNCTION_APIKEY=""
CONFIGSTORE_FUNCTION_NAME="chefAMAConfigStore"

MONITOR_USER="monitor"
MONITOR_EMAIL="monitor@chef.io"

BACKUP_SCRIPT_URL=""
BACKUP_CRON="0 1 * * *"

SA_NAME=""
SA_CONTAINER_NAME=""
SA_KEY=""

#
# Do not modify variables below here
#
OIFS=$IFS
IFS=","
DRY_RUN=0

# FUNCTIONS ------------------------------------

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

  logger -t "CHEF_SETUP" -p "user.${level}" $message
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

# Download and install specific package
function install()
{
  command_to_check=$1
  url=$2

  # Determine if the specified command exists or not
  COMMAND=`which $command_to_check`
  if [ "X$COMMAND" == "X" ]
  then

    # Determine if the downloaded file already exists or not
    download_file=`basename $url`
    if [ ! -f $download_file ]
    then
      log "downloading package" 1
      executeCmd "wget -nv $url"
    fi

    # Install the package
    log "installing package" 1
    executeCmd "dpkg -i $download_file"
  else
    log "already installed" 1
  fi
}

# Function to trim whitespace characters from both ends of string
function trim() {
  read -rd '' $1 <<<"${!1}"
}

# ----------------------------------------------

# Use the arguments and the name of the script to determine how the script was called
called="$0 $@"
echo $called >> commands.log

# Analyse the script arguments and configure the variables accordingly
while [[ $# -gt 0 ]]
do
  key="$1"

  case $key in

    -o|--operation)
      MODE="$2"
    ;;

    # Get the version of Chef Server to download
    -v|--version)
      CHEF_SERVER_VERSION="$2"
    ;;

    # Find the chef user name
    -u|--username)
      CHEF_USER_NAME="$2"
    ;;

    # Get the full name of the user
    -f|--fullname)
      CHEF_USER_FULLNAME="$2"
    ;;

    # Get the password that has been set
    -p|--password)
      CHEF_USER_PASSWORD="$2"
    ;;

    # Get the email address
    -a|--address)
      CHEF_USER_EMAILADDRESS="$2"
    ;;

    # Get the organisations
    -O|--org)
      CHEF_ORGNAME="$2"
    ;;

    # Get the org description
    -d|--orgdescription)
      CHEF_ORG_DESCRIPTION="$2"
    ;;

    -b|--functionbaseurl)
      FUNCTION_BASE_URL="$2"
    ;;

    -n|--functioname)
      CONFIGSTORE_FUNCTION_NAME="$2"
    ;;

    -k|--functionapikey)
      CONFIGSTORE_FUNCTION_APIKEY="$2"
    ;;

    -F|--automatefqdn)
      AUTOMATE_SERVER_FQDN="$2"
    ;;

    -C|--chefserverfqdn)
      CHEF_SERVER_FQDN="$2"
    ;;

    -m|--monitoruser)
      MONITOR_USER="$2"
    ;;

    -M|--monitoremail)
      MONITOR_EMAIL="$2"
    ;;

    # Specify the url to the backup script
    --backupscripturl)
      BACKUP_SCRIPT_URL="$2"
    ;;

    --backupcron)
      BACKUP_CRON="$2"
    ;;

    # Get the storage account settings
    --saname)
      SA_NAME="$2"
    ;;

    --sacontainer)
      SA_CONTAINER_NAME="$2"
    ;;

    --sakey)
      SA_KEY="$2"
    ;;    
  esac

  # move onto the next argument
  shift
done

log "Chef server"

# Install necessary pre-requisites for the script
# In this case jq is required to read data from the function
log "Pre-requisites" 1
jq=`which jq`
if [ "X$jq" == "X" ]
then
  log "installing jq" 2
  cmd="apt-get install -y jq"
  executeCmd "$cmd"
fi

# Determine the full URL for the Azure function
AF_URL=$(printf '%s/%s?code=%s' $FUNCTION_BASE_URL $CONFIGSTORE_FUNCTION_NAME $CONFIGSTORE_FUNCTION_APIKEY)

# Determine the necessary operations
for operation in $MODE
do

  # Run the necssary steps as per the operation
  case $operation in

    # Download and install Chef server
    install)

      if [ "X$CHEF_SERVER_VERSION" != "X" ]
      then
        # Download and installed Chef server
        # Determine the download url taking into account the version
        download_url=$(printf 'https://packages.chef.io/files/stable/chef-server/%s/ubuntu/16.04/chef-server-core_%s-1_amd64.deb' $CHEF_SERVER_VERSION $CHEF_SERVER_VERSION)
        install chef-server-ctl $download_url
      else
        log "Not installing Chef server as not version specified. Use -v and rerun the command if this is required" 0 err
      fi

    ;;

    config)
      # Configure the Chef server
      # Only perform this step if all parameters have been specified for the chef server
      if [ "X$CHEF_USER_NAME" != "X" ] && \
          [ "X$CHEF_USER_FULLNAME" != "X" ] && \
          [ "X$CHEF_USER_EMAILADDRESS" != "X" ] && \
          [ "X$CHEF_USER_PASSWORD" != "X" ] && \
          [ "X$CHEF_ORGNAME" != "X" ] && \
          [ "X$CHEF_ORG_DESCRIPTION" != "X" ]
      then

        log "Configuration"

        # Configure the Chef server for the first time
        log "reconfigure" 1
        executeCmd "chef-server-ctl reconfigure"

        # Build up the command to create the new user
        log "create user: ${CHEF_USER_NAME}" 1
        cmd=$(printf 'chef-server-ctl user-create %s %s %s "%s" --filename %s.pem' \
              $CHEF_USER_NAME \
              "$CHEF_USER_FULLNAME" \
              $CHEF_USER_EMAILADDRESS \
              $CHEF_USER_PASSWORD \
              $CHEF_USER_NAME)
        executeCmd "${cmd}"

        # Create the named organisation
        log "create organisation: ${CHEF_ORGNAME}" 1
        cmd=$(printf 'chef-server-ctl org-create %s "%s" --association-user %s --filename %s-validator.pem' \
              $CHEF_ORGNAME \
              "$CHEF_ORG_DESCRIPTION" \
              $CHEF_USER_NAME \
              $CHEF_ORGNAME)
        executeCmd "${cmd}"
      fi

      # Create a user that can be used to monitor the Chef server using the API
      monitor_password=`openssl rand -hex 8`
      log "create monitor user: monitor" 1
      cmd=$(printf 'chef-server-ctl user-create %s Monitoring User %s "%s" -o %s --filename %s.pem' \
            $MONITOR_USER \
            $MONITOR_EMAIL \
            $monitor_password \
            $CHEF_ORGNAME \
            $MONITOR_USER)
      executeCmd "${cmd}"
    ;;

    # Store the user and organisation keys in the storage
    storekeys)

      log "Storing Keys"
      log "$CHEF_USER_NAME" 1

      cmd=$(printf "curl -XPOST %s -d '{\"user\": \"%s\"}'" $AF_URL $CHEF_USER_NAME)
      executeCmd "$cmd"

      cmd=$(printf "curl -XPOST %s -d '{\"user_key\": \"%s\"}'" $AF_URL `cat ${CHEF_USER_NAME}.pem | base64 -w 0`)
      executeCmd "$cmd"

      cmd=$(printf "curl -XPOST %s -d '{\"user_password\": \"%s\"}'" $AF_URL $CHEF_USER_PASSWORD)
      executeCmd "$cmd"      

      log "${CHEF_ORGNAME}-validator" 1

      cmd=$(printf "curl -XPOST %s -d '{\"org\": \"%s\"}'" $AF_URL $CHEF_ORGNAME)
      executeCmd "$cmd"

      cmd=$(printf "curl -XPOST %s -d '{\"org_validator_key\": \"%s\"}'" $AF_URL `cat ${CHEF_ORGNAME}-validator.pem | base64 -w 0`)
      executeCmd "$cmd"

      # Set extra information in the configuration store such as the server FQDN and monitor key
      cmd=$(printf "curl -XPOST %s -d '{\"chefserver_fqdn\": \"%s\"}'" $AF_URL $CHEF_SERVER_FQDN)
      executeCmd "$cmd"

      cmd=$(printf "curl -XPOST %s -d '{\"monitor_user\": \"%s\"}'" $AF_URL $MONITOR_USER)
      executeCmd "$cmd"

      cmd=$(printf "curl -XPOST %s -d '{\"monitor_user_password\": \"%s\"}'" $AF_URL $monitor_password)
      executeCmd "$cmd"      

      cmd=$(printf "curl -XPOST %s -d '{\"monitor_key\": \"%s\"}'" $AF_URL `cat ${MONITOR_USER}.pem | base64 -w 0`)
      executeCmd "$cmd"      
    ;;

    # Integrate the Chef server with the automate server
    integrate)

      log "Integrate"

      # Get the token from the azure function
      log "Retrieving token" 1
      cmd=$(printf "curl -s -XGET '%s&key=automate_token' | jq -r .automate_token " $AF_URL)
      automate_token=$(executeCmd "$cmd")

      # Use this token to configure the chef server
      cmd=$(printf "chef-server-ctl set-secret data_collector token '%s'" $automate_token)
      executeCmd "$cmd"

      cmd="chef-server-ctl restart nginx"
      executeCmd "$cmd"

      cmd="chef-server-ctl restart opscode-erchef"
      executeCmd "$cmd"

      # Now set the data collector and profiles in the Chef server configuration file
      setting=$(printf "data_collector['root_url'] = 'https://%s/data-collector/v0/'" $AUTOMATE_SERVER_FQDN)
      cmd="echo \"$setting\" >> /etc/opscode/chef-server.rb"
      executeCmd "$cmd"

      setting=$(printf "profiles['root_url'] = 'https://%s'" $AUTOMATE_SERVER_FQDN)
      cmd="echo \"$setting\" >> /etc/opscode/chef-server.rb"
      executeCmd "$cmd"      
    ;;

    # Configure backup for the server
    backup)

      BACKUP_SCRIPT_PATH="/usr/local/bin/backup.sh"

      log "Configuring Backup"

      # Ensure that the directories are 
      log "Creating necessary directories" 1
      cmd="mkdir -p /etc/managed_app /var/log/managed_app"
      executeCmd "$cmd"

      # Download the script to the correct location
      log "Downloading backup script" 1
      cmd="curl -o ${BACKUP_SCRIPT_PATH} ${BACKUP_SCRIPT_URL} && chmod +x ${BACKUP_SCRIPT_PATH}"
      executeCmd "$cmd"

      # Write out the configuration file
      cat << EOF > /etc/managed_app/backup_config
STORAGE_ACCOUNT="${SA_NAME}"
CONTAINER_NAME="${SA_CONTAINER_NAME}"
ACCESS_KEY="${SA_KEY}"
EOF

      # Add the script to the crontab for backup
      cmd=$(printf '(crontab -l; echo "%s %s -t chef") | crontab -' $BACKUP_CRON $BACKUP_SCRIPT_PATH)
      executeCmd "$cmd"

      # Perform an initial backup
      cmd="${BACKUP_SCRIPT_PATH} -t chef"
      executeCmd "$cmd"      
    ;;

    reconfigure)
      # Reconfigure the server after creating user and organisation
      log "Reconfigure"
      executeCmd "chef-server-ctl reconfigure"  
    ;;

    # Extract the external IP address to add to the config store
    internalip)

      # Get the IP address
      internal_ip=`ip addr show eth0 | grep -Po 'inet \K[\d.]+'`

      # set the address in the config store
      cmd=$(printf "curl -XPOST %s/%s?code=%s -d '{\"chef_internal_ip\": \"%s\"}'" $FUNCTION_BASE_URL $CONFIGSTORE_FUNCTION_NAME $CONFIGSTORE_FUNCTION_APIKEY $internal_ip)
      executeCmd "$cmd" 
    ;;    

  esac

done





IFS=$OIFS