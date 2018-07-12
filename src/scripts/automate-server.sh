#!/bin/bash

#
# Script to download and configure Automate server as per the settings
# that are passed to it from the ARM template
#
# This is part of the Azure Managed App configuration
#

# Declare and initialise variables

# Specify the operation of the script
MODE=""

# Version of Automate to download
AUTOMATE_SERVER_VERSION=""
AUTOMATE_SERVER_FQDN=""

# The download URL for Automate
AUTOMATE_DOWNLOAD_URL="https://packages.chef.io/files/current/automate/latest/chef-automate_linux_amd64.zip"

AUTOMATE_LICENCE=""

# SPecify the automate command that is used to execute commands
AUTOMATE_COMMAND="chef-automate"

USERNAME=""
PASSWORD=""
EMAILADDRESS=""
FULLNAME=""

# Define the variables that hold information about the Azure functions
FUNCTION_BASE_URL=""
CONFIGSTORE_FUNCTION_APIKEY=""
CONFIGSTORE_FUNCTION_NAME="chefAMAConfigStore"

AUTOMATELOG_FUNCTION_APIKEY=""
AUTOMATELOG_FUNCTION_NAME="AutomateLog"

BACKUP_SCRIPT_URL=""
BACKUP_CRON="0 1 * * *"

SA_NAME=""
SA_CONTAINER_NAME=""
SA_KEY=""

# Define where the script called by the cronjob should be saved
SCRIPT_LOCATION="/usr/local/bin/azurefunctionlog.sh"

#
# Do not modify variables below here
#
OIFS=$IFS
IFS=","
DRY_RUN=0
CONFIG_FILE="config.toml"

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

  logger -t "AUTOMATE_SETUP" -p "user.${level}" $message
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
    echo "$localcmd" >> commands.log

    eval "$localcmd"

  fi
}

# Download and install specific package
function install()
{
  command_to_check=$1
  url=$2
  unzip_dir=$3

  # Determine if the specified command exists or not
  COMMAND=`which $command_to_check`
  if [ "X$COMMAND" == "X" ]
  then

    # Determine if the downloaded file already exists or not
    download_file=`basename $url`
    if [ ! -f $download_file ]
    then
      log "downloading package" 2
      executeCmd "wget -nv $url"
    else
      log "package already exists" 2
    fi

    # Install the package
    if [ "X$unzip_dir" == "X" ]
    then
      log "installing package" 2
      executeCmd "dpkg -i $download_file"
    else
      log "unpacking" 2
      cmd=$(printf 'gunzip -S .zip < %s > /usr/local/bin/chef-automate && chmod +x /usr/local/bin/chef-automate' $download_file)
      executeCmd "$cmd"
    fi
  else
    log "already installed" 2
  fi
}

# Function to trim whitespace characters from both ends of string
function trim() {
  read -rd '' $1 <<<"${!1}"
}

# ----------------------------------------------

# Use the arguments and the name of the script to determine how the script was called
called="$0 $@"
echo -e "$called" >> commands.log

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
      AUTOMATE_SERVER_VERSION="$2"
    ;;

    -U|--url)
      AUTOMATE_DOWNLOAD_URL="$2"
    ;;

    -l|--licence)
      AUTOMATE_LICENCE="$2"
    ;;

    -u|--username)
      USERNAME="$2"
    ;;

    -p|--password)
      PASSWORD="$2"
    ;;

    -e|--email)
      EMAILADDRESS="$2"
    ;;

    # Get the full name of the user
    -f|--fullname)
      FULLNAME="$2"
    ;;    

    -b|--functionbaseurl)
      FUNCTION_BASE_URL="$2"
    ;;

    -n|--configstorefunctioname)
      CONFIGSTORE_FUNCTION_NAME="$2"
    ;;

    -k|--configstorefunctionapikey)
      CONFIGSTORE_FUNCTION_APIKEY="$2"
    ;;

    -N|--automatelogfunctionname)
      AUTOMATELOG_FUNCTION_NAME="$2"
    ;;

    -K|--automatelogfunctionkey)
      AUTOMATELOG_FUNCTION_APIKEY="$2"
    ;;

    -F|--automatefqdn)
      AUTOMATE_SERVER_FQDN="$2"
    ;;

    # Specify the location of the script, this must be a full path
    --scriptlocation)
      SCRIPT_LOCATION="$2"
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

log "Automate server"

# Install necessary pre-requisites for the script
# In this case jq is required to read data from the function
log "Pre-requisites" 1

# Install rmate for remote script editing for VSCode
log "rmate" 2
rmate=`which rmate`
if [ "X$rmate" == "X" ]
then
  log "installing" 3
  cmd="wget -O /usr/local/bin/rmate https://raw.github.com/aurora/rmate/master/rmate && chmod a+x /usr/local/bin/rmate"
  executeCmd "$cmd"
fi

# Determine what needs to be done
for operation in $MODE
do

  # Run the necessary operations as spcified
  case $operation in

    # Download and install Automate server package or download and unzip from a URL
    install)

      log "Installation" 1

      # If a version has been specified then download the package,
      # but if a URL has been specified download that and unpack it
      if [ "X$AUTOMATE_SERVER_VERSION" != "X" ]
      then
        log "Downloading Automate from a package is not currently supported" 0 err
      elif [ "X$AUTOMATE_DOWNLOAD_URL" != "X" ]
      then

        # Download and unpack the automate server
        install $AUTOMATE_COMMAND $AUTOMATE_DOWNLOAD_URL "/usr/local/bin/${AUTOMATE_COMMAND}"
      fi
    ;;

    # Configure the kernel parameters as required by Automate
    kernel)

      log "Kernel settings" 1
      cmd="sysctl -w vm.max_map_count=262144"
      executeCmd "$cmd"
      cmd="sysctl -w vm.dirty_expire_centisecs=20000"
      executeCmd "$cmd"
      cmd="echo vm.max_map_count=262144 > /etc/sysctl.d/50-chef-automate.conf"
      executeCmd "$cmd"
      cmd="echo vm.dirty_expire_centisecs=20000 >> /etc/sysctl.d/50-chef-automate.conf"
      executeCmd "$cmd"      
    ;;

    # Initialise Automate
    config)

      log "Configuration" 1
      
      # If the config.toml file does not exist then run the initialisation
      if [ ! -f $CONFIG_FILE ]
      then
        log "initialisation" 2
        cmd="chef-automate init-config"
        executeCmd "$cmd"
      fi   
    ;;

    # Dpeloy the automate server with the specified settings
    deploy)
      log "Deployment" 1

      cmd="GRPC_GO_LOG_SEVERITY_LEVEL=info GRPC_GO_LOG_VERBOSITY_LEVEL=2 chef-automate deploy config.toml --accept-terms-and-mlsa --debug"
      executeCmd "$cmd"

      # Get information from the automate-credentials.toml file to add to the config store
      cat automate-credentials.toml | while read line
      do
        [[ "$line" =~ ^#.*$ ]] && continue

        # Get the name of the parameter and the value
        name="$(echo "${line%=*}" | tr -d '[:space:]')"
        value=${line#*=}

        # add each value to the config store
        cmd=$(printf "curl -XPOST %s/%s?code=%s -d '{\"automate_credentials_%s\": %s}'" $FUNCTION_BASE_URL $CONFIGSTORE_FUNCTION_NAME $CONFIGSTORE_FUNCTION_APIKEY $name $value)
        executeCmd "$cmd"
      done
    ;;

    # Apply the licence to automate
    licence)
      log "Apply licence"

      cmd=$(printf 'chef-automate license apply %s' $AUTOMATE_LICENCE)
      executeCmd "$cmd"
    ;;

    # Generate API token and post it into the chefAMAConfigStore function
    # This operation now creates the user as the token is required
    token)

      log "API Token"

      # build up command to get the token from automate
      cmd="chef-automate admin-token | sed -e 's/^[[:space:]]*//'"
      automate_api_token=$(executeCmd "$cmd")

      # build up the command to curl information into the function
      cmd=$(printf "curl -XPOST %s/%s?code=%s -d '{\"automate_token\": \"%s\"}'" $FUNCTION_BASE_URL $CONFIGSTORE_FUNCTION_NAME $CONFIGSTORE_FUNCTION_APIKEY $automate_api_token)
      executeCmd "$cmd"

      cmd=$(printf "curl -XPOST %s/%s?code=%s -d '{\"automate_fqdn\": \"%s\"}'" $FUNCTION_BASE_URL $CONFIGSTORE_FUNCTION_NAME $CONFIGSTORE_FUNCTION_APIKEY $AUTOMATE_SERVER_FQDN)
      executeCmd "$cmd"

      # Create the user using the Automate Server API
      cmd=$(printf "curl -H 'api-token: %s' -H 'Content-Type: application/json' -d '{\"name\": \"%s\", \"username\": \"%s\", \"password\": \"%s\"}' --insecure https://localhost/api/v0/auth/users" $automate_api_token $FULLNAME $USERNAME $PASSWORD)
      executeCmd "$cmd"
      
    ;;

    # Setup the cronjob to send data to Log Analytics
    cron)

      # Only perform the cron addition if the variables are set
      if [ "X$AUTOMATELOG_FUNCTION_NAME" != "X" ] && [ "X$AUTOMATELOG_FUNCTION_APIKEY" != "X" ]
      then
         
        log "Configuring CronJob for Log Analytics data"

        log "Creating script: $SCRIPT_LOCATION" 1
        # Create the script that will be called by the cronjob
        cat << EOF > $SCRIPT_LOCATION
#!/usr/bin/env bash

journalctl -fu chef-automate --since "5 minutes ago" --until "now" -o json > /var/log/jsondump.json
curl -H "Content-Type: application/json" -X POST -d @/var/log/jsondump.json ${FUNCTION_BASE_URL}/${AUTOMATELOG_FUNCTION_NAME}?code=${AUTOMATELOG_FUNCTION_APIKEY}      
EOF

        # Ensure that the script is executable
        cmd=$(printf "chmod +x %s" $SCRIPT_LOCATION)
        executeCmd "$cmd"

        log "Adding cron entry" 1

        # Add the script to cron
        cmd=$(printf '(crontab -l; echo "*/5 * * * * %s") | crontab -' $SCRIPT_LOCATION)
        executeCmd "$cmd"
      else

        log "Unable to complete Cron setup as function name and / or API key have not been specified. Please use -N and -K to specify them"
      fi

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
      cmd="curl -o ${BACKUP_SCRIPT_PATH} \"${BACKUP_SCRIPT_URL}\" && chmod +x ${BACKUP_SCRIPT_PATH}"
      executeCmd "$cmd"

      # Write out the configuration file
      cat << EOF > /etc/managed_app/backup_config
STORAGE_ACCOUNT="${SA_NAME}"
CONTAINER_NAME="${SA_CONTAINER_NAME}"
ACCESS_KEY="${SA_KEY}"
EOF

      # Add the script to the crontab for backup
      cmd=$(printf '(crontab -l; echo "%s %s -t automate") | crontab -' $BACKUP_CRON $BACKUP_SCRIPT_PATH)
      executeCmd "$cmd"

      # Perform an initial backup
      cmd="${BACKUP_SCRIPT_PATH} -t automate"
      executeCmd "$cmd"
    ;;

    # Extract the external IP address to add to the config store
    internalip)

      # Get the IP address
      internal_ip=`ip addr show eth0 | grep -Po 'inet \K[\d.]+'`

      # set the address in the config store
      cmd=$(printf "curl -XPOST %s/%s?code=%s -d '{\"automate_internal_ip\": \"%s\"}'" $FUNCTION_BASE_URL $CONFIGSTORE_FUNCTION_NAME $CONFIGSTORE_FUNCTION_APIKEY $internal_ip)
      executeCmd "$cmd" 
    ;;
  
  esac

done

exit

IFS=$OIFS