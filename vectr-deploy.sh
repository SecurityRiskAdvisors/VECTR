#!/bin/bash
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

DEPLOY_SCRIPT_VER=2
VECTR_MIN_VER=5.0.0

if [ "$(id -u)" != "0" ]; then
	echo "Exiting... setup must be run as sudo/root.  Please run sudo ./$0."
    SCRIPTEXIT
	exit 1
fi

function showHelp ()
{
    echo "usage: $0 "
    echo "    -h | --help : Show Help"
    echo "    -e | --envfile <filepath> : Use existing ENV file "
    echo "    -r | --releasefile <filepath> : Use release file zip already on disk (EXPERIMENTAL, sets full offline mode)"
    echo "    -p | --password <password> : Supply a password to an existing cert authority provided in the env file"
}

OFFLINE=false
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
         "--password" | "-p" )
            CA_PASS="$1"; shift;;
        "--help" | "-h" )
            showHelp
            SCRIPTEXIT
            exit 0;;
        *)
            echo "Invalid option: $opt"
            SCRIPTEXIT
            exit 1;;
   esac
done

source "vectr-shared-methods.sh"
SCRIPTENTRY

RUNNING_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

ENV_FILE_NAME="$(getFileNameNoExt "$ENV_FILE")"

ENV_VECTR_DEPLOY_DIR=$(getEnvVar "VECTR_DEPLOY_DIR" "$ENV_FILE")

VECTR_APP_DIR="$ENV_VECTR_DEPLOY_DIR/app"

ENV_VECTR_DATA_DIR=$(getEnvVar "VECTR_DATA_DIR" "$ENV_FILE")
ENV_VECTR_OS_USER=$(getEnvVar "VECTR_OS_USER" "$ENV_FILE")

ENV_VECTR_RELEASE_URL=$(getEnvVar "VECTR_RELEASE_URL" "$ENV_FILE")
ENV_VECTR_DOWNLOAD_TEMP=$(getEnvVar "VECTR_DOWNLOAD_TEMP" "$ENV_FILE")
ENV_VECTR_INSTALLED_VERSION=$(getEnvVar "VECTR_INSTALLED_VERSION" "$ENV_FILE")

ENV_VECTR_CERT_COUNTRY=$(getEnvVar "VECTR_CERT_COUNTRY" "$ENV_FILE")
ENV_VECTR_CERT_STATE=$(getEnvVar "VECTR_CERT_STATE" "$ENV_FILE")
ENV_VECTR_CERT_LOCALITY=$(getEnvVar "VECTR_CERT_LOCALITY" "$ENV_FILE")
ENV_VECTR_CERT_ORG=$(getEnvVar "VECTR_CERT_ORG" "$ENV_FILE")

ENV_VECTR_HOSTNAME=$(getEnvVar "VECTR_HOSTNAME" "$ENV_FILE")
ENV_VECTR_PORT=$(getEnvVar "VECTR_PORT" "$ENV_FILE")
ENV_MONGO_PORT=$(getEnvVar "MONGO_PORT" "$ENV_FILE")

ENV_TAXII_CERT_DIR=$(getEnvVar "TAXII_CERT_DIR" "$ENV_FILE")
ENV_CAS_DIR=$(getEnvVar "CAS_DIR" "$ENV_FILE")

ENV_VECTR_NETWORK_SUBNET=$(getEnvVar "VECTR_NETWORK_SUBNET" "$ENV_FILE")
ENV_VECTR_NETWORK_NAME=$(getEnvVar "VECTR_NETWORK_NAME" "$ENV_FILE")

ENV_VECTR_TOMCAT_CONTAINER_NAME=$(getEnvVar "VECTR_TOMCAT_CONTAINER_NAME" "$ENV_FILE")
ENV_VECTR_MONGO_CONTAINER_NAME=$(getEnvVar "VECTR_MONGO_CONTAINER_NAME" "$ENV_FILE")

VECTR_SSL_CRT_ENV_KEYNAME="VECTR_SSL_CRT"
VECTR_SSL_KEY_ENV_KEYNAME="VECTR_SSL_KEY"
ENV_VECTR_SSL_CRT=$(getEnvVar "$VECTR_SSL_CRT_ENV_KEYNAME" "$ENV_FILE")
ENV_VECTR_SSL_KEY=$(getEnvVar "$VECTR_SSL_KEY_ENV_KEYNAME" "$ENV_FILE")

ENV_VECTR_CA_CERT=$(getEnvVar "VECTR_CA_CERT" "$ENV_FILE")
ENV_VECTR_CA_KEY=$(getEnvVar "VECTR_CA_KEY" "$ENV_FILE")

ENV_VECTR_DATA_KEY=$(getEnvVar "VECTR_DATA_KEY" "$ENV_FILE")

VECTR_ENV_INSTALLED_VER_KEYNAME="VECTR_INSTALLED_VERSION"

AUTH_PROPERTIES_EXT_PORT_KEYNAME="vectr.server.port.external"
AUTH_PROPERTIES_HOSTNAME_KEYNAME="vectr.server.hostname"
AUTH_PROPERTIES_INSTALLTYPE_KEYNAME="cas.server.installType"
AUTH_PROPERTIES_CAS_URL_KEYNAME="cas.server.url"

VECTR_PROPERTIES_DATA_KEY_KEYNAME="dataKey"

CAS_URL="https://${ENV_VECTR_HOSTNAME}:8443/cas"


DEPLOY_DEFAULT_NETWORK_SUBNET="10.0.27.0/24"
DEPLOY_DEFAULT_NETWORK_NAME="vectr_bridge"
DEPLOY_DEFAULT_TOMCAT_CONTAINER_NAME="vectr_tomcat_sandbox1"
DEPLOY_DEFAULT_MONGO_CONTAINER_NAME="vectr_mongo_sandbox1"
DEPLOY_DEFAULT_DEPLOY_DIR="/opt/vectr"
DEPLOY_COMPOSE_YAML_FILE_PATH="docker-compose.yml"
DEPLOY_SECONDARY_YAML_FILE_PATH="devSsl.yml"
DEPLOY_DEFAULT_DATA_DIR="/var/data/sandbox1"
DEPLOY_DEFAULT_PORTS="\"8081:8443\""
DEPLOY_DEFAULT_MONGO_PORTS="\"27018:27017\""
DEPLOY_DEFAULT_TAXII_CERT_DIR="/opt/taxii/certs/"

TOMCAT_CONTAINER_TOOLS_DIR="/opt/vectr/tools"

DEPLOY_DEFAULT_CAS_FOLDER="${VECTR_APP_DIR}/cas"

CAS_CONFIG_SERVER_NAME_KEYNAME="cas.server.name"
CAS_CONFIG_SERVER_PREFIX_KEYNAME="cas.server.prefix"

CAS_CONFIG_SERVER_NAME_DEFAULT="https://localhost:8443"
CAS_CONFIG_SERVER_PREFIX_DEFAULT="https://localhost:8443/cas"

CAS_SERVICE_FILE_NAME="vectr-$ENV_VECTR_PORT.json"
CAS_CONFIG_FILE_NAME="cas.properties"

function checkContinueDeployment ()
{
    if [ "$1" -ne 1 ]; then
        # stop deployment, throw error
        echo " ERROR: VECTR Deployment can not continue. Please correct any issues marked above or check installation logs."
        SCRIPTEXIT
        exit 1
    fi
}

function deployVectr ()
{
    #local JAVA_OK=$(javaOk)
    #printStatusMark "$JAVA_OK"
    #printf " Java version 1.8 or greater\n"

    # -------------------------------------------------------------------------------------------
    # Step 1: Check the docker version to make sure it supports our compose features
    # -------------------------------------------------------------------------------------------
    local DOCKER_OK=$(dockerVersionOk)
    printStatusMark "$DOCKER_OK"
    printf " Docker ce version 17.03 or Docker engine 1.10 or greater\n"
    checkContinueDeployment "$DOCKER_OK"

    # -------------------------------------------------------------------------------------------
    # Step 2: Make sure curl is installed (really, ubuntu?)
    # -------------------------------------------------------------------------------------------
    if [ "$OFFLINE" != true ]; then
        local CURL_OK=$(curlInstalled)
        printStatusMark "$CURL_OK"
        printf " Curl is installed\n"
        checkContinueDeployment "$CURL_OK"
    fi

    # -------------------------------------------------------------------------------------------
    # Step 3: Make sure the VECTR user specified actually exists on the operating system
    # -------------------------------------------------------------------------------------------
    local USER_EXISTS=$(userExists "$ENV_VECTR_OS_USER")
    printStatusMark "$USER_EXISTS"
    printf " VECTR OS user exists\n"

    checkContinueDeployment "$USER_EXISTS"

    # -------------------------------------------------------------------------------------------
    # Step 4: Check for existing VECTR docker containers and stop them if present
    # -------------------------------------------------------------------------------------------

    local VECTR_TOMCAT_CONTAINER_EXISTS=$(dockerContainerExists "$ENV_VECTR_TOMCAT_CONTAINER_NAME")
    local VECTR_MONGO_CONTAINER_EXISTS=$(dockerContainerExists "$ENV_VECTR_MONGO_CONTAINER_NAME")

    local DOCKER_STOPPED
    if [[ "$VECTR_TOMCAT_CONTAINER_EXISTS" -eq 1 ]] && [[ "$VECTR_MONGO_CONTAINER_EXISTS" -eq 1 ]]; then
        local STOP_TOMCAT=$(docker stop "$ENV_VECTR_TOMCAT_CONTAINER_NAME")
        local STOP_MONGO=$(docker stop "$ENV_VECTR_MONGO_CONTAINER_NAME")
        DOCKER_STOPPED=1
        printStatusMark "$DOCKER_STOPPED"
        printf " Stopped existing VECTR docker containers for this configuration\n"
    else
        printStatusMark 1
        DOCKER_STOPPED=0
        printf " No existing VECTR docker containers for this config found\n"
    fi

    # -------------------------------------------------------------------------------------------
    # Step 5: Verify that VECTR deployment directory exists and if not, make a new directory
    # -------------------------------------------------------------------------------------------
    local VECTR_DEPLOY_DIR_EXISTS=$(dirExists "$ENV_VECTR_DEPLOY_DIR")
    if [ "$VECTR_DEPLOY_DIR_EXISTS" -ne 1 ]
    then
        local VECTR_MAKE_DEPLOY_DIR=$(makeDir "$ENV_VECTR_DEPLOY_DIR")
        printStatusMark "$VECTR_MAKE_DEPLOY_DIR"
        printf " Made VECTR deploy directory\n"

        local VECTR_DEPLOY_DIR_EXISTS=$(dirExists "$ENV_VECTR_DEPLOY_DIR")
        printStatusMark "$VECTR_DEPLOY_DIR_EXISTS"
        printf " VECTR deploy directory exists\n"
    else
        printStatusMark "$VECTR_DEPLOY_DIR_EXISTS"
        printf " VECTR deploy directory exists\n"
    fi
    checkContinueDeployment "$VECTR_DEPLOY_DIR_EXISTS"



    # -------------------------------------------------------------------------------------------
    # Step 6: Check VECTR download temp directory exists and create if not
    # -------------------------------------------------------------------------------------------
    local VECTR_DOWNLOAD_TEMP_EXISTS=$(dirExists "$ENV_VECTR_DOWNLOAD_TEMP")
    if [ "$VECTR_DOWNLOAD_TEMP_EXISTS" -ne 1 ]
    then
        local VECTR_MAKE_DOWNLOAD_TEMP_DIR=$(makeDir "$ENV_VECTR_DOWNLOAD_TEMP")
        printStatusMark "$VECTR_MAKE_DOWNLOAD_TEMP_DIR"
        printf " Made VECTR download temp dir\n"

        local VECTR_DOWNLOAD_TEMP_EXISTS=$(dirExists "$ENV_VECTR_DOWNLOAD_TEMP")
        printStatusMark "$VECTR_DOWNLOAD_TEMP_EXISTS"
        printf " VECTR download temp directory exists\n"
    else
        printStatusMark "$VECTR_DOWNLOAD_TEMP_EXISTS"
        printf " VECTR download temp directory exists\n"
    fi
    checkContinueDeployment "$VECTR_DEPLOY_DIR_EXISTS"

    # -------------------------------------------------------------------------------------------
    # Step 7: Check VECTR download temp directory permissions for VECTR user account and if they're bad attempt to fix and recheck
    # -------------------------------------------------------------------------------------------
    local VECTR_DOWNLOAD_TEMP_DIR_PERMS_CHECK=$(dirPermsCheck "$ENV_VECTR_OS_USER" "$ENV_VECTR_DOWNLOAD_TEMP")
    if [ "$VECTR_DOWNLOAD_TEMP_DIR_PERMS_CHECK" -ne 1 ]
    then
        local VECTR_FIX_DOWNLOAD_TEMP_DIR_PERMS=$(fixDirPerms "$ENV_VECTR_OS_USER" "$ENV_VECTR_DOWNLOAD_TEMP")
        printStatusMark 1
        printf " Fix VECTR download temp directory permissions\n"

        local VECTR_DOWNLOAD_TEMP_DIR_PERMS_CHECK=$(dirPermsCheck "$ENV_VECTR_OS_USER" "$ENV_VECTR_DOWNLOAD_TEMP")
        printStatusMark "$VECTR_DOWNLOAD_TEMP_DIR_PERMS_CHECK"
        printf " VECTR download temp directory permissions are OK\n"
    else
        printStatusMark "$VECTR_DOWNLOAD_TEMP_DIR_PERMS_CHECK"
        printf " VECTR download temp permissions are OK\n"
    fi
    checkContinueDeployment "$VECTR_DOWNLOAD_TEMP_DIR_PERMS_CHECK"

    # -------------------------------------------------------------------------------------------
    # Step 8: Get VECTR Release URL for pulling down latest VECTR Release Download
    # -------------------------------------------------------------------------------------------
    if [ "$OFFLINE" != true ]; then
        local VECTR_RELEASE_FILE_URL=$(getLatestVectrReleaseFileUrl "$ENV_VECTR_RELEASE_URL")
        if [ -z "$VECTR_RELEASE_FILE_URL" ]; then
            local VECTR_RELEASE_FILE_URL_PARSE_SUCCESS=0
        else
            local VECTR_RELEASE_FILE_URL_PARSE_SUCCESS=1
        fi
        printStatusMark "$VECTR_RELEASE_FILE_URL_PARSE_SUCCESS"
        printf " VECTR release file URL parsed for download\n"
    else
        local VECTR_RELEASE_FILE_URL="$RELEASE_FILE_SPECIFIED"
    fi

    # -------------------------------------------------------------------------------------------
    # Step 9: Get VECTR Release Zip file name for comparison and storing in ENV file if successfully deployed
    # -------------------------------------------------------------------------------------------

    local VECTR_RELEASE_ZIP_NAME=$(getLatestVectrReleaseZipFile $VECTR_RELEASE_FILE_URL)
    if [ -z "$VECTR_RELEASE_ZIP_NAME" ]; then
        local VECTR_RELEASE_ZIP_NAME_PARSE_SUCCESS=0
    else
        local VECTR_RELEASE_ZIP_NAME_PARSE_SUCCESS=1
    fi
    printStatusMark "$VECTR_RELEASE_ZIP_NAME_PARSE_SUCCESS"
    printf " VECTR release zip name found for comparison\n"

    # -------------------------------------------------------------------------------------------
    # Step 10: Check to see if a VECTR vesrion was previously installed or downloaded, download if doesn't exist or not up to date
    # -------------------------------------------------------------------------------------------
    # @TODO - This logic can be simplified at a later date


    local VECTR_DOWNLOADED_VER_OK=0
    local VECTR_DOWNLOADED_NEW=0

    if [ "$OFFLINE" != true ]; then
        if [ ! -z "$ENV_VECTR_INSTALLED_VERSION" ]; then
            if [ $VECTR_RELEASE_ZIP_NAME != "$ENV_VECTR_INSTALLED_VERSION" ]; then
                # This is the upgrade code path
                downloadLatestVectrRelease $ENV_VECTR_OS_USER $VECTR_RELEASE_FILE_URL $ENV_VECTR_DOWNLOAD_TEMP $RUNNING_DIR

                local VECTR_RELEASE_FILE_DOWNLOADED=$(fileExists "$ENV_VECTR_DOWNLOAD_TEMP/$VECTR_RELEASE_ZIP_NAME" )
                printStatusMark "$VECTR_RELEASE_FILE_DOWNLOADED"
                printf " VECTR release zip downloaded to temporary download dir for upgrade\n"
                local VECTR_DOWNLOADED_VER_OK="$VECTR_RELEASE_FILE_DOWNLOADED"
                local VECTR_DOWNLOADED_NEW="$VECTR_RELEASE_FILE_DOWNLOADED"

            else
                # current version of zip exists, continue
                printStatusMark 1
                printf " VECTR release in temporary download dir is current\n"
                local VECTR_DOWNLOADED_VER_OK=1
            fi
        else
            # new installation code path

            local VECTR_RELEASE_FILE_EXISTS=$(fileExists "$ENV_VECTR_DOWNLOAD_TEMP/$VECTR_RELEASE_ZIP_NAME")
            if [ "$VECTR_RELEASE_FILE_EXISTS" -ne 1 ]
            then
                downloadLatestVectrRelease $ENV_VECTR_OS_USER $VECTR_RELEASE_FILE_URL $ENV_VECTR_DOWNLOAD_TEMP $RUNNING_DIR

                local VECTR_RELEASE_FILE_DOWNLOADED=$(fileExists "$ENV_VECTR_DOWNLOAD_TEMP/$VECTR_RELEASE_ZIP_NAME")
                printStatusMark "$VECTR_RELEASE_FILE_DOWNLOADED"
                printf " VECTR release zip downloaded to temporary download dir for new installation\n"
                local VECTR_DOWNLOADED_VER_OK="$VECTR_RELEASE_FILE_DOWNLOADED"
                local VECTR_DOWNLOADED_NEW="$VECTR_RELEASE_FILE_DOWNLOADED"
            else
                printStatusMark 1
                printf " VECTR release zip already exists in temp download dir despite not being installed\n"
                local VECTR_DOWNLOADED_VER_OK=1
            fi
        fi
        checkContinueDeployment "$VECTR_DOWNLOADED_VER_OK"
    else
        # release file is specified
        if [ ! -z "$ENV_VECTR_INSTALLED_VERSION" ]; then
            if [ $VECTR_RELEASE_ZIP_NAME != "$ENV_VECTR_INSTALLED_VERSION" ]; then
                local VECTR_RELEASE_FILE_DOWNLOADED=$(fileExists "$VECTR_RELEASE_FILE_URL" )
                printStatusMark "$VECTR_RELEASE_FILE_DOWNLOADED"
                printf " VECTR release zip exists at install location\n"
                local VECTR_DOWNLOADED_VER_OK="$VECTR_RELEASE_FILE_DOWNLOADED"
                local VECTR_DOWNLOADED_NEW="$VECTR_RELEASE_FILE_DOWNLOADED"

            else
                # current version of zip exists, continue
                printStatusMark 1
                printf " VECTR release in specified dir is current\n"
                local VECTR_DOWNLOADED_VER_OK=1
            fi
        fi
    fi

    # -------------------------------------------------------------------------------------------
    # Step 11: Extract VECTR zip file if extracted folder doesn't exist
    # -------------------------------------------------------------------------------------------
    local VECTR_RELEASE_FOLDER_NAME=${VECTR_RELEASE_ZIP_NAME%.*}

    local VECTR_EXTRACT_DIR_EXISTS=$(dirExists "$ENV_VECTR_DOWNLOAD_TEMP/$VECTR_RELEASE_FOLDER_NAME")
    if [ "$VECTR_EXTRACT_DIR_EXISTS" -ne 1 ]
    then
        local EXTRACT_FROM_LOCATION
        if [ "$OFFLINE" != true ]; then
            EXTRACT_FROM_LOCATION="$ENV_VECTR_DOWNLOAD_TEMP/$VECTR_RELEASE_ZIP_NAME"
        else
            EXTRACT_FROM_LOCATION="$VECTR_RELEASE_FILE_URL"
        fi
        local VECTR_RELEASE_EXTRACT=$(extractVectrRelease "$ENV_VECTR_OS_USER" "$EXTRACT_FROM_LOCATION" "$ENV_VECTR_DOWNLOAD_TEMP/$VECTR_RELEASE_FOLDER_NAME")

        local VECTR_EXTRACT_DIR_EXISTS=$(dirExists "$ENV_VECTR_DOWNLOAD_TEMP/$VECTR_RELEASE_FOLDER_NAME")
        printStatusMark "$VECTR_EXTRACT_DIR_EXISTS"
        printf " Extracted VECTR downloaded release to $ENV_VECTR_DOWNLOAD_TEMP/$VECTR_RELEASE_FOLDER_NAME\n"

    else
        printStatusMark "$VECTR_EXTRACT_DIR_EXISTS"
        printf " VECTR extracted release folder exists\n"
    fi
    checkContinueDeployment "$VECTR_EXTRACT_DIR_EXISTS"


    # -------------------------------------------------------------------------------------------
    # Step 12: Verify extracted VECTR release files
    # -------------------------------------------------------------------------------------------
    local VECTR_VERIFY_RELEASE=$(verifyVectrReleaseHelper "$ENV_VECTR_DOWNLOAD_TEMP/$VECTR_RELEASE_FOLDER_NAME")
    printStatusMark "$VECTR_VERIFY_RELEASE"
    printf " Verify extracted VECTR release\n"

    checkContinueDeployment "$VECTR_VERIFY_RELEASE"


    # -------------------------------------------------------------------------------------------
    # Step 13: Copy extracted VECTR release files to VECTR deploy directory if it's newly downloaded or nothing exists in there
    # -------------------------------------------------------------------------------------------
    local VECTR_VERIFY_DEPLOY=$(verifyVectrReleaseHelper "$VECTR_APP_DIR")

    if [ "$VECTR_DOWNLOADED_NEW" -eq 1 ] || [ "$VECTR_VERIFY_DEPLOY" -ne 1 ]; then
        # if at least config folder exists let's backup
        VECTR_RELEASE_EXISTS=$(dirExists "$VECTR_APP_DIR/config")
        if [ $VECTR_RELEASE_EXISTS -eq 1 ]; then
            local ZIP_BACKUP_RES=$(backupConfigFiles "$VECTR_APP_DIR")
        fi

        local CAS_CONFIGS_ALREADY_EXIST=$(dirExists "$ENV_CAS_DIR/config")
        if [ $CAS_CONFIGS_ALREADY_EXIST -eq 1 ]; then
            local CAS_ZIP_BACKUP_RES=$(backupCasConfigFiles "$ENV_VECTR_DEPLOY_DIR" "$ENV_CAS_DIR")
        fi

        local COPIED_RELEASE_FILES=$(copyFilesToFolder "$ENV_VECTR_DOWNLOAD_TEMP/$VECTR_RELEASE_FOLDER_NAME" "$VECTR_APP_DIR")
        local VECTR_FIX_COPIED_RELEASE_PERMS=$(fixDirPerms "$ENV_VECTR_OS_USER" "$VECTR_APP_DIR")

        local VECTR_DEPLOY_DIR_POST_PERMS_CHECK=$(dirPermsCheck "$ENV_VECTR_OS_USER" "$VECTR_APP_DIR")
        printStatusMark "$VECTR_DEPLOY_DIR_POST_PERMS_CHECK"
        printf " VECTR deployed and check directory permissions are OK after deployment\n"

        local VECTR_VERIFY_DEPLOY=$(verifyVectrReleaseHelper "$VECTR_APP_DIR")
    fi


    printStatusMark "$VECTR_VERIFY_DEPLOY"
    printf " Verify VECTR deployed to VECTR deploy folder\n"

    checkContinueDeployment "$VECTR_VERIFY_DEPLOY"


    # -------------------------------------------------------------------------------------------
    # Step 13b: Copy extracted VECTR release files to VECTR deploy directory if it's newly downloaded or nothing exists in there
    # -------------------------------------------------------------------------------------------

    local VECTR_TOOLS_FOLDER_EXISTS
    VECTR_TOOLS_FOLDER_EXISTS=$(dirExists "$VECTR_APP_DIR/tools")

    if [ $VECTR_TOOLS_FOLDER_EXISTS -ne 1 ]; then
        local MAKE_TOOLS_DIR=$(makeDir "$VECTR_APP_DIR/tools")
    fi
    VECTR_TOOLS_FOLDER_EXISTS=$(dirExists "$VECTR_APP_DIR/tools")

    printStatusMark "$VECTR_TOOLS_FOLDER_EXISTS"
    printf " Verify VECTR tools dir exists for any post-installation scripts\n"


    # -------------------------------------------------------------------------------------------
    # Step 14: Generate certs if needed or copy certs to correct config dir
    # -------------------------------------------------------------------------------------------

    local CRT_FILENAME
    local KEY_FILENAME
    if [ -z "$ENV_VECTR_SSL_CRT" ] || [ -z "$ENV_VECTR_SSL_KEY" ] || [ ! -f "$ENV_VECTR_SSL_CRT" ] || [ ! -f "$ENV_VECTR_SSL_KEY" ]; then
        local SELF_SIGNED_CERT_CLI_OUTPUT
        local SELF_SIGNED_CERT_NAME="ssl"
        CRT_FILENAME="$SELF_SIGNED_CERT_NAME.crt"
        KEY_FILENAME="$SELF_SIGNED_CERT_NAME.key"

        local CA_CERT_PATH
        CA_CERT_PATH="${ENV_TAXII_CERT_DIR}/${ENV_VECTR_CA_CERT}"
        local CA_KEY_PATH
        CA_KEY_PATH="${ENV_TAXII_CERT_DIR}/${ENV_VECTR_CA_KEY}"
        SELF_SIGNED_CERT_CLI_OUTPUT=$(buildSelfSignedCerts "$ENV_VECTR_OS_USER" "$ENV_VECTR_HOSTNAME" "$VECTR_APP_DIR" "$CA_CERT_PATH" "$CA_KEY_PATH" "$CA_PASS")

        local CERTS_GENERATED_OK
        CERTS_GENERATED_OK=1
        # @TODO - build this function
        #CERTS_GENERATED_OK=$(checkGeneratedCertOutput "$SELF_SIGNED_CERT_CLI_OUTPUT")

        printStatusMark "$CERTS_GENERATED_OK"
        printf " Generated self-signed SSL certs\n"
    else
        # copy both to $VECTR_DEPLOY_DIR/config if not there
        CRT_FILENAME=$(basename "$ENV_VECTR_SSL_CRT")
        KEY_FILENAME=$(basename "$ENV_VECTR_SSL_KEY")

        if [ ! -f "$VECTR_APP_DIR/config/$CRT_FILENAME" ] || [ ! -f "$VECTR_APP_DIR/config/$KEY_FILENAME" ]; then
            cp "$ENV_VECTR_SSL_CRT" "$VECTR_APP_DIR/config/$CRT_FILENAME"
            cp "$ENV_VECTR_SSL_KEY" "$VECTR_APP_DIR/config/$KEY_FILENAME"

            printStatusMark 1
            printf " Attempting to use existing SSL certs specified, moving to VECTR config\n"
        else
            printStatusMark 1
            printf " Attempting to use existing SSL certs in VECTR config folder\n"
        fi
    fi

    # make ssl.key file readable by all (not ideal, but Ubuntu's docker perms are a pain)
    # @TODO - get rid of this if we're not supporting snap installs?
    chmod a+r "$VECTR_APP_DIR/config/$KEY_FILENAME"

    # -------------------------------------------------------------------------------------------
    # Step 15: Verify SSL certs
    # -------------------------------------------------------------------------------------------
    local VECTR_VERIFY_CERTS
    VECTR_VERIFY_CERTS=$(verifySSLCert "$VECTR_APP_DIR/config/$KEY_FILENAME" "$VECTR_APP_DIR/config/$CRT_FILENAME")

    printStatusMark "$VECTR_VERIFY_CERTS"
    printf " Verify VECTR SSL certs in config folder\n"

    checkContinueDeployment "$VECTR_VERIFY_CERTS"

    # -------------------------------------------------------------------------------------------
    # Step 16: Write SSL cert location to ENV file
    # -------------------------------------------------------------------------------------------

    local VECTR_FINAL_SSL_KEY_FILE
    VECTR_FINAL_SSL_KEY_FILE="$VECTR_APP_DIR/config/$KEY_FILENAME"
    local VECTR_FINAL_SSL_CRT_FILE
    VECTR_FINAL_SSL_CRT_FILE="$VECTR_APP_DIR/config/$CRT_FILENAME"

    local VECTR_WRITE_SSL_KEY_CONF=$(writeKeyValueToEnvFile "$ENV_FILE" "$VECTR_SSL_KEY_ENV_KEYNAME" "$VECTR_FINAL_SSL_KEY_FILE")
    local VECTR_WRITE_SSL_CRT_CONF=$(writeKeyValueToEnvFile "$ENV_FILE" "$VECTR_SSL_CRT_ENV_KEYNAME" "$VECTR_FINAL_SSL_CRT_FILE")

    # -------------------------------------------------------------------------------------------
    # Step 17: Verify ENV file SSL contents
    # -------------------------------------------------------------------------------------------

    local SSL_KEY_FILE_CHECK
    SSL_KEY_FILE_CHECK="$(envFileKeyEqualsValue "$ENV_FILE" "$VECTR_SSL_KEY_ENV_KEYNAME" "$VECTR_FINAL_SSL_KEY_FILE")"
    local SSL_CRT_FILE_CHECK
    SSL_CRT_FILE_CHECK="$(envFileKeyEqualsValue "$ENV_FILE" "$VECTR_SSL_CRT_ENV_KEYNAME" "$VECTR_FINAL_SSL_CRT_FILE")"

    local ENV_FILE_SSL_FILES_CHECK
    if [ $SSL_KEY_FILE_CHECK -eq 1 ] && [ $SSL_CRT_FILE_CHECK -eq 1 ]; then
        ENV_FILE_SSL_FILES_CHECK=1
    else
        ENV_FILE_SSL_FILES_CHECK=0
    fi

    printStatusMark "$ENV_FILE_SSL_FILES_CHECK"
    printf " Verify VECTR SSL certs set in ENV file\n"

    checkContinueDeployment "$ENV_FILE_SSL_FILES_CHECK"

    # -------------------------------------------------------------------------------------------
    # Step 18: Modify VECTR deploy directory configuration files to match supplied env settings IF NOT SET
    # -------------------------------------------------------------------------------------------

    local DOCKER_COMPOSE_YAML_DEPLOY_DIR_EXISTS
    DOCKER_COMPOSE_YAML_DEPLOY_DIR_EXISTS="$(yamlConfigItemExists "$VECTR_APP_DIR/$DEPLOY_COMPOSE_YAML_FILE_PATH" "$VECTR_APP_DIR/wars")"
    if [ "$DOCKER_COMPOSE_YAML_DEPLOY_DIR_EXISTS" -ne 1 ]; then
        local EDIT_DOCKER_COMPOSE_YAML_DEPLOY_DIR
        EDIT_DOCKER_COMPOSE_YAML_DEPLOY_DIR="$(editYamlConfigItem "$VECTR_APP_DIR/$DEPLOY_COMPOSE_YAML_FILE_PATH" "$DEPLOY_DEFAULT_DEPLOY_DIR" "$VECTR_APP_DIR")"
    fi

    local SECONDARY_YAML_DEPLOY_DIR_EXISTS
    SECONDARY_YAML_DEPLOY_DIR_EXISTS="$(yamlConfigItemExists "$VECTR_APP_DIR/$DEPLOY_SECONDARY_YAML_FILE_PATH" "$VECTR_APP_DIR/config/server.xml")"
    if [ "$SECONDARY_YAML_DEPLOY_DIR_EXISTS" -ne 1 ]; then
        local EDIT_SECONDARY_YAML_DEPLOY_DIR
        EDIT_SECONDARY_YAML_DEPLOY_DIR="$(editYamlConfigItem "$VECTR_APP_DIR/$DEPLOY_SECONDARY_YAML_FILE_PATH" "$DEPLOY_DEFAULT_DEPLOY_DIR" "$VECTR_APP_DIR")"
    fi

    local SECONDARY_YAML_DATA_DIR_EXISTS
    SECONDARY_YAML_DATA_DIR_EXISTS="$(yamlConfigItemExists "$VECTR_APP_DIR/$DEPLOY_SECONDARY_YAML_FILE_PATH" "$ENV_VECTR_DATA_DIR")"
    if [ "$SECONDARY_YAML_DATA_DIR_EXISTS" -ne 1 ]; then
        local EDIT_SECONDARY_YAML_DATA_DIR
        EDIT_SECONDARY_YAML_DATA_DIR="$(editYamlConfigItem "$VECTR_APP_DIR/$DEPLOY_SECONDARY_YAML_FILE_PATH" "$DEPLOY_DEFAULT_DATA_DIR" "$ENV_VECTR_DATA_DIR")"
    fi

    local SECONDARY_YAML_SSL_PORT_MAP_EXISTS
    SECONDARY_YAML_SSL_PORT_MAP_EXISTS="$(yamlConfigItemExists "$VECTR_APP_DIR/$DEPLOY_SECONDARY_YAML_FILE_PATH" "\"$ENV_VECTR_PORT")"
    if [ "$SECONDARY_YAML_SSL_PORT_MAP_EXISTS" -ne 1 ]; then
        local EDIT_SECONDARY_YAML_SSL_PORT
        EDIT_SECONDARY_YAML_SSL_PORT="$(editYamlConfigItem "$VECTR_APP_DIR/$DEPLOY_SECONDARY_YAML_FILE_PATH" "$DEPLOY_DEFAULT_PORTS" "\"$ENV_VECTR_PORT:8443\"")"
    fi

    local SECONDARY_YAML_MONGO_PORT_MAP_EXISTS
    SECONDARY_YAML_MONGO_PORT_MAP_EXISTS="$(yamlConfigItemExists "$VECTR_APP_DIR/$DEPLOY_SECONDARY_YAML_FILE_PATH" "\"$ENV_MONGO_PORT")"
    if [ "$SECONDARY_YAML_MONGO_PORT_MAP_EXISTS" -ne 1 ]; then
        local EDIT_SECONDARY_YAML_MONGO_PORT
        EDIT_SECONDARY_YAML_MONGO_PORT="$(editYamlConfigItem "$VECTR_APP_DIR/$DEPLOY_SECONDARY_YAML_FILE_PATH" "$DEPLOY_DEFAULT_MONGO_PORTS" "\"$ENV_MONGO_PORT:27017\"")"
    fi

    # DEPLOY_DEFAULT_TOMCAT_CONTAINER_NAME="vectr_tomcat_sandbox1"
    # DEPLOY_DEFAULT_MONGO_CONTAINER_NAME="vectr_mongo_sandbox1"
    # Network config items
    # - subnet: 10.0.27.0/24
    local DOCKER_COMPOSE_YAML_NETWORK_SUBNET_EXISTS
    DOCKER_COMPOSE_YAML_NETWORK_SUBNET_EXISTS="$(yamlConfigItemExists "$VECTR_APP_DIR/$DEPLOY_COMPOSE_YAML_FILE_PATH" "$ENV_VECTR_NETWORK_SUBNET")"
    if [ "$DOCKER_COMPOSE_YAML_NETWORK_SUBNET_EXISTS" -ne 1 ]; then
        local EDIT_DOCKER_COMPOSE_YAML_NETWORK_SUBNET
        EDIT_DOCKER_COMPOSE_YAML_NETWORK_SUBNET="$(replaceValueInFile "$VECTR_APP_DIR/$DEPLOY_COMPOSE_YAML_FILE_PATH" "$DEPLOY_DEFAULT_NETWORK_SUBNET" "$ENV_VECTR_NETWORK_SUBNET")"
    fi

    # replace tomcat VECTR_BRIDGE first, it'll replace the - as a yamlConfigItem, we can then replace other instances like mongo later
    local DOCKER_COMPOSE_YAML_TOMCAT_NETWORK_NAME_EXISTS
    DOCKER_COMPOSE_YAML_TOMCAT_NETWORK_NAME_EXISTS="$(yamlSoloConfigItemExists "$VECTR_APP_DIR/$DEPLOY_COMPOSE_YAML_FILE_PATH" "$DEPLOY_DEFAULT_NETWORK_NAME")"
    if [ "$DOCKER_COMPOSE_YAML_TOMCAT_NETWORK_NAME_EXISTS" -eq 1 ]; then
        local EDIT_DOCKER_COMPOSE_YAML_TOMCAT_NETWORK_NAME
        EDIT_DOCKER_COMPOSE_YAML_TOMCAT_NETWORK_NAME="$(replaceDockerNetworkNameWithAlias "$DEPLOY_DEFAULT_NETWORK_NAME" "$ENV_VECTR_HOSTNAME" "$VECTR_APP_DIR/$DEPLOY_COMPOSE_YAML_FILE_PATH")"
    fi

    # vectr_bridge category created above
    local DOCKER_COMPOSE_YAML_NETWORK_NAME_EXISTS
    DOCKER_COMPOSE_YAML_NETWORK_NAME_EXISTS="$(yamlConfigCategoryExists "$VECTR_APP_DIR/$DEPLOY_COMPOSE_YAML_FILE_PATH" "$ENV_VECTR_NETWORK_NAME")"
    if [ "$DOCKER_COMPOSE_YAML_NETWORK_NAME_EXISTS" -ne 1 ]; then
        local EDIT_DOCKER_COMPOSE_YAML_NETWORK_NAME
        EDIT_DOCKER_COMPOSE_YAML_NETWORK_NAME="$(replaceValueInFile "$VECTR_APP_DIR/$DEPLOY_COMPOSE_YAML_FILE_PATH" "$DEPLOY_DEFAULT_NETWORK_NAME" "$ENV_VECTR_NETWORK_NAME")"
    fi

    # secondary yaml
    # vectr_tomcat_sandbox1
    local SECONDARY_YAML_TOMCAT_CONTAINER_NAME_EXISTS
    SECONDARY_YAML_TOMCAT_CONTAINER_NAME_EXISTS="$(yamlConfigItemExists "$VECTR_APP_DIR/$DEPLOY_SECONDARY_YAML_FILE_PATH" "$ENV_VECTR_TOMCAT_CONTAINER_NAME")"
    if [ "$SECONDARY_YAML_TOMCAT_CONTAINER_NAME_EXISTS" -ne 1 ]; then
        local EDIT_SECONDARY_YAML_TOMCAT_CONTAINER_NAME
        EDIT_SECONDARY_YAML_TOMCAT_CONTAINER_NAME="$(replaceValueInFile "$VECTR_APP_DIR/$DEPLOY_SECONDARY_YAML_FILE_PATH" "$DEPLOY_DEFAULT_TOMCAT_CONTAINER_NAME" "$ENV_VECTR_TOMCAT_CONTAINER_NAME")"
    fi

    # vectr_mongo_sandbox1
    local SECONDARY_YAML_MONGO_CONTAINER_NAME_EXISTS
    SECONDARY_YAML_MONGO_CONTAINER_NAME_EXISTS="$(yamlConfigItemExists "$VECTR_APP_DIR/$DEPLOY_SECONDARY_YAML_FILE_PATH" "$ENV_VECTR_MONGO_CONTAINER_NAME")"
    if [ "$SECONDARY_YAML_MONGO_CONTAINER_NAME_EXISTS" -ne 1 ]; then
        local EDIT_SECONDARY_YAML_MONGO_CONTAINER_NAME
        EDIT_SECONDARY_YAML_MONGO_CONTAINER_NAME="$(replaceValueInFile "$VECTR_APP_DIR/$DEPLOY_SECONDARY_YAML_FILE_PATH" "$DEPLOY_DEFAULT_MONGO_CONTAINER_NAME" "$ENV_VECTR_MONGO_CONTAINER_NAME")"
    fi

    # Wrap in conditionals to detect if they're actually there?

    # NOTE!!! These are followed by a trailing /, this might cause issues... probably need to build in some leniency in the yamlConfigItemExists function
    local DOCKER_COMPOSE_TAXII_CERT_DIR_EXISTS
    DOCKER_COMPOSE_TAXII_CERT_DIR_EXISTS="$(yamlConfigItemExists "$VECTR_APP_DIR/$DEPLOY_COMPOSE_YAML_FILE_PATH" "$ENV_TAXII_CERT_DIR/")"
    if [ "$DOCKER_COMPOSE_TAXII_CERT_DIR_EXISTS" -ne 1 ]; then
        local EDIT_DOCKER_COMPOSE_YAML_TAXII_CERT_DIR
        EDIT_DOCKER_COMPOSE_YAML_TAXII_CERT_DIR="$(editYamlConfigItem "$VECTR_APP_DIR/$DEPLOY_COMPOSE_YAML_FILE_PATH" "$DEPLOY_DEFAULT_TAXII_CERT_DIR" "$ENV_TAXII_CERT_DIR/")"
    fi

    local DOCKER_COMPOSE_CAS_DIR_EXISTS
    DOCKER_COMPOSE_CAS_DIR_EXISTS="$(yamlConfigItemExists "$VECTR_APP_DIR/$DEPLOY_COMPOSE_YAML_FILE_PATH" "$ENV_CAS_DIR/")"
    if [ "$DOCKER_COMPOSE_CAS_DIR_EXISTS" -ne 1 ]; then
        local EDIT_DOCKER_COMPOSE_YAML_CAS_DIR
        # this is a bandaid, DEPLOY_DEFAULT_CAS_FOLDER is manipulated by the first part of this step
        EDIT_DOCKER_COMPOSE_YAML_CAS_DIR="$(editYamlConfigItem "$VECTR_APP_DIR/$DEPLOY_COMPOSE_YAML_FILE_PATH" "$DEPLOY_DEFAULT_CAS_FOLDER/" "$ENV_CAS_DIR/")"
    fi


    # Modify auth.properties conf values
    local AUTH_PROPERTIES_EXTERNAL_PORT_SET
    AUTH_PROPERTIES_EXTERNAL_PORT_SET="$(envFileKeyEqualsValue "$VECTR_APP_DIR/config/auth.properties" "$AUTH_PROPERTIES_EXT_PORT_KEYNAME" "$ENV_VECTR_PORT")"

    if [ "$AUTH_PROPERTIES_EXTERNAL_PORT_SET" -ne 1 ]; then
        local EDIT_AUTH_PROPERTIES_EXTERNAL_PORT
        EDIT_AUTH_PROPERTIES_EXTERNAL_PORT="$(writeKeyValueToEnvFile "$VECTR_APP_DIR/config/auth.properties" "$AUTH_PROPERTIES_EXT_PORT_KEYNAME" "$ENV_VECTR_PORT")"
    fi

    local AUTH_PROPERTIES_HOSTNAME_SET
    AUTH_PROPERTIES_HOSTNAME_SET="$(envFileKeyEqualsValue "$VECTR_APP_DIR/config/auth.properties" "$AUTH_PROPERTIES_HOSTNAME_KEYNAME" "$ENV_VECTR_HOSTNAME")"

    if [ "$AUTH_PROPERTIES_HOSTNAME_SET" -ne 1 ]; then
        local EDIT_AUTH_PROPERTIES_HOSTNAME
        EDIT_AUTH_PROPERTIES_HOSTNAME="$(writeKeyValueToEnvFile "$VECTR_APP_DIR/config/auth.properties" "$AUTH_PROPERTIES_HOSTNAME_KEYNAME" "$ENV_VECTR_HOSTNAME")"
    fi

    local AUTH_PROPERTIES_INSTALLTYPE_SET
    AUTH_PROPERTIES_INSTALLTYPE_SET="$(envFileKeyEqualsValue "$VECTR_APP_DIR/config/auth.properties" "$AUTH_PROPERTIES_INSTALLTYPE_KEYNAME" "remote")"

    if [ "$AUTH_PROPERTIES_INSTALLTYPE_SET" -ne 1 ]; then
        local EDIT_AUTH_PROPERTIES_INSTALLTYPE
        EDIT_AUTH_PROPERTIES_INSTALLTYPE="$(writeKeyValueToEnvFile "$VECTR_APP_DIR/config/auth.properties" "$AUTH_PROPERTIES_INSTALLTYPE_KEYNAME" "remote")"
    fi

    # make sure this is uncommented #cas.server.url=https://my-cas-domain
    local UNCOMMENT_AUTH_PROPERTIES_CAS_SERVER="$(replaceValueInFile "$VECTR_APP_DIR/config/auth.properties" "#$AUTH_PROPERTIES_CAS_URL_KEYNAME" "$AUTH_PROPERTIES_CAS_URL_KEYNAME")"

    AUTH_PROPERTIES_CAS_URL_SET="$(envFileKeyEqualsValue "$VECTR_APP_DIR/config/auth.properties" "$AUTH_PROPERTIES_CAS_URL_KEYNAME" "$CAS_URL")"

    if [ "$AUTH_PROPERTIES_CAS_URL_SET" -ne 1 ]; then
        local EDIT_AUTH_PROPERTIES_CAS_URL
        EDIT_AUTH_PROPERTIES_CAS_URL="$(writeKeyValueToEnvFile "$VECTR_APP_DIR/config/auth.properties" "$AUTH_PROPERTIES_CAS_URL_KEYNAME" "$CAS_URL")"
    fi

    local VECTR_PROPERTIES_DATA_KEY_SET
    VECTR_PROPERTIES_DATA_KEY_SET="$(envFileKeyEqualsValue "$VECTR_APP_DIR/config/vectr.properties" "$VECTR_PROPERTIES_DATA_KEY_KEYNAME" "$ENV_VECTR_DATA_KEY")"

    if [ "$VECTR_PROPERTIES_DATA_KEY_SET" -ne 1 ]; then
        local EDIT_VECTR_PROPERTIES_DATA_KEY
        EDIT_VECTR_PROPERTIES_DATA_KEY="$(writeKeyValueToEnvFile "$VECTR_APP_DIR/config/vectr.properties" "$VECTR_PROPERTIES_DATA_KEY_KEYNAME" "$ENV_VECTR_DATA_KEY")"
    fi

    # -------------------------------------------------------------------------------------------
    # Step 19: Verify some VECTR configuration changes made by installer
    # -------------------------------------------------------------------------------------------

    local COMPOSE_DEPLOY_DIRS_ARR=("wars" "config" "backup" "migrationlogs" "migrationbackups" "tools" "uploads" "static")

    local COMPOSE_CONFIG_ITEM_EXISTS_RES
    local COMPOSE_CONFIG_ITEMS_EXIST=1
    for COMPOSE_DEPLOY_DIR in "${COMPOSE_DEPLOY_DIRS_ARR[@]}"; do
        COMPOSE_CONFIG_ITEM_EXISTS_RES="$(yamlConfigItemExists "$VECTR_APP_DIR/$DEPLOY_COMPOSE_YAML_FILE_PATH" "$VECTR_APP_DIR/$COMPOSE_DEPLOY_DIR")"

        if [ "$COMPOSE_CONFIG_ITEM_EXISTS_RES" -eq 0 ]; then
            COMPOSE_CONFIG_ITEMS_EXIST=0
        fi
    done

    # TAXII/CAS future items
    # DEV NOTE - This seems to cause the mose issues with older versions, not sure it's necessary yet
    #local COMPOSE_TAXII_CERT_EXISTS_RES="$(yamlConfigItemExists "$VECTR_APP_DIR/$DEPLOY_COMPOSE_YAML_FILE_PATH" "$ENV_TAXII_CERT_DIR/")"

    local COMPOSE_CAS_DIR_EXISTS="$(yamlConfigItemExists "$VECTR_APP_DIR/$DEPLOY_COMPOSE_YAML_FILE_PATH" "$ENV_CAS_DIR/")"
    if [ "$COMPOSE_CAS_DIR_EXISTS" -ne 1 ]; then
        COMPOSE_CONFIG_ITEMS_EXIST=0
    fi

    printStatusMark "$COMPOSE_CONFIG_ITEMS_EXIST"
    printf " VECTR docker-compose file checks out\n"

    checkContinueDeployment "$COMPOSE_CONFIG_ITEMS_EXIST"

    # Check secondary docker configuration file

    local SECONDARY_CONFIG_ITEMS_ARR=("$VECTR_APP_DIR/config/server.xml" "$VECTR_APP_DIR/config/$CRT_FILENAME" "$VECTR_APP_DIR/config/$KEY_FILENAME" "$ENV_VECTR_DATA_DIR" "\"$ENV_VECTR_PORT")

    local SECONDARY_CONFIG_ITEM_EXISTS_RES
    local SECONDARY_CONFIG_ITEMS_EXIST=1
    for SECONDARY_CONFIG_ITEM in "${SECONDARY_CONFIG_ITEMS_ARR[@]}"; do
        SECONDARY_CONFIG_ITEM_EXISTS_RES="$(yamlConfigItemExists "$VECTR_APP_DIR/$DEPLOY_SECONDARY_YAML_FILE_PATH" "$SECONDARY_CONFIG_ITEM")"

        if [ "$SECONDARY_CONFIG_ITEM_EXISTS_RES" -eq 0 ]; then
            echo "checking $SECONDARY_CONFIG_ITEM  failed"
            SECONDARY_CONFIG_ITEMS_EXIST=0
        fi
    done

    printStatusMark "$SECONDARY_CONFIG_ITEMS_EXIST"
    printf " VECTR secondary docker config file checks out\n"

    checkContinueDeployment "$SECONDARY_CONFIG_ITEMS_EXIST"

    # check auth.properties
    local AUTH_PROPERTIES_CHECKS_OUT=1
    local AUTH_PROPERTIES_EXTERNAL_PORT_CHECK
    AUTH_PROPERTIES_EXTERNAL_PORT_CHECK="$(envFileKeyEqualsValue "$VECTR_APP_DIR/config/auth.properties" "$AUTH_PROPERTIES_EXT_PORT_KEYNAME" "$ENV_VECTR_PORT")"

    if [ "$AUTH_PROPERTIES_EXTERNAL_PORT_CHECK" -ne 1 ]; then
        AUTH_PROPERTIES_CHECKS_OUT=0
    fi

    local AUTH_PROPERTIES_HOSTNAME_CHECK
    AUTH_PROPERTIES_HOSTNAME_CHECK="$(envFileKeyEqualsValue "$VECTR_APP_DIR/config/auth.properties" "$AUTH_PROPERTIES_HOSTNAME_KEYNAME" "$ENV_VECTR_HOSTNAME")"

    if [ "$AUTH_PROPERTIES_HOSTNAME_CHECK" -ne 1 ]; then
         AUTH_PROPERTIES_CHECKS_OUT=0
    fi

    local AUTH_PROPERTIES_INSTALLTYPE_CHECK
    AUTH_PROPERTIES_INSTALLTYPE_CHECK="$(envFileKeyEqualsValue "$VECTR_APP_DIR/config/auth.properties" "$AUTH_PROPERTIES_INSTALLTYPE_KEYNAME" "remote")"

    if [ "$AUTH_PROPERTIES_INSTALLTYPE_CHECK" -ne 1 ]; then
         AUTH_PROPERTIES_CHECKS_OUT=0
    fi

    local AUTH_PROPERTIES_CAS_URL_CHECK
    AUTH_PROPERTIES_CAS_URL_CHECK="$(envFileKeyEqualsValue "$VECTR_APP_DIR/config/auth.properties" "$AUTH_PROPERTIES_CAS_URL_KEYNAME" "$CAS_URL")"

    if [ "$AUTH_PROPERTIES_CAS_URL_CHECK" -ne 1 ]; then
         AUTH_PROPERTIES_CHECKS_OUT=0
    fi

    printStatusMark "$AUTH_PROPERTIES_CHECKS_OUT"
    printf " VECTR auth.properties file checks out\n"

    checkContinueDeployment "$AUTH_PROPERTIES_CHECKS_OUT"

    # -------------------------------------------------------------------------------------------
    # Step 20: Make CAS deploy folder if doesn't exist and set perms
    # -------------------------------------------------------------------------------------------

    local CAS_DIR_EXISTS=$(dirExists "$ENV_CAS_DIR/services")
    if [ "$CAS_DIR_EXISTS" -ne 1 ]
    then
        local MAKE_CAS_DIR=$(makeDir "$ENV_CAS_DIR/services")
        printStatusMark "$MAKE_CAS_DIR"
        printf " Made CAS services directory\n"

        CAS_DIR_EXISTS=$(dirExists "$ENV_CAS_DIR/services")
    fi
    printStatusMark "$CAS_DIR_EXISTS"
    printf " CAS services directory exists\n"
    checkContinueDeployment "$CAS_DIR_EXISTS"

    local CAS_CONFIG_DIR_EXISTS=$(dirExists "$ENV_CAS_DIR/config")
    if [ "$CAS_CONFIG_DIR_EXISTS" -ne 1 ]
    then
        local MAKE_CAS_CONFIG_DIR=$(makeDir "$ENV_CAS_DIR/config")
        printStatusMark "$MAKE_CAS_CONFIG_DIR"
        printf " Made CAS config directory\n"

        CAS_CONFIG_DIR_EXISTS=$(dirExists "$ENV_CAS_DIR/config")
    fi
    printStatusMark "$CAS_CONFIG_DIR_EXISTS"
    printf " CAS config directory exists\n"

    checkContinueDeployment "$CAS_CONFIG_DIR_EXISTS"

    # -------------------------------------------------------------------------------------------
    # Step 21: Write CAS service file for VECTR
    # -------------------------------------------------------------------------------------------

    local CAS_SERVICE_FILE_EXISTS=$(fileExists "$ENV_CAS_DIR/services/$CAS_SERVICE_FILE_NAME")

    local SERVICE_FILE_WRITE=$(writeCasServiceJsonFile "$ENV_VECTR_HOSTNAME" "$ENV_VECTR_PORT" "$ENV_CAS_DIR/services" "$CAS_SERVICE_FILE_NAME")

    CAS_SERVICE_FILE_EXISTS=$(fileExists "$ENV_CAS_DIR/services/$CAS_SERVICE_FILE_NAME")
    printStatusMark "$CAS_SERVICE_FILE_EXISTS"
    printf " CAS service file written\n"

    checkContinueDeployment "$CAS_SERVICE_FILE_EXISTS"


    # -------------------------------------------------------------------------------------------
    # Step 22: Move CAS configuration to specified CAS folder
    # -------------------------------------------------------------------------------------------

    # these may be the same folder so the check has to make sure they're not before moving anything
    local CAS_CONFIGS_ARE_IN_VECTR_APP_FOLDER=$(dirExists "$DEPLOY_DEFAULT_CAS_FOLDER/config")

    # @TODO - this should check for all the expected config files
    local CAS_CONFIGS_ARE_IN_DEPLOY_FOLDER
    CAS_CONFIGS_ARE_IN_DEPLOY_FOLDER=$(fileExists "$ENV_CAS_DIR/config/$CAS_CONFIG_FILE_NAME")

    if [ "$CAS_CONFIGS_ARE_IN_VECTR_APP_FOLDER" -eq 1 ] && [ $CAS_CONFIGS_ARE_IN_DEPLOY_FOLDER -ne 1 ]; then
        # move the configs into the CAS folder (this will cover scenarios with new releases/updates in place)
        local MOVE_CAS_CONFIG_FILES=$(moveFilesToFolder "$DEPLOY_DEFAULT_CAS_FOLDER/config" "$ENV_CAS_DIR/config")
    fi

    CAS_CONFIGS_ARE_IN_DEPLOY_FOLDER=$(fileExists "$ENV_CAS_DIR/config/$CAS_CONFIG_FILE_NAME")

    printStatusMark "$CAS_CONFIGS_ARE_IN_DEPLOY_FOLDER"
    printf " CAS config file from release bundle moved to CAS config folder\n"

    checkContinueDeployment "$CAS_CONFIGS_ARE_IN_DEPLOY_FOLDER"

    # -------------------------------------------------------------------------------------------
    # Step 23: Modify CAS configuration file and check
    # -------------------------------------------------------------------------------------------

    # Modify cas.properties conf values
    local CAS_PROPERTIES_SERVER_NAME_SET
    CAS_PROPERTIES_SERVER_NAME_SET="$(envFileKeyEqualsValue "$ENV_CAS_DIR/config/$CAS_CONFIG_FILE_NAME" "$CAS_CONFIG_SERVER_NAME_KEYNAME" "https://${ENV_VECTR_HOSTNAME}:8443")"

    if [ "$CAS_PROPERTIES_SERVER_NAME_SET" -ne 1 ]; then
        local EDIT_CAS_PROPERTIES_SERVER_NAME
        EDIT_CAS_PROPERTIES_SERVER_NAME="$(writeKeyValueToEnvFile "$ENV_CAS_DIR/config/$CAS_CONFIG_FILE_NAME" "$CAS_CONFIG_SERVER_NAME_KEYNAME" "https://${ENV_VECTR_HOSTNAME}:8443")"
    fi

    local CAS_PROPERTIES_SERVER_PREFIX_SET
    CAS_PROPERTIES_SERVER_PREFIX_SET="$(envFileKeyEqualsValue "$ENV_CAS_DIR/config/$CAS_CONFIG_FILE_NAME" "$CAS_CONFIG_SERVER_PREFIX_KEYNAME" "https://${ENV_VECTR_HOSTNAME}:8443/cas")"

    if [ "$CAS_PROPERTIES_SERVER_PREFIX_SET" -ne 1 ]; then
        local EDIT_CAS_PROPERTIES_SERVER_PREFIX
        EDIT_CAS_PROPERTIES_SERVER_PREFIX="$(writeKeyValueToEnvFile "$ENV_CAS_DIR/config/$CAS_CONFIG_FILE_NAME" "$CAS_CONFIG_SERVER_PREFIX_KEYNAME" "https://${ENV_VECTR_HOSTNAME}:8443/cas")"
    fi

    # Check cas.properties conf values
    local CAS_PROPERTIES_CHECKS_OUT
    CAS_PROPERTIES_CHECKS_OUT=1
    local CAS_PROPERTIES_SERVER_NAME_CHECK
    CAS_PROPERTIES_SERVER_NAME_CHECK="$(envFileKeyEqualsValue "$ENV_CAS_DIR/config/$CAS_CONFIG_FILE_NAME" "$CAS_CONFIG_SERVER_NAME_KEYNAME" "https://${ENV_VECTR_HOSTNAME}:8443")"

    if [ "$CAS_PROPERTIES_SERVER_NAME_CHECK" -ne 1 ]; then
        CAS_PROPERTIES_CHECKS_OUT=0
    fi

    local CAS_PROPERTIES_SERVER_PREFIX_CHECK
    CAS_PROPERTIES_SERVER_PREFIX_CHECK="$(envFileKeyEqualsValue "$ENV_CAS_DIR/config/$CAS_CONFIG_FILE_NAME" "$CAS_CONFIG_SERVER_PREFIX_KEYNAME" "https://${ENV_VECTR_HOSTNAME}:8443/cas")"

    if [ "$CAS_PROPERTIES_SERVER_PREFIX_CHECK" -ne 1 ]; then
         CAS_PROPERTIES_CHECKS_OUT=0
    fi

    printStatusMark "$CAS_PROPERTIES_CHECKS_OUT"
    printf " CAS config cas.properties file checks out\n"

    checkContinueDeployment "$CAS_PROPERTIES_CHECKS_OUT"

    # -------------------------------------------------------------------------------------------
    # Step 24: Fix CAS dir perms
    # -------------------------------------------------------------------------------------------

    local CAS_PERMS_FIX=$(fixDirPerms "$ENV_VECTR_OS_USER" "$ENV_CAS_DIR")

    # @TODO - verify that this doesn't prevent writes to logs folder?
    local CAS_PERMS_CHECK=$(dirPermsCheck "$ENV_VECTR_OS_USER" "$ENV_CAS_DIR")
    printStatusMark "$CAS_PERMS_CHECK"
    printf " CAS dir permissions checked/fixed\n"

    checkContinueDeployment "$CAS_PERMS_CHECK"


    # -------------------------------------------------------------------------------------------
    # Step 25: Check VECTR deployment directory permissions for VECTR user account and if they're bad attempt to fix and recheck
    # -------------------------------------------------------------------------------------------

    local VECTR_DEPLOY_DIR_PERMS_CHECK=$(dirPermsCheck "$ENV_VECTR_OS_USER" "$ENV_VECTR_DEPLOY_DIR")
    if [ "$VECTR_DEPLOY_DIR_PERMS_CHECK" -ne 1 ]
    then
        local VECTR_FIX_DEPLOY_DIR_PERMS=$(fixDirPerms "$ENV_VECTR_OS_USER" "$ENV_VECTR_DEPLOY_DIR")
        printStatusMark 1
        printf " Fix VECTR deploy directory permissions\n"

        local VECTR_DEPLOY_DIR_PERMS_CHECK=$(dirPermsCheck "$ENV_VECTR_OS_USER" "$ENV_VECTR_DEPLOY_DIR")
        printStatusMark "$VECTR_DEPLOY_DIR_PERMS_CHECK"
        printf " VECTR deploy directory permissions are OK\n"
    else
        printStatusMark "$VECTR_DEPLOY_DIR_PERMS_CHECK"
        printf " VECTR deploy directory permissions are OK\n"
    fi
    checkContinueDeployment "$VECTR_DEPLOY_DIR_PERMS_CHECK"


    # -------------------------------------------------------------------------------------------
    # Step 26: Remove old auth service
    # -------------------------------------------------------------------------------------------
    # delete sra-oauth2-rest.war if it exists in wars

    local OLD_AUTH_WAR_EXISTS=$(fileExists "$VECTR_APP_DIR/wars/sra-oauth2-rest.war")
    if [ "$OLD_AUTH_WAR_EXISTS" -eq 1 ]
    then
        local OLD_AUTH_WAR_DELETE=$(rm "$VECTR_APP_DIR/wars/sra-oauth2-rest.war")
    fi

    # -------------------------------------------------------------------------------------------
    # Step 27: Edit /etc/hosts to add hostname and 127.0.0.1 if doesn't exist
    # -------------------------------------------------------------------------------------------

    local HOSTS_VECTR_HOSTNAME_EXISTS

    HOSTS_VECTR_HOSTNAME_EXISTS="$(checkHostExists "$ENV_VECTR_HOSTNAME")"
    if [ "$HOSTS_VECTR_HOSTNAME_EXISTS" -ne 1 ]; then
        local HOSTS_ADD_VECTR_HOSTNAME
        HOSTS_ADD_VECTR_HOSTNAME="$(addHost "127.0.0.1" "$ENV_VECTR_HOSTNAME")"

        printStatusMark 1
        printf " VECTR local /etc/hosts hostname created\n"

        HOSTS_VECTR_HOSTNAME_EXISTS="$(checkHostExists "$ENV_VECTR_HOSTNAME")"
    fi

    printStatusMark "$SECONDARY_CONFIG_ITEMS_EXIST"
    printf " VECTR local /etc/hosts hostname exists\n"

    # -------------------------------------------------------------------------------------------
    # Step 28: Mark VECTR_INSTALLED_VERSION in env file supplied
    # -------------------------------------------------------------------------------------------

    local VECTR_WRITE_INSTALLED_VER=$(writeKeyValueToEnvFile "$ENV_FILE" "$VECTR_ENV_INSTALLED_VER_KEYNAME" "$VECTR_RELEASE_ZIP_NAME")

    local VECTR_INSTALLED_VER_ENV_CHECK
    VECTR_INSTALLED_VER_ENV_CHECK="$(envFileKeyEqualsValue "$ENV_FILE" "$VECTR_ENV_INSTALLED_VER_KEYNAME" "$VECTR_RELEASE_ZIP_NAME")"

    printStatusMark "$VECTR_INSTALLED_VER_ENV_CHECK"
    printf " Verify VECTR Installed version set in ENV file\n"

    chown "$RUN_USER" "$ENV_FILE"

    # -------------------------------------------------------------------------------------------
    # Step 29: Restart docker containers if they were stopped
    # -------------------------------------------------------------------------------------------

    if [[ "$DOCKER_STOPPED" -eq 1 ]]; then
        local START_VECTR=$(docker-compose -f "$VECTR_APP_DIR/docker-compose.yml" -f "$VECTR_APP_DIR/devSsl.yml" -p $ENV_FILE_NAME up -d)
        printStatusMark 1
        printf " Docker containers restarted... please wait a moment, this can take 40 seconds or more\n"
    else
        printStatusMark 1
        printf " No existing VECTR docker containers for this to restart - fresh installation\n"
    fi

    # -------------------------------------------------------------------------------------------
    # Step 30: Migrate old users if from older version
    # -------------------------------------------------------------------------------------------

    if [[ "$OLD_AUTH_WAR_EXISTS" -eq 1 ]]; then

        local MIGRATE_USER_RUN
        local PASSWORD_MIGRATION_SCRIPT_EXISTS=$(fileExists "$RUNNING_DIR/password-migration-tool.jar")
        if [[ "$PASSWORD_MIGRATION_SCRIPT_EXISTS" -eq 1 ]]; then
            local COPY_TOOL_RESULT=$(cp -v "$RUNNING_DIR/password-migration-tool.jar" "$VECTR_APP_DIR/tools/password-migration-tool.jar")
            MIGRATE_USER_RUN=1

            # change this sleep to wait for service up? complex check in bash...
            sleep 30
            # echo "calling docker exec -w $TOMCAT_CONTAINER_TOOLS_DIR $ENV_VECTR_TOMCAT_CONTAINER_NAME java -jar password-migration-tool.jar -h $ENV_VECTR_MONGO_CONTAINER_NAME -p 27017"
            local MIGRATE_COMMAND=$(docker exec -w "$TOMCAT_CONTAINER_TOOLS_DIR" "$ENV_VECTR_TOMCAT_CONTAINER_NAME" java -jar password-migration-tool.jar -h "$ENV_VECTR_MONGO_CONTAINER_NAME" -p 27017 )
            printStatusMark $MIGRATE_USER_RUN
            printf " Resetting user passwords to default due to authentication change (if this fails, you won't be able to login. see documentation)\n"
        else
            MIGRATE_USER_RUN=0
            printStatusMark 0
            printf " Couldn't find password migration tool for old users, manual user migration will be required after install\n"
        fi
    else
        printStatusMark 1
        printf " No VECTR data setup tools needed - fresh installation\n"
    fi


    # -------------------------------------------------------------------------------------------
    # Step 31: Output docker compose command to start running VECTR
    # -------------------------------------------------------------------------------------------

    if [[ "$DOCKER_STOPPED" -eq 1 ]]; then
        echo ""
        echo "-------------------- UPGRADE COMPLETE -----------------------"
        echo ""
        echo " # NOTE: VECTR will take 2-5 minutes to restart the server with the latest code. "
        echo " #  Once deployed you may visit https://$ENV_VECTR_HOSTNAME:$ENV_VECTR_PORT"
    else
        echo ""
        echo "-------------------- INSTALLATION COMPLETE -----------------------"
        echo " # NOTE: cd to your vectr deploy app directory (ex: cd $VECTR_APP_DIR) then run the following command:"
        echo ""
        echo "sudo docker-compose -f docker-compose.yml -f devSsl.yml -p $ENV_FILE_NAME up -d"
        echo ""
        echo " # NOTE: VECTR will take 2-5 minutes to deploy for the first time. "
        echo " #  Once deployed you may visit https://$ENV_VECTR_HOSTNAME:$ENV_VECTR_PORT"
    fi



}



deployVectr

SCRIPTEXIT
exit 0