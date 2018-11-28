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

AUTOMATE_LICENSE=""

# SPecify the automate command that is used to execute commands
AUTOMATE_COMMAND="chef-automate"

USERNAME=""
PASSWORD=""
EMAILADDRESS=""
GDPR_AGREE=""
FULLNAME=""

# Define the variables that hold information about the Azure functions
FUNCTION_BASE_URL=""
OPS_FUNCTION_APIKEY=""
OPS_FUNCTION_NAME="config"

AUTOMATELOG_FUNCTION_NAME="AutomateLog"

BACKUP_SCRIPT_URL=""
BACKUP_CRON="0 1 * * *"

SA_NAME=""
SA_CONTAINER_NAME=""
SA_KEY=""

# Define variables that hold the encoded arguments that can be passed
# to the script. An existing decoded file can also be used
ENCODED_ARGS=""
ARG_FILE=""

# Define where the script called by the cronjob should be saved
SCRIPT_LOCATION="/usr/local/bin/azurefunctionlog.sh"
VERIFY_SCRIPT_LOCATION="/usr/local/bin/verify.sh"

# Set the subscription id which will be used for verification for centralLogging
SUBSCRIPTION_ID=""
VERIFY_URL=""
VERIFY_API_KEY=""

# Initialise variables to handle custom DNS Domain name and server FQDN names
CUSTOM_DOMAIN_NAME=""
CHEF_SERVER_FQDN=""

# In order to configure the DNS for the ManagedApp the script needs to know the
# Public FQDN of the public IP address to create the alias from
PIP_CHEF_SERVER_FQDN=""
PIP_AUTOMATE_SERVER_FQDN=""

# State if this is a Managed App or not
MANAGED_APP=false

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

    -e|--encoded)
      ENCODED_ARGS="$2"
    ;;

    -A|--argfile)
      ARG_FILE="$2"
    ;;

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

    -l|--license)
      AUTOMATE_LICENSE="$2"
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
      OPS_FUNCTION_NAME="$2"
    ;;

    -k|--configstorefunctionapikey)
      OPS_FUNCTION_APIKEY="$2"
    ;;

    -N|--automatelogfunctionname)
      AUTOMATELOG_FUNCTION_NAME="$2"
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

    --subscription)
      SUBSCRIPTION_ID="$2"
    ;;

    --verifyurl)
      VERIFY_URL="$2"
    ;;

    --verifyurlapikey)
      VERIFY_API_KEY="$2"
    ;;

    --customdomainname)
      CUSTOM_DOMAIN_NAME="$2"
    ;;

    -C|--chefserverfqdn)
      CHEF_SERVER_FQDN="$2"
    ;;

    --pipautomate)
      PIP_AUTOMATE_SERVER_FQDN="$2"
    ;;

    --pipchef)
      PIP_CHEF_SERVER_FQDN="$2"
    ;;

    --managedapp)
      MANAGED_APP=$2
    ;;


  esac

  # move onto the next argument
  shift
done

log "Automate server"

# Install necessary pre-requisites for the script
# In this case jq is required to read the decoded JSON data and function responses
log "Pre-requisites" 1
log "jq" 2
jq=`which jq`
if [ "X$jq" == "X" ]
then
  log "installing" 3
  cmd="apt-get install -y jq"
  executeCmd "$cmd"
fi

# Install rmate for remote script editing for VSCode
log "rmate" 2
rmate=`which rmate`
if [ "X$rmate" == "X" ]
then
  log "installing" 3
  cmd="wget -O /usr/local/bin/rmate https://raw.github.com/aurora/rmate/master/rmate && chmod a+x /usr/local/bin/rmate"
  executeCmd "$cmd"
fi

# If encoded arguments have been supplied, decode them and save to file
if [ "X${ENCODED_ARGS}" != "X" ]
then
  log "Decoding arguments"

  ARG_FILE="args.json"
  
  # Decode the bas64 string and write out the ARG file
  echo ${ENCODED_ARGS} | base64 --decode | jq . > ${ARG_FILE}
fi

# If the ARG_FILE has been specified and the file exists read in the arguments
if [ "X${ARG_FILE}" != "X" ]
then
  if [ -f $ARG_FILE ]
  then

    log "Reading JSON vars"

    VARS=`cat ${ARG_FILE} | jq -r '. | keys[] as $k | "\($k)=\"\(.[$k])\""'`

    # Evaluate all the vars in the arguments
    for VAR in "$VARS"
    do
      eval "$VAR"
    done
  else
    log "Unable to find specified args file: ${ARG_FILE}" 0 err
    exit 1
  fi
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
        cmd=$(printf "curl -XPOST %s/%s?code=%s -d '{\"automate_credentials_%s\": %s}'" $FUNCTION_BASE_URL $OPS_FUNCTION_NAME $OPS_FUNCTION_APIKEY $name $value)
        executeCmd "$cmd"
      done
    ;;

    # Apply the license to automate
    license)
      log "Apply license"

      if [ -z "$AUTOMATE_LICENSE" ]
      then
        log "requesting trial license" 1
        FIRSTNAME=$(echo $FULLNAME | cut -d ' ' -f 1)
        LASTNAME=$(echo $FULLNAME | cut -d ' ' -f 2)

        cmd=$(printf "curl -s https://automate-gateway:2000/license/request --resolve automate-gateway:2000:127.0.0.1 \
        --cert /hab/svc/deployment-service/data/deployment-service.crt \
        --cacert /hab/svc/deployment-service/data/root.crt \
        --key /hab/svc/deployment-service/data/deployment-service.key \
        -d '{ \"first_name\": \"%s\", \"last_name\": \"%s\", \"email\": \"%s\", \"gdpr_agree\": %s }' \
        | jq -r '.license'" $FIRSTNAME $LASTNAME $EMAILADDRESS $GDPR_AGREE)

        AUTOMATE_LICENSE=`executeCmd "$cmd"`
        log "applying trial license: $AUTOMATE_LICENSE" 1
      else
        log "applying provided license: $AUTOMATE_LICENSE" 1
      fi

      cmd=$(printf 'chef-automate license apply %s' $AUTOMATE_LICENSE)
      executeCmd "$cmd"
    ;;

    # Generate API token and post it into the chefAMAConfigStore function
    # This operation now creates the user as the token is required
    token)

      log "API Token"

      # 3 api tokens are required
      # - chef server connection
      # - remote stats for 'node' and 'user' count
      # - user token

      # build up command to generate a token for the chef server
      cmd="chef-automate admin-token | sed -e 's/^[[:space:]]*//'"
      automate_api_token=$(executeCmd "$cmd")

      # build up the command to curl information into the function
      cmd=$(printf "curl -XPOST %s/%s?code=%s -d '{\"chef_automate_token\": \"%s\"}'" $FUNCTION_BASE_URL $OPS_FUNCTION_NAME $OPS_FUNCTION_APIKEY $automate_api_token)
      executeCmd "$cmd"

      # build up command to generate a token for the remote stats
      cmd="chef-automate admin-token | sed -e 's/^[[:space:]]*//'"
      automate_api_token=$(executeCmd "$cmd")

      # build up the command to curl information into the function
      cmd=$(printf "curl -XPOST %s/%s?code=%s -d '{\"logging_automate_token\": \"%s\"}'" $FUNCTION_BASE_URL $OPS_FUNCTION_NAME $OPS_FUNCTION_APIKEY $automate_api_token)
      executeCmd "$cmd"

      # build up command to generate a token for the remote stats
      cmd="chef-automate admin-token | sed -e 's/^[[:space:]]*//'"
      automate_api_token=$(executeCmd "$cmd")

      # build up the command to curl information into the function
      cmd=$(printf "curl -XPOST %s/%s?code=%s -d '{\"user_automate_token\": \"%s\"}'" $FUNCTION_BASE_URL $OPS_FUNCTION_NAME $OPS_FUNCTION_APIKEY $automate_api_token)
      executeCmd "$cmd"          

      cmd=$(printf "curl -XPOST %s/%s?code=%s -d '{\"automate_fqdn\": \"%s\"}'" $FUNCTION_BASE_URL $OPS_FUNCTION_NAME $OPS_FUNCTION_APIKEY $AUTOMATE_SERVER_FQDN)
      executeCmd "$cmd"

      cmd=$(printf "curl -XPOST %s/%s?code=%s -d '{\"pip_automate_fqdn\": \"%s\"}'" $FUNCTION_BASE_URL $OPS_FUNCTION_NAME $OPS_FUNCTION_APIKEY $PIP_AUTOMATE_SERVER_FQDN)
      executeCmd "$cmd"      

      # Create the user using the Automate Server API
      cmd=$(printf "curl -H 'api-token: %s' -H 'Content-Type: application/json' -d '{\"name\": \"%s\", \"username\": \"%s\", \"password\": \"%s\"}' --insecure https://localhost/api/v0/auth/users" $automate_api_token $FULLNAME $USERNAME $PASSWORD)
      executeCmd "$cmd"
      
    ;;

    # Setup the cronjob to send data to Log Analytics
    cron)

      # Only perform the cron addition if the variables are set
      if [ "X$AUTOMATELOG_FUNCTION_NAME" != "X" ] && [ "X$OPS_FUNCTION_APIKEY" != "X" ]
      then
         
        log "Configuring CronJob for Log Analytics data"

        log "Creating script: $SCRIPT_LOCATION" 1
        # Create the script that will be called by the cronjob
        cat << EOF > $SCRIPT_LOCATION
#!/usr/bin/env bash

journalctl -fu chef-automate --since "5 minutes ago" --until "now" -o json > /var/log/jsondump.json
curl -H "Content-Type: application/json" -X POST -d @/var/log/jsondump.json ${FUNCTION_BASE_URL}/${AUTOMATELOG_FUNCTION_NAME}?code=${OPS_FUNCTION_APIKEY}      
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

    centrallogging)

      # If the subscription id has been passed as well as the verification URL then attempt to get the central Log Analytics workspace ID and key
      if [ "X$SUBSCRIPTION_ID" != "X" ] && [ "X$VERIFY_URL" != "X" ]
      then

        log "Configuring Central Logging"

        log "Creating script: $VERIFY_SCRIPT_LOCATION" 1

        # Create the script that will be called by the cronjob
        cat << 'EOF' > $VERIFY_SCRIPT_LOCATION
#
# Script to call the verification endpoint and return the workspace id and key for
# central logging
#
# Data will only be returned if the subscription is in the whitelist and the automate license is verified
#

VERIFY_URL="{{VERIFY_URL}}"
VERIFY_API_KEY="{{VERIFY_API_KEY}}"
SUBSCRIPTION_ID="{{SUBSCRIPTION_ID}}"
AUTOMATE_LICENSE="{{AUTOMATE_LICENSE}}"
CONFIG_STORE_URL="{{FUNCTION_BASE_URL}}/config?code={{OPS_FUNCTION_APIKEY}}"

# Build up the curl command to call the remote function
cmd=$(printf "curl -XPOST %s?code=%s -d '{\"subscription_id\": \"%s\", \"automate_license\": \"%s\"}'" $VERIFY_URL $VERIFY_API_KEY $SUBSCRIPTION_ID $AUTOMATE_LICENSE)
response=`eval "$cmd"`

# if the response is not null, turn the response into variables
if [ "X$response" != "X" ]
then

  # Use jq to extract the json payloads into variables
  VARS=`echo ${response} | jq -r '. | keys[] as $k | "\($k)=\"\(.[$k])\""'`

  for VAR in "$VARS"
  do
    eval "$VAR"
  done

  # if the error is false add the workspaceid and key to the config store
  if [ "$error" == "false" ]
  then
    # Perform CURL operations to add the data to the config store
    # Going to use a PUT here so that the item is either created or updated, this is so that it will be updated
    # if the workspace keys change for whatever reason

    # add the workspace key, using the category 'centralLogging'
    category="centralLogging"
    cmd=$(printf "curl -XPUT %s -d '{\"category\": \"%s\", \"workspace_id\": \"%s\"}'" $CONFIG_STORE_URL $category $workspace_id)
    eval "$cmd"

    cmd=$(printf "curl -XPUT %s -d '{\"category\": \"%s\", \"workspace_key\": \"%s\"}'" $CONFIG_STORE_URL $category $workspace_key)
    eval "$cmd"            

  else
    echo "There was an error with the request: ${message}"
  fi
fi
EOF

        # Use sed to patch the tokens at the beginning of the file
        # Use a different delimiter to avoid errors
        log "Patching script" 1

        sed -i.bak "s|{{VERIFY_URL}}|$VERIFY_URL|" $VERIFY_SCRIPT_LOCATION
        sed -i.bak "s|{{VERIFY_API_KEY}}|$VERIFY_API_KEY|" $VERIFY_SCRIPT_LOCATION
        sed -i.bak "s|{{SUBSCRIPTION_ID}}|$SUBSCRIPTION_ID|" $VERIFY_SCRIPT_LOCATION
        sed -i.bak "s|{{AUTOMATE_LICENSE}}|$AUTOMATE_LICENSE|" $VERIFY_SCRIPT_LOCATION
        sed -i.bak "s|{{FUNCTION_BASE_URL}}|$FUNCTION_BASE_URL|" $VERIFY_SCRIPT_LOCATION
        sed -i.bak "s|{{OPS_FUNCTION_NAME}}|$OPS_FUNCTION_NAME|" $VERIFY_SCRIPT_LOCATION
        sed -i.bak "s|{{OPS_FUNCTION_APIKEY}}|$OPS_FUNCTION_APIKEY|" $VERIFY_SCRIPT_LOCATION

        # Ensure correct line endings
        cmd="sed -i.bak 's/\r$//' ${VERIFY_SCRIPT_LOCATION}"
        executeCmd "$cmd"

        # Ensure that the script is executable
        cmd=$(printf "chmod +x %s" $VERIFY_SCRIPT_LOCATION)
        executeCmd "$cmd"

        # Add the script to the cron
        cmd=$(printf '(crontab -l; echo "0 * * * * %s") | crontab -' $VERIFY_SCRIPT_LOCATION)
        executeCmd "$cmd"

        # Perform an initial grab of the workspace information
        executeCmd "$VERIFY_SCRIPT_LOCATION"
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

      # Ensure the backup script has linux line endings
      cmd="sed -i.bak 's/\r$//' ${BACKUP_SCRIPT_PATH}"
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
      cmd=$(printf "curl -XPOST %s/%s?code=%s -d '{\"automate_internal_ip\": \"%s\"}'" $FUNCTION_BASE_URL $OPS_FUNCTION_NAME $OPS_FUNCTION_APIKEY $internal_ip)
      executeCmd "$cmd" 
    ;;

    # Set the DNS entries for the servers, as long as the custom domain name has not been set
    dns)

      if [ "X$CUSTOM_DOMAIN_NAME" == "X" ] && [ "$MANAGED_APP" = true ]
      then

        # Call the service to add the DNS Entries for the Chef and Automate servers
        # Determine the hostnames of the Automate and Chef servers
        AUTOMATE_SERVER_HOSTNAME=`echo $AUTOMATE_SERVER_FQDN | awk -F '.' '{print $1}'`
        CHEF_SERVER_HOSTNAME=`echo $CHEF_SERVER_FQDN | awk -F '.' '{print $1}'`

        # Build up the JSON payload that needs to be sent
        cat << EOF > dns_entries.json
{
  "name": "${FULLNAME}",
  "automate_licence": "${AUTOMATE_LICENSE}",
  "entries": [
    {
      "name": "${CHEF_SERVER_HOSTNAME}",
      "target": "${PIP_CHEF_SERVER_FQDN}",
      "type": "cname"
    },
    {
      "name": "${AUTOMATE_SERVER_HOSTNAME}",
      "target": "${PIP_AUTOMATE_SERVER_FQDN}",
      "type": "cname"
    }    
  ]
}
EOF

        # Build up the CURL command
        cmd=$(printf "curl -XPOST %s/dns?code=%s -d @dns_entries.json" $VERIFY_URL $VERIFY_API_KEY)
        executeCmd "$cmd"

      else
        log "Configuring DNS entries for custom domains is not supported" 0 err
      fi

    ;;

    # Configure SSL for the server
    # If this is for the ManagedApp and a Custom Domain Name has not been set then a
    # Lets Encrypt certificate will be used, otherwise use the certificate and key
    # that have been supplied to the script
    certificate)

      if [ "X$CUSTOM_DOMAIN_NAME" == "X" ] && [ "$MANAGED_APP" = true ]
      then

        # Use Let's Encrypt to get certificate
        # Install the necessary software, if not already installed
        certbot=`which certbot`
        if [ "X$certbot" == "X" ]
        then
          log "Installing CertBot for Let's Encrypt Certificates"
          cmd="apt-get update && apt-get install software-properties-common && add-apt-repository ppa:certbot/certbot -y && apt-get update && apt-get install certbot -y"
          executeCmd "$cmd"
        fi

        # Use the standalone webserver for certbot validation
        # In order to do this, the service has to be stopped
        automate_cmd=`which chef-automate`
        if [ "X$automate_cmd" != "X" ]
        then
          log "Stopping Automate"
          cmd="chef-automate stop"
          executeCmd "$cmd"
        fi

        # Call the certbot command to create a certificate for this node
        cmd=$(printf "certbot certonly --standalone -d %s -m %s --agree-tos -n" $AUTOMATE_SERVER_FQDN $EMAILADDRESS)
        executeCmd "$cmd"

        # Set the path to the CERT and KEY files
        SSL_CERT_PATH=$(printf "/etc/letsencrypt/live/%s/fullchain.pem" $AUTOMATE_SERVER_FQDN)
        SSL_KEY_PATH=$(printf "/etc/letsencrypt/live/%s/privkey.pem" $AUTOMATE_SERVER_FQDN)

        # Start Automate again
        if [ "X$automate_cmd" != "X" ]
        then
          log "Starting Automate"
          cmd="chef-automate start"
          executeCmd "$cmd"
        fi        
      fi

      # Create a toml file with the necessary contents that can be applied to Automate
      # https://automate.chef.io/docs/configuration/#load-balancer-certificate-and-private-key

      # Read the certificate and the provate key
      ssl_certificate=`cat $SSL_CERT_PATH`
      ssl_key=`cat $SSL_KEY_PATH`

      cat << EOF > ssl_cert.toml
[[load_balancer.v1.sys.frontend_tls]]
# The TLS certificate for the load balancer frontend
cert = """
${ssl_certificate}
"""

# The TLS RSA key for the load balancer frontend
key = """
${ssl_key}
"""
EOF

      # Run command to patch the automate deployment
      cmd="chef-automate config patch ssl_cert.toml"
      executeCmd "$cmd"

    ;;
  
  esac

done

exit

IFS=$OIFS