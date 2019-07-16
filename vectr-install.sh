#!/bin/bash
# vectr-install.sh
# -----------------------------------------------------------------------------------------
# PLEASE READ:
# * Please store this permanently in a safe place, this may create other files and logs
# * that should be kept for as long as you plan on using VECTR
#
# This installation file may create the following:
# 1. .env configuration file in the same directory as this file that MUST be kept
# 2. 'download_temp' folder for downloading VECTR release
# 3. Named folder for extracting the contents of downloaded VECTR release
# 4. Possible installation logs
# -----------------------------------------------------------------------------------------

INSTALLER_VERSION=3

if [ "$(id -u)" != "0" ]; then
	echo "Exiting... setup must be run as sudo/root.  Please run sudo ./vectr-install.sh."
    SCRIPTEXIT
	exit 1
fi

source "vectr-shared-methods.sh"
SCRIPTENTRY

function showHelp ()
{
    echo "usage: $0 "
    echo "    -h | --help : Show Help"
    echo "    -i | --ignore : Ignore SRA github version check for installer "
    echo "                   (ignore will check VECTR version, specify a local release file if unwanted)"
    echo "    -e | --envfile <filepath> : Use existing ENV file "
    echo "    -r | --releasefile <filepath> : Use release file zip already on disk (EXPERIMENTAL, sets full offline mode)"
}

function getWebInstallerVersion ()
{
    FUNCENTRY
    local VECTR_INSTALLER_REGEX="(INSTALLER_VERSION\=[0-9]+)"
    local VECTR_INSTALLER_VER
    VECTR_INSTALLER_VER=$(curl -s -L https://raw.githubusercontent.com/SecurityRiskAdvisors/VECTR/master/vectr-install.sh | grep -oE "${VECTR_INSTALLER_REGEX}" | cut -d"=" -f2)

    INFO "Web VECTR installer version found: $VECTR_INSTALLER_VER"
    echo "$VECTR_INSTALLER_VER"
    FUNCEXIT
}

OFFLINE=false
IGNORE=false
ENV_FILE=""
RELEASE_FILE_SPECIFIED=""

# Get and parse CLI arguments
# https://stackoverflow.com/questions/14062895/bash-argument-case-for-args-in/14063511#14063511
while [[ $# -gt 0 ]] && ( [[ ."$1" = .--* ]] || [[ ."$1" = .-* ]] ) ;
do
    opt="$1";
    shift;
    case "$opt" in
        "--" ) break 2;;
        "--envfile" | "-e" )
            ENV_FILE="$1"; shift;;
        "--releasefile" | "-r" )
            RELEASE_FILE_SPECIFIED="$1"
            OFFLINE=true
            shift;;
        "--help" | "-h" )
            showHelp
            SCRIPTEXIT
            exit 0;;
        "--ignore" | "-i" )
            IGNORE=true;;
        *)
            echo "Invalid option: $opt"
            SCRIPTEXIT
            exit 1;;
   esac
done



echo "----------------------------------------"
echo "   SRA VECTR Installer (EXPERIMENTAL)   "
echo "----------------------------------------"
echo ""

# Installer version check
if [ "$OFFLINE" = false ] && [ "$IGNORE" = false ] ; then
    WEB_INSTALLER_VER="$(getWebInstallerVersion)"
    if [ -z "$WEB_INSTALLER_VER" ]; then
        echo "WARNING!!! Version check against https://github.com/SecurityRiskAdvisors/VECTR failed. Please manually check the repo to make sure your installation scripts are up to date. "
        read -p "Do you wish to continue? [y/N]: " VER_OUT_OF_DATE_CONTINUE
        VER_OUT_OF_DATE_CONTINUE=${VER_OUT_OF_DATE_CONTINUE:-"N"}
        if [ "$VER_OUT_OF_DATE_CONTINUE" != "y" ] && [ "$VER_OUT_OF_DATE_CONTINUE" != "Y" ]; then
            SCRIPTEXIT
            exit 0
        fi

        echo ""
    elif [ "$WEB_INSTALLER_VER" -gt "$INSTALLER_VERSION" ]; then
        echo "Installer out of date. Please download .sh scripts from https://github.com/SecurityRiskAdvisors/VECTR into your vectr download directory replacing existing ones."
        SCRIPTEXIT
        exit 1
    fi
fi


## CENTOS style first, then Ubuntu/Mint

RUN_USER="$(who am i | awk 'NR==1{print $1}')"
if [ -z "$RUN_USER" ]; then
    RUN_USER="$(who | awk 'NR==1{print $1}')"
fi

if [ "$RUN_USER" == "root" ]; then
    RUN_USER="vectr"
fi

RUN_USER_HOME="$(eval echo "~$RUN_USER")"

chown "$RUN_USER":"$RUN_USER" "$SCRIPT_LOG"

# check for env files in directory to warn user about in place upgrades
if [ -z "$ENV_FILE" ]; then
    ENV_FILES_IN_RUN_FOLDER="$(find . -name "*\.env" -type f)"
    if [ ! -z "$ENV_FILES_IN_RUN_FOLDER" ]; then
        echo "Possible VECTR configuration files found in run folder:"
        echo "$ENV_FILES_IN_RUN_FOLDER"
        echo ""
        echo "If you intend to upgrade VECTR in place please run 'sudo $0 -h' to see options for supplying an existing env file. "
        echo ""
        read -p " Do you wish to continue with a clean new install? (program will exit and no data will be written if Y not selected) [y/N]: " ENVS_FOUND_CONTINUE
        ENVS_FOUND_CONTINUE=${ENVS_FOUND_CONTINUE:-"N"}

        if [ "$ENVS_FOUND_CONTINUE" != "Y" ] && [ "$ENVS_FOUND_CONTINUE" != "y" ]; then
            SCRIPTEXIT
            exit 1
        fi
    fi
fi

echo ""
echo "It is strongly recommended you read the prompts and hit ENTER to select the default option for each.  "
echo "Configurability is provided for advanced self-supported installations ONLY."
echo ""

if [ -z "$ENV_FILE" ]; then
    read -p "Enter a name for this vectr configuration [sravectr]: " VECTR_CONFIG_NAME
    VECTR_CONFIG_NAME=${VECTR_CONFIG_NAME:-"sravectr"}
else
    VECTR_OS_USER=$(getEnvVar "VECTR_OS_USER" "$ENV_FILE")
    VECTR_DEPLOY_DIR=$(getEnvVar "VECTR_DEPLOY_DIR" "$ENV_FILE")
    VECTR_DEPLOY_DIR=${VECTR_DEPLOY_DIR%/}
    VECTR_BACKUP_DIR=$(getEnvVar "VECTR_BACKUP_DIR" "$ENV_FILE")
    VECTR_BACKUP_DIR=${VECTR_BACKUP_DIR%/}
    VECTR_DATA_DIR=$(getEnvVar "VECTR_DATA_DIR" "$ENV_FILE")
    VECTR_DATA_DIR=${VECTR_DATA_DIR%/}
    VECTR_HOSTNAME=$(getEnvVar "VECTR_HOSTNAME" "$ENV_FILE")
    VECTR_PORT=$(getEnvVar "VECTR_PORT" "$ENV_FILE")
    MONGO_PORT=$(getEnvVar "MONGO_PORT" "$ENV_FILE")
    VECTR_CRT_LOCATION=$(getEnvVar "VECTR_SSL_CRT" "$ENV_FILE")
    VECTR_KEY_LOCATION=$(getEnvVar "VECTR_SSL_KEY" "$ENV_FILE")
    VECTR_NETWORK_SUBNET=$(getEnvVar "VECTR_NETWORK_SUBNET" "$ENV_FILE")
    VECTR_NETWORK_NAME=$(getEnvVar "VECTR_NETWORK_NAME" "$ENV_FILE")

    VECTR_TOMCAT_CONTAINER_NAME=$(getEnvVar "VECTR_TOMCAT_CONTAINER_NAME" "$ENV_FILE")
    VECTR_MONGO_CONTAINER_NAME=$(getEnvVar "VECTR_MONGO_CONTAINER_NAME" "$ENV_FILE")

    # these two aren't really needed now, but for consistency...
    VECTR_CA_KEY=$(getEnvVar "VECTR_CA_KEY" "$ENV_FILE")
    VECTR_CA_CERT=$(getEnvVar "VECTR_CA_CERT" "$ENV_FILE")

    VECTR_DATA_KEY=$(getEnvVar "VECTR_DATA_KEY" "$ENV_FILE")

    VECTR_CERT_COUNTRY=$(getEnvVar "VECTR_CERT_COUNTRY" "$ENV_FILE")
    VECTR_CERT_STATE=$(getEnvVar "VECTR_CERT_STATE" "$ENV_FILE")
    VECTR_CERT_LOCALITY=$(getEnvVar "VECTR_CERT_LOCALITY" "$ENV_FILE")
    VECTR_CERT_ORG=$(getEnvVar "VECTR_CERT_ORG" "$ENV_FILE")
    VECTR_DOWNLOAD_TEMP=$(getEnvVar "VECTR_DOWNLOAD_TEMP" "$ENV_FILE")
    VECTR_DOWNLOAD_TEMP=${VECTR_DOWNLOAD_TEMP%/}
    VECTR_INSTALLED_VERSION=$(getEnvVar "VECTR_INSTALLED_VERSION" "$ENV_FILE")
    VECTR_RELEASE_URL=$(getEnvVar "VECTR_RELEASE_URL" "$ENV_FILE")

    TAXII_CERT_DIR=$(getEnvVar "TAXII_CERT_DIR" "$ENV_FILE")
    TAXII_CERT_DIR=${TAXII_CERT_DIR%/}
    CAS_DIR=$(getEnvVar "CAS_DIR" "$ENV_FILE")
    CAS_DIR=${CAS_DIR%/}

    VECTR_CONFIG_NAME="$(getFileNameNoExt $ENV_FILE)"
fi

echo ""

# ---------------------------------------------------------------------------------------
#  This works by only asking for config entries that aren't present in existing env files
#  That way, any updates will allow the installer to ask for only new data as needed
#
#  @TODO - replace blank values that can be empty with some sort of %%UNSET%% token so they can be intentionally left blank if needed?
# ---------------------------------------------------------------------------------------

if [ -z "$VECTR_OS_USER" ]; then
    read -p "Enter the VECTR OS user [$RUN_USER]: " VECTR_OS_USER
    VECTR_OS_USER=${VECTR_OS_USER:-"$RUN_USER"}
fi

if [ -z "$VECTR_DEPLOY_DIR" ]; then
    read -e -p "Enter the VECTR deploy directory (this will append /app for where the vectr web app deploys) [$RUN_USER_HOME/$VECTR_CONFIG_NAME]: " VECTR_DEPLOY_DIR
    VECTR_DEPLOY_DIR=${VECTR_DEPLOY_DIR:-"$RUN_USER_HOME/$VECTR_CONFIG_NAME"}
    VECTR_DEPLOY_DIR=${VECTR_DEPLOY_DIR%/}
fi

if [ -z "$VECTR_DATA_DIR" ]; then
    read -e -p "Enter the VECTR data directory [$VECTR_DEPLOY_DIR/data]: " VECTR_DATA_DIR
    VECTR_DATA_DIR=${VECTR_DATA_DIR:-"$VECTR_DEPLOY_DIR/data"}
    VECTR_DATA_DIR=${VECTR_DATA_DIR%/}
fi

if [ -z "$VECTR_BACKUP_DIR" ]; then
    VECTR_BACKUP_DIR=${VECTR_BACKUP_DIR:-"${VECTR_DEPLOY_DIR}/backup"}
    VECTR_BACKUP_DIR=${VECTR_BACKUP_DIR%/}
fi

if [ -z "$VECTR_HOSTNAME" ]; then
    read -p "VECTR hostname [$VECTR_CONFIG_NAME.internal]: " VECTR_HOSTNAME
    VECTR_HOSTNAME=${VECTR_HOSTNAME:-"$VECTR_CONFIG_NAME.internal"}
fi

if [ -z "$VECTR_PORT" ]; then
    read -p "VECTR port [8081]: " VECTR_PORT
    VECTR_PORT=${VECTR_PORT:-"8081"}
fi

if [ -z "$VECTR_CRT_LOCATION" ] || [ -z "$VECTR_KEY_LOCATION" ]; then
    echo ""
    echo "  WARNING!! SSL Cert creation can vary between OpenSSL versions. If you do not specify an existing key, a self-signed cert will generate. "
    echo ""

    read -p "VECTR SSL certificate existing crt file (Please leave blank if none. Ex: $VECTR_DEPLOY_DIR/app/config/ssl.crt) []: " VECTR_CRT_LOCATION
    read -p "VECTR SSL certificate existing key file (Please leave blank if none. Ex: $VECTR_DEPLOY_DIR/app/config/ssl.key) []: " VECTR_KEY_LOCATION
fi


if [ -z "$ENV_FILE" ]; then
    read -p "Enter advanced configuration options? [y/N]: " ADVANCED_CONFIG
    ADVANCED_CONFIG=${ADVANCED_CONFIG:-"N"}

    if [ "$ADVANCED_CONFIG" == "Y" ] || [ "$ADVANCED_CONFIG" == "y" ]; then
        read -p "VECTR docker network subnet [10.0.27.0/24]: " VECTR_NETWORK_SUBNET
        VECTR_NETWORK_SUBNET=${VECTR_NETWORK_SUBNET:-"10.0.27.0/24"}

        read -p "VECTR docker network bridge name [${VECTR_CONFIG_NAME}_bridge]: " VECTR_NETWORK_NAME
        VECTR_NETWORK_NAME=${VECTR_NETWORK_NAME:-"${VECTR_CONFIG_NAME}_bridge"}

        read -p "VECTR mongo port [27018]: " MONGO_PORT
        MONGO_PORT=${MONGO_PORT:-"27018"}

        read -p "Use existing CA cert file? [y/N]: " USE_EXISTING_CA
        USE_EXISTING_CA=${USE_EXISTING_CA:-"N"}

        if [ "$USE_EXISTING_CA" == "Y" ] || [ "$USE_EXISTING_CA" == "y" ]; then
            read -e -p "Existing CA cert dir [${VECTR_DEPLOY_DIR}/taxii/certs]: " TAXII_CERT_DIR
            TAXII_CERT_DIR=${TAXII_CERT_DIR:-"${VECTR_DEPLOY_DIR}/taxii/certs"}
            TAXII_CERT_DIR=${TAXII_CERT_DIR%/}

            read -p "Existing CA cert file (must be in pem format) [vectrRootCA.pem]: " VECTR_CA_CERT
            VECTR_CA_CERT=${VECTR_CA_CERT:-"vectrRootCA.pem"}

            read -p "Existing CA key file (must be in key format) [vectrRootCA.key]: " VECTR_CA_KEY
            VECTR_CA_KEY=${VECTR_CA_KEY:-"vectrRootCA.key"}

            read -s -p "Existing CA password []: " VECTR_CA_PASS
        fi
    fi
fi

# advanced config defaults

if [ -z "$VECTR_NETWORK_SUBNET" ]; then
    VECTR_NETWORK_SUBNET="10.0.27.0/24"
fi

if [ -z "$MONGO_PORT" ]; then
    MONGO_PORT="27018"
fi

if [ -z "$VECTR_NETWORK_NAME" ]; then
    VECTR_NETWORK_NAME="vectr_bridge"
fi

# set normal defaults

CLEANED_CONFIG_NAME=${VECTR_CONFIG_NAME//[^a-zA-Z0-9]/_}
if [ -z "$VECTR_TOMCAT_CONTAINER_NAME" ]; then
    VECTR_TOMCAT_CONTAINER_NAME="${CLEANED_CONFIG_NAME}_tomcat"
fi

if [ -z "$VECTR_MONGO_CONTAINER_NAME" ]; then
    VECTR_MONGO_CONTAINER_NAME="${CLEANED_CONFIG_NAME}_mongo"
fi

if [ -z "$VECTR_CERT_COUNTRY" ]; then
    VECTR_CERT_COUNTRY="US"
fi

if [ -z "$VECTR_CERT_STATE" ]; then
    VECTR_CERT_STATE="PA"
fi

if [ -z "$VECTR_CERT_LOCALITY" ]; then
    VECTR_CERT_LOCALITY="Phila"
fi

if [ -z "$VECTR_CERT_ORG" ]; then
    VECTR_CERT_ORG="SRA"
fi

if [ -z "$VECTR_DOWNLOAD_TEMP" ]; then
    VECTR_DOWNLOAD_TEMP="download_temp"
    VECTR_DOWNLOAD_TEMP=${VECTR_DOWNLOAD_TEMP%/}
fi

# unnecessary?
if [ -z "$VECTR_INSTALLED_VERSION" ]; then
    VECTR_INSTALLED_VERSION=""
fi

if [ -z "$VECTR_RELEASE_URL" ]; then
    VECTR_RELEASE_URL="https://github.com/SecurityRiskAdvisors/VECTR/releases/latest"
fi

if [ -z "$TAXII_CERT_DIR" ]; then
    TAXII_CERT_DIR="$VECTR_DEPLOY_DIR/taxii/certs"
    TAXII_CERT_DIR=${TAXII_CERT_DIR%/}
fi

if [ -z "$VECTR_CA_CERT" ]; then
    VECTR_CA_CERT="vectrRootCA.pem"
fi

if [ -z "$VECTR_CA_KEY" ]; then
    VECTR_CA_KEY="vectrRootCA.key"
fi

if [ -z "$CAS_DIR" ]; then
    CAS_DIR="$VECTR_DEPLOY_DIR/app/cas"
    CAS_DIR=${CAS_DIR%/}
fi

if [ -z "$VECTR_NETWORK_NAME" ]; then
    VECTR_NETWORK_NAME="vectr_bridge"
fi

if [ -z "$VECTR_DATA_KEY" ]; then
    VECTR_DATA_KEY=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 24 | head -n 1)
fi

echo ""
echo "Configuration data: "
echo "  VECTR configuration name: $VECTR_CONFIG_NAME"
echo "  VECTR OS user: $VECTR_OS_USER"
echo "  VECTR deploy directory: $VECTR_DEPLOY_DIR"
echo "  VECTR data directory: $VECTR_DATA_DIR"
echo "  VECTR hostname: $VECTR_HOSTNAME"
echo "  VECTR port: $VECTR_PORT"
echo "  VECTR docker bridge subnet: $VECTR_NETWORK_SUBNET"
echo "  VECTR docker internal container names: $VECTR_TOMCAT_CONTAINER_NAME and $VECTR_MONGO_CONTAINER_NAME"
echo "  VECTR Mongo DB port: $MONGO_PORT"
echo "  CAS directory: $CAS_DIR"

if [ -z "$VECTR_CRT_LOCATION" ] && [ -z "$VECTR_KEY_LOCATION" ]; then
    echo "  VECTR OpenSSL self-signed cert will be created."
else
    echo "  VECTR cert and key: $VECTR_CRT_LOCATION and $VECTR_KEY_LOCATION"
fi

echo ""
read -p " Do you wish to continue with the install? (program will exit and no data will be written if Y not selected) [Y/n]: " VECTR_WRITE_DATA
VECTR_WRITE_DATA=${VECTR_WRITE_DATA:-"Y"}

VECTR_CONFIG_FILE_NAME="$VECTR_CONFIG_NAME.env"

if [ "$VECTR_WRITE_DATA" == "Y" ] || [ "$VECTR_WRITE_DATA" == "y" ]; then
    echo " Writing data to $VECTR_CONFIG_FILE_NAME config file..."
else
    SCRIPTEXIT
    exit 1
fi


# Write out the env config...
# cat <EOF > "$VECTR_CONFIG_FILE_NAME"
# switch /dev/null to STDOUT for -v flag
tee "$VECTR_CONFIG_FILE_NAME" > /dev/null <<EOF

# ----------------------------------------------------------------------------------
# ---- You can change these vars prior to installation, don't change after ---------
# ----------------------------------------------------------------------------------

# ---- Owner of downloaded files and VECTR's deploy directory
VECTR_OS_USER=$VECTR_OS_USER

VECTR_HOSTNAME=$VECTR_HOSTNAME
VECTR_PORT=$VECTR_PORT
MONGO_PORT=$MONGO_PORT

# ---- SSL Cert for VECTR, this will be populated later if you do not specify now
VECTR_SSL_CRT=$VECTR_CRT_LOCATION
VECTR_SSL_KEY=$VECTR_KEY_LOCATION


# ----------------------------------------------------------------------------------
# ---- Only change these vars if you absolutely know what you're doing -------------
# ----------------------------------------------------------------------------------

VECTR_DEPLOY_DIR=$VECTR_DEPLOY_DIR
VECTR_DATA_DIR=$VECTR_DATA_DIR
VECTR_BACKUP_DIR=$VECTR_BACKUP_DIR

TAXII_CERT_DIR=$TAXII_CERT_DIR
VECTR_CA_CERT=$VECTR_CA_CERT
VECTR_CA_KEY=$VECTR_CA_KEY

VECTR_DATA_KEY=$VECTR_DATA_KEY

CAS_DIR=$CAS_DIR

VECTR_CERT_COUNTRY=$VECTR_CERT_COUNTRY
VECTR_CERT_STATE=$VECTR_CERT_STATE
VECTR_CERT_LOCALITY=$VECTR_CERT_LOCALITY
VECTR_CERT_ORG=$VECTR_CERT_ORG

VECTR_NETWORK_SUBNET=$VECTR_NETWORK_SUBNET
VECTR_NETWORK_NAME=$VECTR_NETWORK_NAME

VECTR_TOMCAT_CONTAINER_NAME=$VECTR_TOMCAT_CONTAINER_NAME
VECTR_MONGO_CONTAINER_NAME=$VECTR_MONGO_CONTAINER_NAME

# ----------------------------------------------------------------------------------
# ---- Don't manually change these variables.  If you do, it could break everything 
# ----------------------------------------------------------------------------------

VECTR_RELEASE_URL=$VECTR_RELEASE_URL
VECTR_DOWNLOAD_TEMP=$VECTR_DOWNLOAD_TEMP
VECTR_INSTALLER_VER=$INSTALLER_VERSION
VECTR_INSTALLED_VERSION=$VECTR_INSTALLED_VERSION

EOF

echo " Deploying VECTR installation according to configuration values selected ..."
echo ""

# this could get complex with more options, try to find a way to avoid eval statements
# can we switch this to a subshell call? VAR=$(vectr-deploy.sh blah)
if [ ! -z "$RELEASE_FILE_SPECIFIED" ]; then
    if [ -z "$VECTR_CA_PASS" ]; then
        ./vectr-deploy.sh -e "$VECTR_CONFIG_FILE_NAME" -r "$RELEASE_FILE_SPECIFIED"
    else
        ./vectr-deploy.sh -e "$VECTR_CONFIG_FILE_NAME" -r "$RELEASE_FILE_SPECIFIED" -p "$VECTR_CA_PASS"
    fi
else
    if [ -z "$VECTR_CA_PASS" ]; then
        ./vectr-deploy.sh -e "$VECTR_CONFIG_FILE_NAME"
    else
        ./vectr-deploy.sh -e "$VECTR_CONFIG_FILE_NAME"  -p "$VECTR_CA_PASS"
    fi
fi

SCRIPTEXIT
exit 0
