#!/usr/bin/env bash

#
# Script to download and configure Chef server as per the settings
# that are passed to it from the ARM template
#
# This is part of the Azure Managed App configuration
#

# Declare and initialise variables
CHEF_SERVER_VERSION=""
CHEF_USER_NAME=""
CHEF_USER_FULLNAME=""
CHEF_USER_EMAILADDRESS=""
CHEF_USER_PASSWORD=""
CHEF_ORGNAME=""
CHEF_ORG_DESCRIPTION=""

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
    -o|--org)
      CHEF_ORGNAME="$2"
    ;;

    # Get the org description
    -d|--orgdescription)
      CHEF_ORG_DESCRIPTION="$2"
    ;;
  esac

  # move onto the next argument
  shift
done

echo "Checking Chef server"

if [ "X$CHEF_SERVER_VERSION" != "X" ]
then
  # Download and installed Chef server
  # Determine the download url taking into account the version
  download_url=$(printf 'https://packages.chef.io/files/stable/chef-server/%s/ubuntu/16.04/chef-server-core_%s-1_amd64.deb' $CHEF_SERVER_VERSION $CHEF_SERVER_VERSION)
  install chef-server-ctl $download_url
else
  echo -e "Not install Chef server as not version specified. Use -v and rerun the command if this is required"
fi

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
  cmd=$(printf 'chef-server-ctl user-create %s "%s" %s "%s" --filename %s.pem' \
        $CHEF_USER_NAME \
        $CHEF_USER_FULLNAME \
        $CHEF_USER_EMAILADDRESS \
        $CHEF_USER_PASSWORD \
        $CHEF_USER_NAME)
  executeCmd $cmd

  # Create the named organisation
  echo -e "\tcreate organisation: ${CHEF_ORGNAME}"
  cmd=$(printf 'chef-server-ctl org-create %s "%s" --association-user %s --filename %s-validator.pem' \
        $CHEF_ORGNAME \
        $CHEF_ORG_DESCRIPTION \
        $CHEF_USER_NAME \
        $CHEF_ORGNAME)
  executeCmd $cmd

  # Reconfigure the server after creating user and organisation
  echo -e "\treconfigure"
  executeCmd "chef-server-ctl reconfigure"  
fi