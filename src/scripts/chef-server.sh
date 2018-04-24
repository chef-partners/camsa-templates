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

FUNCTION_BASE_URL=""
FUNCTION_APIKEY=""
FUNCTION_NAME="chefAMAConfigStore"

#
# Do not modify variables below here
#
OIFS=$IFS
IFS=","
DRY_RUN=0

# FUNCTIONS ------------------------------------

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
      echo -e "\tdownloading package"
      executeCmd "wget $url"
    fi

    # Install the package
    echo -e "\tinstalling package"
    executeCmd "dpkg -i $download_file"
  else
    echo -e "\talready installed"
  fi
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
      FUNCTION_NAME="$2"
    ;;

    -k|--functionapikey)
      FUNCTION_APIKEY="$2"
    ;;

    -F|--automatefqdn)
      AUTOMATE_SERVER_FQDN="$2"
    ;;
  esac

  # move onto the next argument
  shift
done

echo "Chef server"

# Install necessary pre-requisites for the script
# In this case jq is required to read data from the function
echo -e "\tPre-requisites"
jq=`which jq`
if [ "X$jq" == "X" ]
then
  echo "\t\tinstalling jq"
  cmd="apt-get install -y jq"
  executeCmd "$cmd"
fi

# Determine the full URL for the Azure function
AF_URL=$(printf '%s/%s?code=%s' $FUNCTION_BASE_URL $FUNCTION_NAME $FUNCTION_APIKEY)

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
        echo -e "Not installing Chef server as not version specified. Use -v and rerun the command if this is required"
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

        echo "Configuration"

        # Configure the Chef server for the first time
        echo -e "\treconfigure"
        executeCmd "chef-server-ctl reconfigure"

        # Build up the command to create the new user
        echo -e "\tcreate user: ${CHEF_USER_NAME}"
        cmd=$(printf 'chef-server-ctl user-create %s %s %s "%s" --filename %s.pem' \
              $CHEF_USER_NAME \
              "$CHEF_USER_FULLNAME" \
              $CHEF_USER_EMAILADDRESS \
              $CHEF_USER_PASSWORD \
              $CHEF_USER_NAME)
        executeCmd "${cmd}"

        # Create the named organisation
        echo -e "\tcreate organisation: ${CHEF_ORGNAME}"
        cmd=$(printf 'chef-server-ctl org-create %s "%s" --association-user %s --filename %s-validator.pem' \
              $CHEF_ORGNAME \
              "$CHEF_ORG_DESCRIPTION" \
              $CHEF_USER_NAME \
              $CHEF_ORGNAME)
        executeCmd "${cmd}"
      fi
    ;;

    # Store the user and organisation keys in the storage
    storekeys)

      echo "Storing Keys"
      echo -e "\t$CHEF_USER_NAME"

      cmd=$(printf "curl -XPOST %s -d '{\"%s_key\": \"%s\"}'" $AF_URL $CHEF_USER_NAME `cat ${CHEF_USER_NAME}.pem | base64 -w 0`)
      executeCmd "$cmd"

      echo -e "\t${CHEF_ORGNAME}-validator"

      cmd=$(printf "curl -XPOST %s -d '{\"%s_validator_key\": \"%s\"}'" $AF_URL $CHEF_ORGNAME `cat ${CHEF_ORG_NAME}-validator.pem | base64 -w 0`)
      executeCmd "$cmd"
    ;;

    # Integrate the Chef server with the automate server
    integrate)

      echo -e "Integrate"

      # Get the token from the azure function
      echo -e "\tRetrieving token"
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
      cmd="echo $setting >> /etc/opscode/chef-server.rb"
      executeCmd "$cmd"

      setting=$(printf "profiles['root_url'] = 'https://%s'" $AUTOMATE_SERVER_FQDN)
      cmd="echo $setting >> /etc/opscode/chef-server.rb"
      executeCmd "$cmd"      
    ;;

    reconfigure)
      # Reconfigure the server after creating user and organisation
      echo -e "Reconfigure"
      executeCmd "chef-server-ctl reconfigure"  
    ;;

  esac

done





IFS=$OIFS