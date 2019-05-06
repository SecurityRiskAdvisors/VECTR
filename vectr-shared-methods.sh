#!/bin/bash

SHARED_METHODS_VER=2

# shell logging functions from http://www.cubicrace.com/2016/03/efficient-logging-mechnism-in-shell.html
SCRIPT_LOG=vectr-install.log
touch $SCRIPT_LOG

function SCRIPTENTRY(){
 timeAndDate=`date`
 script_name=`basename "$0"`
 script_name="${script_name%.*}"
 echo "[$timeAndDate] [DEBUG]  > $script_name $FUNCNAME" >> $SCRIPT_LOG
}

function SCRIPTEXIT(){
 script_name=`basename "$0"`
 script_name="${script_name%.*}"
 echo "[$timeAndDate] [DEBUG]  < $script_name $FUNCNAME" >> $SCRIPT_LOG
}

function FUNCENTRY(){
 local cfn="${FUNCNAME[1]}"
 timeAndDate=`date`
 echo "[$timeAndDate] [DEBUG]  > $cfn $FUNCNAME" >> $SCRIPT_LOG
}

function FUNCEXIT(){
 local cfn="${FUNCNAME[1]}"
 timeAndDate=`date`
 echo "[$timeAndDate] [DEBUG]  < $cfn $FUNCNAME" >> $SCRIPT_LOG
}

function INFO(){
 local function_name="${FUNCNAME[1]}"
    local msg="$1"
    timeAndDate=`date`
    echo "[$timeAndDate] [INFO]  $msg" >> $SCRIPT_LOG
}

function DEBUG(){
 local function_name="${FUNCNAME[1]}"
    local msg="$1"
    timeAndDate=`date`
 echo "[$timeAndDate] [DEBUG]  $msg" >> $SCRIPT_LOG
}

function ERROR(){
 local function_name="${FUNCNAME[1]}"
    local msg="$1"
    timeAndDate=`date`
    echo "[$timeAndDate] [ERROR]  $msg" >> $SCRIPT_LOG
}

function getEnvVar () {
    FUNCENTRY
    DEBUG "Getting ENV var $1 with param $2"
    #@TODO - fix parsing here to make it less bad
    if [ -z "$2" ]; then
        echo "$(printenv $1)"
    else
        echo "$(grep $1 $2 | cut -d '=' -f 2-)"
    fi
    FUNCEXIT
}

function getFileNameNoExt ()
{
    FUNCENTRY
    FILENAME="$(basename $1)"
    WITHOUT_EXT="${FILENAME%.*}"
    DEBUG "Using $1 retrieved filename with no Ext: $WITHOUT_EXT"
    echo "$WITHOUT_EXT"
    FUNCEXIT
}

function curlInstalled ()
{
    FUNCENTRY
    local CURL_INSTALLED="$(which curl ; echo $?)"
    if [ "$CURL_INSTALLED" == "1" ]; then
        ERROR "Curl not installed. Installation can't continue."
        echo 0
    else
        echo 1
    fi
    FUNCEXIT
}


function getJavaVersion ()
{
    FUNCENTRY
    local JAVA_VER_REGEX="([0-9]+\.[0-9]+|[0-9]+)"
    local JAVA_VER=$(java -version 2>&1 | grep 'version' | awk '{print $3}' | grep -oE "${JAVA_VER_REGEX}" | head -1)
    # local JAVA_VER=$(printf "java version \"1.5.1\"" | grep 'version' | awk '{print $3}' | grep -oE "${JAVA_VER_REGEX}" | head -1)

    if [ -z "$JAVA_VER" ]
    then
        echo 0
    else
        if [[ "$JAVA_VER" =~ [.] ]]
        then
            local SPLIT_JAVA_VER_MAJOR=$(awk -F. '{print $1}' <<< "$JAVA_VER")
            local SPLIT_JAVA_VER_MINOR=$(awk -F. '{print $2}' <<< "$JAVA_VER")

            if [ "$SPLIT_JAVA_VER_MAJOR" = "1" ]; then
                echo "$SPLIT_JAVA_VER_MINOR"
            else
                echo "$SPLIT_JAVA_VER_MAJOR"
            fi

        else
            local INT_REGEX='^[0-9]+$'
            if [[ "$JAVA_VER" =~ $INT_REGEX ]]; then
                if [[ "$JAVA_VER" -ge 8 ]]; then
                    echo "$JAVA_VER"
                else
                    # versions below 8 don't report this way
                    echo 0
                fi
            else
                # not integer, something's wrong
                echo 0
            fi
        fi
    fi
    FUNCEXIT
}

function javaOk ()
{
    local JAVA_VER=$(getJavaVersion)   # or result=`myfunc`
    [[ "$JAVA_VER" -ge 8 ]] && echo 1 || echo 0
}

function checkMajorMinorDockerVer ()
{
    FUNCENTRY
    local MAJOR_VER="$1"
    local MINOR_VER="$2"

    local INT_REGEX='^[0-9]+$'
    DEBUG "Evaluating Docker Major and Minor version for v$1.$2 "
    if [[ ( "$MAJOR_VER" =~ $INT_REGEX ) && ( "$MINOR_VER" =~ $INT_REGEX ) ]]; then
        if [[ "$MAJOR_VER" -eq 1 ]]; then
            if [[ $MINOR_VER -ge 10 ]]; then
                echo 1
            else
                echo 0
            fi
        else
            if [[ "$MAJOR_VER" -eq 17 ]]; then
                if [[ $MINOR_VER -ge 03 ]]; then
                    echo 1
                else
                    echo 0
                fi
            else
                if [[ "$MAJOR_VER" -ge 18 ]]; then
                    echo 1
                else
                    echo 0
                fi
            fi
        fi
    else
        # not integers, something's wrong
        ERROR "Docker major and minor version not recognized, can't determine if installed"
        echo 0
    fi
    FUNCEXIT
}

# Check for Docker ce version 17.03+ or Docker engine 1.10+
function dockerVersionOk ()
{
    FUNCENTRY
    local DOCKER_VER_REGEX="([0-9]+\.[0-9]+|[0-9]+)"
    local DOCKER_VER=$(docker -v 2>&1 | grep 'version' | awk '{print $3}' | grep -oE "${DOCKER_VER_REGEX}" | head -1)
    # local JAVA_VER=$(printf "java version \"1.5.1\"" | grep 'version' | awk '{print $3}' | grep -oE "${JAVA_VER_REGEX}" | head -1)

    if [ -z "$DOCKER_VER" ]
    then
        ERROR "Docker version can't be parsed - possibly empty, docker not installed?"
        echo 0
    else
        if [[ "$DOCKER_VER" =~ [.] ]]
        then
            local SPLIT_DOCKER_VER_MAJOR=$(awk -F. '{print $1}' <<< "$DOCKER_VER")
            local SPLIT_DOCKER_VER_MINOR=$(awk -F. '{print $2}' <<< "$DOCKER_VER")

            local DOCKER_VER_OK=$(checkMajorMinorDockerVer "$SPLIT_DOCKER_VER_MAJOR" "$SPLIT_DOCKER_VER_MINOR")
            echo "$DOCKER_VER_OK"

        else
            ERROR "Docker version not parsed properly. Installer error."
            echo 0
        fi
    fi
    FUNCEXIT
}

function dockerContainerExists ()
{
    FUNCENTRY
    local CONTAINER_NAME="$1"

    if sudo docker ps -a --format '{{.Names}}' | grep -Eq "^${CONTAINER_NAME}\$"; then
        DEBUG "Docker container ${CONTAINER_NAME} doesn't exist"
        echo 1
    else
        DEBUG "Docker container ${CONTAINER_NAME} exists"
        echo 0
    fi

    FUNCEXIT
}

function userExists ()
{
    FUNCENTRY
    # https://superuser.com/questions/336275/find-out-if-user-name-exists
    if id "$1" >/dev/null 2>&1; then
        echo 1
    else
        ERROR "$1 user not found using id command"
        echo 0
    fi
    FUNCEXIT
}

function dirExists ()
{
    FUNCENTRY
    if [ -d "$1" ]; then
        echo 1
    else
        INFO "Directory $1 does not exist on disk"
        echo 0
    fi
    FUNCEXIT
}

function showSpinnerForPid ()
{
    FUNCENTRY
    spin='-\|/'

    i=0
    while kill -0 $1 2>/dev/null
    do
      i=$(( (i+1) %4 ))
      printf "\r${spin:$i:1}"
      sleep .1
    done
    echo ""
    FUNCEXIT
}

function fileExists ()
{
    FUNCENTRY
    if [ -f "$1" ]; then
        echo 1
    else
        INFO "File $1 does not exist on disk"
        echo 0
    fi
    FUNCEXIT
}

function downloadLatestVectrRelease ()
{
    FUNCENTRY
    cd $3
    sudo -u $1 curl -O -s -L "$2" 2>/dev/null &
    cd $4

    local pid=$! # Process Id of the previous running command
    showSpinnerForPid $pid
    FUNCEXIT
}

function getLatestVectrReleaseFileUrl ()
{
    FUNCENTRY
    local VECTR_RELEASE_REGEX="(\/SecurityRiskAdvisors\/VECTR\/releases\/download\/[_A-Za-z0-9\.\-]+\/[_A-Za-z0-9\.\-]+\.zip)"
    local VECTR_RELEASE_URL=$(curl -s -L $1 | grep -oE "${VECTR_RELEASE_REGEX}")

    echo "https://github.com$VECTR_RELEASE_URL"
    FUNCEXIT
}

function getLatestVectrReleaseZipFile ()
{
    FUNCENTRY
    local VECTR_ZIP_FILE_REGEX="[_A-Za-z0-9\.\-]+\.zip"
    local VECTR_ZIP_FILE=$(echo "$1" | grep -oE "${VECTR_ZIP_FILE_REGEX}")

    DEBUG "VECTR zip file name: $VECTR_ZIP_FILE"
    echo "$VECTR_ZIP_FILE"
    FUNCEXIT
}

function extractVectrRelease ()
{
    FUNCENTRY
    sudo -u $1 unzip $2 -d $3
    FUNCEXIT
}

function makeDir ()
{
    FUNCENTRY
    mkdir -p "$1"

    echo "$(dirExists "$1")"
    FUNCEXIT
}

function dirPermsCheck ()
{
    FUNCENTRY
    local VECTR_USER=$1
    local CHECK_DIR=$2

    if sudo -u $VECTR_USER [ -w "$CHECK_DIR" ] && sudo -u $VECTR_USER [ -r "$CHECK_DIR" ]; then
        echo 1
    else
        INFO "User: $VECTR_USER doesnt have r/w access to $2"
        echo 0
    fi
    FUNCEXIT
}

function fixDirPerms ()
{
    FUNCENTRY
    chown $1:$1 $2 -R
    FUNCEXIT
}

function verifyVectrRelease ()
{
    FUNCENTRY
    if [ ! -d "$1/backup" ]; then

        ERROR "VECTR temp extract dir $1/backup folder does not exist."
        return 1
    fi

    if [ ! -d "$1/config" ]; then
        ERROR "VECTR temp extract dir $1/config folder does not exist."
        return 2
    fi

    if [ ! -f "$1/config/vectr.properties" ]; then
        ERROR "vectr.properties config file doesn't exist in $1/config folder."
        return 3
    fi

    if [ ! -d "$1/dumpfiles" ]; then
        ERROR "VECTR temp extract dir $1/dumpfiles folder does not exist."
        return 4
    fi

    if [ ! -d "$1/migrationbackups" ]; then
        ERROR "VECTR temp extract dir $1/migrationbackups folder does not exist."
        return 5
    fi

    if [ ! -d "$1/migrationlogs" ]; then
        ERROR "VECTR temp extract dir $1/migrationlogs folder does not exist."
        return 6
    fi

    if [ ! -d "$1/wars" ]; then
        ERROR "VECTR temp extract dir $1/wars folder does not exist."
        return 7
    fi

    if [ ! -d "$1/wars/ROOT" ]; then
        ERROR "ERROR: VECTR temp extract dir $1/wars/ROOT folder does not exist."
        return 8
    fi

    if [ ! -f "$1/wars/sra-purpletools-rest.war" ]; then
        ERROR "ERROR: $1/wars/sra-purpletools-rest.war file doesn't exist in 'wars' folder."
        return 9
    fi

    if [ ! -f "$1/wars/sra-purpletools-webui.war" ]; then
        ERROR "ERROR: $1/wars/sra-purpletools-webui.war file doesn't exist in 'wars' folder."
        return 10
    fi

    if [ ! -f "$1/wars/ROOT/index.jsp" ]; then
        ERROR "ERROR: $1/wars/ROOT/index.jsp file doesn't exist in 'wars/ROOT' folder."
        return 11
    fi
    FUNCEXIT
}

function verifyVectrReleaseHelper ()
{
    FUNCENTRY
    if verifyVectrRelease "$1"; then
        echo 1
    else
        echo 0
    fi
    FUNCEXIT
}

function copyFilesToFolder ()
{
    FUNCENTRY
    INFO "Copying files from $1 to $2"
    cp -a $1/. $2/
    FUNCEXIT
}

function moveFilesToFolder ()
{
    FUNCENTRY
    INFO "Moving files from $1 to $2"
    local MOVE_OUTPUT="$(mv  -v $1/* $2/)"
    FUNCEXIT
}

# usage buildSelfSignedCerts "$VECTR_OS_USER" "$ENV_VECTR_HOSTNAME" "$VECTR_APP_DIR"
function buildSelfSignedCerts ()
{
    local OS_USER="$1"
    local HOSTNAME="$2"
    local VECTR_CERT_PASSWORD
    local VECTR_APP_DIR="$3"
    local CA_CERT="$4"
    local CA_KEY="$5"
    local CA_PASS="$6"

    local CA_CERT_EXISTS=$(fileExists "$CA_CERT")
    local CA_KEY_EXISTS=$(fileExists "$CA_KEY")

    local CA_CERT_LOCATION

    if [[ -z "$CA_PASS" ]]; then
        # replace output_password for CA        = !!VECTR_PASSWORD_REPLACE!!
        replaceValueInFile "$VECTR_APP_DIR/config/vectr-ca.cnf" "!!VECTR_PASSWORD_REPLACE!!" "$VECTR_CERT_PASSWORD"

        # generate CA cert
        local GENERATE_CA_KEY=$(openssl genrsa -out $VECTR_APP_DIR/config/vectrRootCA.key 4096 2>/dev/null)
        local GENERATE_CA_PEM=$(openssl req -new -x509 -days 9999 -nodes -key $VECTR_APP_DIR/config/vectrRootCA.key -sha256 -out $VECTR_APP_DIR/config/vectrRootCA.pem -config $VECTR_APP_DIR/config/vectr-ca.cnf 2>/dev/null)

        CA_CERT_LOCATION="$VECTR_APP_DIR/config/vectrRootCA.pem"
        CA_KEY_LOCATION="$VECTR_APP_DIR/config/vectrRootCA.key"
        VECTR_CERT_PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 12 | head -n 1)
    else
        VECTR_CERT_PASSWORD="$CA_PASS"
        CA_CERT_LOCATION="$CA_CERT"
        CA_KEY_LOCATION="$CA_KEY"
    fi

    replaceValueInFile "$VECTR_APP_DIR/config/vectr/vectr-app.cnf" "!!VECTR_HOSTNAME!!" "$HOSTNAME"
    replaceValueInFile "$VECTR_APP_DIR/config/vectr/v3.ext" "!!VECTR_HOSTNAME!!" "$HOSTNAME"

    # VECTR ssl certs, convert to PEM commented out at end
    local GENERATE_VECTR_APP_KEY=$(openssl req -new -sha256 -nodes -out $VECTR_APP_DIR/config/vectr-app.csr -newkey rsa:4096 -keyout $VECTR_APP_DIR/config/ssl.key -config $VECTR_APP_DIR/config/vectr/vectr-app.cnf 2>/dev/null)
    local GENERATE_VECTR_APP_CRT=$(openssl x509 -req -in $VECTR_APP_DIR/config/vectr-app.csr -CA $CA_CERT_LOCATION -CAkey $CA_KEY_LOCATION -CAcreateserial -out $VECTR_APP_DIR/config/ssl.crt -days 3650 -passin "pass:$VECTR_CERT_PASSWORD" -sha256 -extfile $VECTR_APP_DIR/config/vectr/v3.ext 2>/dev/null)
    #openssl x509 -in $VECTR_APP_DIR/config/ssl.crt -out $VECTR_APP_DIR/config/ssl.pem -outform PEM

    chown "$OS_USER" "$VECTR_APP_DIR/config" -R
}

function verifySSLCert ()
{
    FUNCENTRY
    local KEY_RESULT
    KEY_RESULT="$(openssl pkey -in "$1" -pubout -outform pem)"
    local CERT_RESULT
    CERT_RESULT="$(openssl x509 -in "$2" -pubkey -noout -outform pem)"

    local KEY_REGEX
    KEY_REGEX="(\-+BEGIN PUBLIC KEY\-+\n[A-Za-z0-9/=\n+]+\-+END PUBLIC KEY\-+)"
    #KEY_REGEX="(\n[A-Za-z0-9/=+]+)"

    local KEY_MATCH
    KEY_MATCH="$(echo "$KEY_RESULT" | grep -zoP "$KEY_REGEX" | tr '\0' '\n')"

    local CERT_MATCH
    CERT_MATCH="$(echo "$CERT_RESULT" | grep -zoP "$KEY_REGEX" | tr '\0' '\n')"

    if [[ ! -z $KEY_MATCH ]] && [[ ! -z $CERT_MATCH ]]; then
        local KEY_HASH
        KEY_HASH=$(openssl pkey -in "$1" -pubout -outform pem | sha256sum)
        local CERT_HASH
        CERT_HASH=$(openssl x509 -in "$2" -pubkey -noout -outform pem | sha256sum)

        if [ "$KEY_HASH" == "$CERT_HASH" ]; then
            echo 1
        else
            ERROR "SSL KEY and CERT check don't match"
            echo 0
        fi
    else
        ERROR "SSL KEY or CERT are empty"
        echo 0
    fi

    FUNCEXIT

    # @TODO - regex match for sha256sum
}

function writeKeyValueToEnvFile
{
    FUNCENTRY

    local FILENAME
    FILENAME=$1
    local KEYNAME
    KEYNAME=$2
    local VALUENAME
    VALUENAME=$3

    local KEY_WRITE_OUTPUT
    KEY_WRITE_OUTPUT=$(sed -i "s@^$KEYNAME=.*@$KEYNAME=$VALUENAME@" "$FILENAME")
    INFO "Writing $VALUENAME to key $KEYNAME in file $FILENAME"

    echo "$KEY_WRITE_OUTPUT"
    FUNCEXIT
}

function envFileKeyEqualsValue
{
    FUNCENTRY
    local FILENAME
    FILENAME=$1
    local KEYNAME
    KEYNAME=$2
    local VALUENAME
    VALUENAME=$3

    local KEY_REGEX="(^$KEYNAME=.*)"
    local KEY_VALUE
    KEY_VALUE=$(grep -oE "$KEY_REGEX" "$FILENAME" | cut -f2- -d=)

    INFO "Checking if Key $KEYNAME in File $FILENAME equals value: $VALUENAME, key parses to $KEYVALUE"
    if [ "$KEY_VALUE" == "$3" ] || [ "$KEY_VALUE" == "\"$3\"" ]; then
        INFO "Key matched"
        echo 1
    else
        INFO "Key did not match"
        echo 0
    fi
    FUNCEXIT
}

# the : for this is because it's generally just been for ports and volumes which end in :, probably should be changed
function yamlConfigItemExists
{
    FUNCENTRY
    local FILENAME
    FILENAME=$1
    local CONFIGITEM
    CONFIGITEM=$2

    local CONFIGITEM_REGEX="(^\s+- $CONFIGITEM:)"
    local FOUND_CONFIGITEM
    FOUND_CONFIGITEM=$(grep -oE "$CONFIGITEM_REGEX" "$FILENAME")

    if [ -z "$FOUND_CONFIGITEM" ]; then
        DEBUG "Yaml config item $CONFIGITEM not found in $FILENAME"
        echo 0
    else
        DEBUG "Yaml config item $CONFIGITEM found in $FILENAME"
        echo 1
    fi
    FUNCEXIT
}

function yamlSoloConfigItemExists
{
    FUNCENTRY
    local FILENAME
    FILENAME=$1
    local CONFIGITEM
    CONFIGITEM=$2

    local CONFIGITEM_REGEX="(^\s+- $CONFIGITEM)"
    local FOUND_CONFIGITEM
    FOUND_CONFIGITEM=$(grep -oE "$CONFIGITEM_REGEX" "$FILENAME")

    if [ -z "$FOUND_CONFIGITEM" ]; then
        INFO "Yaml solo config item $CONFIGITEM not found in $FILENAME"
        echo 0
    else
        echo 1
    fi
    FUNCEXIT
}

function yamlConfigCategoryExists
{
    FUNCENTRY
    local FILENAME
    FILENAME=$1
    local CONFIG_CATEGORY
    CONFIG_CATEGORY=$2

    local CONFIG_CATEGORY_REGEX="(^\s$CONFIG_CATEGORY:)"
    local FOUND_CONFIG_CATEGORY
    FOUND_CONFIG_CATEGORY=$(grep -oE "$CONFIG_CATEGORY_REGEX" "$FILENAME")

    if [ -z "$FOUND_CONFIG_CATEGORY" ]; then
        INFO "Yaml config category $CONFIG_CATEGORY not found in $FILENAME"
        echo 0
    else
        echo 1
    fi
    FUNCEXIT
}

function editYamlConfigItem
{
    FUNCENTRY
    local FILENAME
    FILENAME=$1
    local DEFAULT_VALUE
    DEFAULT_VALUE=$2
    local NEW_VALUE
    NEW_VALUE=$3

    local YML_WRITE_OUTPUT
    YML_WRITE_OUTPUT=$(sed -i "s@- $DEFAULT_VALUE@- $NEW_VALUE@" "$FILENAME")

    echo "$YML_WRITE_OUTPUT"
    FUNCEXIT
}

function replaceValueInFile
{
    FUNCENTRY
    local FILENAME
    FILENAME=$1
    local DEFAULT_VALUE
    DEFAULT_VALUE=$2
    local NEW_VALUE
    NEW_VALUE=$3

    local FILE_WRITE_OUTPUT
    FILE_WRITE_OUTPUT=$(sed -i "s@$DEFAULT_VALUE@$NEW_VALUE@" "$FILENAME")

    echo "$FILE_WRITE_OUTPUT"
    FUNCEXIT
}

function checkHostExists
{
    FUNCENTRY
    local HOSTNAME
    HOSTNAME=$1

    local FOUND_HOST
    FOUND_HOST=$(grep "$HOSTNAME" /etc/hosts)

    if [ -z "$FOUND_HOST" ]; then
        echo 0
    else
        echo 1
    fi
    FUNCEXIT
}

function addHost
{
    FUNCENTRY
    local HOSTS_LINE
    HOSTS_LINE="$1\t$2"
    local ADD_HOST_CMD
    INFO "Adding host to etc hosts: $2 with IP $1"
    ADD_HOST_CMD="$(echo -e "$HOSTS_LINE" >> /etc/hosts)"
    FUNCEXIT
}

function printStatusMark ()
{
    FUNCENTRY
    local RED='\033[0;31m'
    local GREEN='\033[0;32m'
    local SET='\033[0m'

    # printf %s and unicode chars not playing nice, investigate when time permits
    if [ "$1" -eq 1 ]
    then
        printf "[ ${GREEN}\xE2\x9C\x94${SET} ] "
    else
        printf "[ ${RED}X${SET} ] "
    fi
    FUNCEXIT
}

function backupConfigFiles ()
{
    FUNCENTRY
    local VECTR_DEPLOY_DIR=$1
    local CURR_TIMESTAMP="$(date +"%Y%m%d%H%M%S")"
    INFO "backing up configs to $VECTR_DEPLOY_DIR/backup/${CURR_TIMESTAMP}_confBackup.zip "
    ZIP_OUTPUT="$(zip $VECTR_DEPLOY_DIR/backup/${CURR_TIMESTAMP}_confBackup.zip $VECTR_DEPLOY_DIR/*.yml $VECTR_DEPLOY_DIR/config/*)"

    DEBUG "${ZIP_OUTPUT}"

    FUNCEXIT
}

function backupCasConfigFiles ()
{
    FUNCENTRY
    local VECTR_DEPLOY_DIR=$1
    local CAS_DEPLOY_DIR=$2
    local CURR_TIMESTAMP="$(date +"%Y%m%d%H%M%S")"
    INFO "backing up CAS configs to $VECTR_DEPLOY_DIR/backup/${CURR_TIMESTAMP}_casConfBackup.zip "
    ZIP_OUTPUT="$(zip $VECTR_DEPLOY_DIR/backup/${CURR_TIMESTAMP}_casConfBackup.zip $CAS_DEPLOY_DIR/services/*.json $CAS_DEPLOY_DIR/config/*)"

    DEBUG "${ZIP_OUTPUT}"

    FUNCEXIT
}

function writeCasServiceJsonFile ()
{
    FUNCENTRY

read -r -d '' SERVICETEMPLATE <<'EOF'
{
  "@class" : "org.apereo.cas.services.RegexRegisteredService",
  "serviceId" : "https://localhost:8081/sra-purpletools-webui/app\\?client_name=CasClient",
  "name" : "VECTR",
  "id" : 8081,
  "theme" : "sra-theme",
  "attributeReleasePolicy" : {
    "@class" : "org.apereo.cas.services.ReturnAllAttributeReleasePolicy"
  }
}
EOF
    local VECTR_HOST=$1
    local VECTR_PORT=$2
    local CAS_SERVICES_DIR=$3
    local SERVICE_FILENAME=$4

    local SERVICE_DATA
    SERVICE_DATA=$(sed "s/localhost/$VECTR_HOST/g" <<<"$SERVICETEMPLATE")
    if [[ "$VECTR_PORT" == "443" ]]; then
        SERVICE_DATA=$(sed "s/:8081//g" <<<"$SERVICE_DATA")
    fi

    SERVICE_DATA=$(sed "s/8081/$VECTR_PORT/g" <<<"$SERVICE_DATA")

    echo "$SERVICE_DATA" > "$CAS_SERVICES_DIR/$SERVICE_FILENAME"

    FUNCEXIT
}

# replaceDockerNetworkNameWithAlias $DEFAULT_VECTR_NETWORK_NAME $ENV_VECTR_HOSTNAME $DOCKER_COMPOSE_FILENAME
function replaceDockerNetworkNameWithAlias ()
{
    FUNCENTRY
    local DOCKER_DEFAULT_NETWORK_NAME=$1
    local VECTR_HOSTNAME=$2
    local FILENAME=$3
    local DOCKER_NETWORK_CONF_DATA

# there has to be a better way to do this, tried with actual newlines and replacing but wasn't getting anywhere
read -r -d '' NETWORK_TEMPLATE <<'EOF'
      vectr_bridge:\n        aliases:\n          - !!VECTR_HOSTNAME!!
EOF

    DOCKER_NETWORK_CONF_DATA=$(sed "s/!!VECTR_HOSTNAME!!/$VECTR_HOSTNAME/g" <<<"$NETWORK_TEMPLATE")

    local DOCKER_COMPOSE_WRITE_OUTPUT
    DOCKER_COMPOSE_WRITE_OUTPUT=$(sed -i "s@- $DOCKER_DEFAULT_NETWORK_NAME@$DOCKER_NETWORK_CONF_DATA@" "$FILENAME")

    echo "$DOCKER_COMPOSE_WRITE_OUTPUT"

    FUNCEXIT
}
