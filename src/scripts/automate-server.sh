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

# The download URL for Automate
AUTOMATE_DOWNLOAD_URL="https://packages.chef.io/files/current/automate/latest/chef-automate_linux_amd64.zip"

AUTOMATE_LICENCE=""

# SPecify the automate command that is used to execute commands
AUTOMATE_COMMAND="chef-automate"

USERNAME=""
PASSWORD=""
EMAILADDRESS=""

FUNCTION_BASE_URL=""
FUNCTION_APIKEY=""
FUNCTION_NAME="chefAMAConfigStore"

#
# Do not modify variables below here
#
OIFS=$IFS
IFS=","
DRY_RUN=0
CONFIG_FILE="config.toml"

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
  unzip_dir=$3

  # Determine if the specified command exists or not
  COMMAND=`which $command_to_check`
  if [ "X$COMMAND" == "X" ]
  then

    # Determine if the downloaded file already exists or not
    download_file=`basename $url`
    if [ ! -f $download_file ]
    then
      echo -e "\t\tdownloading package"
      executeCmd "wget $url"
    else
      echo -e "\t\tpackage already exists"
    fi

    # Install the package
    if [ "X$unzip_dir" == "X" ]
    then
      echo -e "\t\tinstalling package"
      executeCmd "dpkg -i $download_file"
    else
      echo -e "\t\tunpacking"
      cmd=$(printf 'gunzip -S .zip < %s > /usr/local/bin/chef-automate && chmod +x /usr/local/bin/chef-automate' $download_file)
      executeCmd "$cmd"
    fi
  else
    echo -e "\t\talready installed"
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

    -b|--functionbaseurl)
      FUNCTION_BASE_URL="$2"
    ;;

    -n|--functioname)
      FUNCTION_NAME="$2"
    ;;

    -k|--functionapikey)
      FUNCTION_APIKEY="$2"
    ;;
  esac

  # move onto the next argument
  shift
done

echo "Automate server"

# Determine what needs to be done
for operation in $MODE
do

  # Run the necessary operations as spcified
  case $operation in

    # Download and install Automate server package or download and unzip from a URL
    install)

      echo -e "\tInstallation"

      # If a version has been specified then download the package,
      # but if a URL has been specified download that and unpack it
      if [ "X$AUTOMATE_SERVER_VERSION" != "X" ]
      then
        echo "Downloading Automate from a package is not currently supported"
      elif [ "X$AUTOMATE_DOWNLOAD_URL" != "X" ]
      then

        # Download and unpack the automate server
        install $AUTOMATE_COMMAND $AUTOMATE_DOWNLOAD_URL "/usr/local/bin/${AUTOMATE_COMMAND}"
      fi
    ;;

    # Configure the kernel parameters as required by Automate
    kernel)

      echo -e "\tKernel settings"
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

      echo -e "\tConfiguration"
      
      # If the config.toml file does not exist then run the initialisation
      if [ ! -f $CONFIG_FILE ]
      then
        echo -e "\t\tinitialisation"
        cmd="chef-automate init-config"
        executeCmd "$cmd"
      fi

      # Now edit the confguration file with the settings that have been passed to the script
      if [ "X$USERNAME" != "X" ] && \
         [ "X$PASSWORD" != "X" ] && \
         [ "X$EMAILADDRESS" != "X" ] && \
         [ "X$AUTOMATE_LICENCE" != "X" ]
      then

        echo -e "\t\tSetting user information"

        # replace the username in the config.toml file
        cmd=$(printf 'sed -i.bak -r %ss/(email\\s+=\\s+").*(")/\\1%s\\2/g%s %s' "'" $EMAILADDRESS "'" $CONFIG_FILE)
        executeCmd "$cmd"

        cmd=$(printf 'sed -i.bak -r %ss/(username\\s+=\\s+").*(")/\\1%s\\2/g%s %s' "'" $USERNAME "'" $CONFIG_FILE)
        executeCmd "$cmd"

        cmd=$(printf 'sed -i.bak -r %ss/(password\\s+=\\s+").*(")/\\1%s\\2/g%s %s' "'" $PASSWORD "'" $CONFIG_FILE)
        executeCmd "$cmd"

        # setting the licence in the config.toml does not appear to work
        # cmd=$(printf 'sed -i.bak -r %ss/(license\\s+=\\s+").*(")/\\1%s\\2/g%s %s' "'" $AUTOMATE_LICENCE "'" $CONFIG_FILE)
        # executeCmd "$cmd"          
      fi      
    ;;

    # Dpeloy the automate server with the specified settings
    deploy)
      echo -e "\tDeployment"

      cmd="chef-automate deploy config.toml"
      executeCmd "$cmd"
    ;;

    # Apply the licence to automate
    licence)
      echo -e "Apply licence"

      cmd=$(printf 'chef-automate license apply %s' $AUTOMATE_LICENSE)
      executeCmd "$cmd"
    ;;

    # Generate API token and post it into the chefAMAConfigStore function
    token)

      echo -e "\tAPI Token"

      # build up command to get the token from automate
      cmd="chef-automate admin-token | sed -e 's/^[[:space:]]*//'"
      automate_api_token=$(executeCmd "$cmd")

      # build up the command to curl information into the function
      cmd=$(printf "curl -XPOST %s/%s?code=%s -d '{\"automate_token\": \"%s\"}'" $FUNCTION_BASE_URL $FUNCTION_NAME $FUNCTION_APIKEY $automate_api_token)
      executeCmd $cmd
      
    ;;

  esac

done

exit

IFS=$OIFS