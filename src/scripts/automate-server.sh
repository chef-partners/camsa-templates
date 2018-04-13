#!/bin/bash

#
# Script to download and configure Automate server as per the settings
# that are passed to it from the ARM template
#
# This is part of the Azure Managed App configuration
#

# Declare and initialise variables
AUTOMATE_SERVER_VERSION=""

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
    echo $localcmd

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
  comnmand_to_check=$1
  url $2

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

# Analyse the script arguments and configure the variables accordingly
while [[ $# -gt 0 ]]
do
  key="$1"

  case $key in

    # Get the version of Chef Server to download
    -v|--version)
      AUTOMATE_SERVER_VERSION="$2"
    ;;
  esac

  # move onto the next argument
  shift
done

echo "Checking Automate server"

# Download and installed Chef server
# Determine the download url taking into account the version
download_url=$(printf 'https://packages.chef.io/stable/ubuntu/16.04/chef-server-core-_%s-1.amd64.deb' $AUTOMATE_SERVER_VERSION)
install automate-ctl $download_url

