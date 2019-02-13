#!/bin/bash

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
    cp -a $1/. $2/
    FUNCEXIT
}

# usage $(generateSelfSignedCert $COUNTRY $STATE $LOCALITY $ORG $HOSTNAME $DEPLOY_DIR)
function generateSelfSignedCert ()
{
    FUNCENTRY
    local COUNTRY=$1
    local STATE=$2
    local LOCALITY=$3
    local ORG=$4
    local HOSTNAME=$5
    local DEPLOY_DIR=$6
    local CERT_FILENAME=$7

    local CERTGEN_OUTPUT
    CERTGEN_OUTPUT=$(openssl req -new -newkey rsa:4096 -days 3650 -nodes -x509 -subj "/C=$COUNTRY/ST=$STATE/L=$LOCALITY/O=$ORG/CN=$HOSTNAME" -keyout $DEPLOY_DIR/config/$CERT_FILENAME.key -out $DEPLOY_DIR/config/$CERT_FILENAME.crt 2>/dev/null)

    echo "$CERTGEN_OUTPUT"
    FUNCEXIT
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
        INFO "Yaml config item $CONFIGITEM not found in $FILENAME"
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


