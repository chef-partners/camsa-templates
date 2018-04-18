#!/bin/bash

#
# Script to download and configure Automate server as per the settings
# that are passed to it from the ARM template
#
# This is part of the Azure Managed App configuration
#

# Declare and initialise variables
AUTOMATE_SERVER_VERSION=""

AUTOMATE_DOWNLOAD_URL="https://s3-us-west-2.amazonaws.com/chef-automate-artifacts/current/latest/chef-automate-cli/chef-automate_linux_amd64.zip"

AUTOMATE_LICENCE=""

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
  url=$2
  install=$3

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
    if [ $install -eq 1 ]
    then
      echo -e "\tinstalling package"
      executeCmd "dpkg -i $download_file"
    fi
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

    -u|--url)
      AUTOMATE_DOWNLOAD_URL="$2"
    ;;

    -l|--licence)
      AUTOMATE_LICENCE="$2"
    ;;
  esac

  # move onto the next argument
  shift
done

echo "Checking Automate server"

# Download and unpack the Automate server
install automate-ctl $AUTOMATE_DOWNLOAD_URL 0
echo -e "\tunpacking"
download_filename=`basename $AUTOMATE_DOWNLOAD_URL`
cmd=$(printf 'gunzip -S .zip < %s > /usr/local/bin/chef-automate && chmod +x /usr/local/bin/chef-automate' $download_filename)
executeCmd "$cmd"

# Set kernel parameters for the session and permenantly
echo "Kernel Parameters"
cmd="sysctl -w vm.max_map_count=262144"
execute "$cmd"
cmd="sysctl -w vm.dirty_expire_centisecs=20000"
execute "$cmd"
cmd="echo vm.max_map_count=262144 > /etc/sysctl.d/50-chef-automate.conf"
execute "$cmd"
cmd="echo vm.dirty_expire_centisecs=20000 >> /etc/sysctl.d/50-chef-automate.conf"
execute "$cmd"

# Configure automate

echo "Configure Automate"
echo -e "\tinitialisation"
cmd="chef-automate init-config"
executeCmd "$cmd"

echo -e "\tdeploy"
cmd="chef-automate deploy config.toml"
executeCmd "$cmd"

echo -e "\tapplying licence"
cmd=$(printf 'chef-automate license apply %s' $AUTOMATE_LICENSE)
executeCmd "$cmd"


