#!/bin/zsh

unsetopt MULTIOS

REPO_FOLDER=$(pwd)

# shellcheck disable=SC2034
LOG_TIMEZONE="Europe/Prague"

LOG_FOLDER=$REPO_FOLDER/logs
LOG_FILENAME="lemp-script.log"

# shellcheck disable=SC2034
LOG_FILE=$LOG_FOLDER/$LOG_FILENAME

source build/helpers.sh
printLine "!!!!!!!!!!! SCRIPT STARTED !!!!!!!!!!!"

printHeader

prepareLogging
removeOldLogFile

checkRoot

printLine "Loading configuration" "Init"
source ./config.sh
printConfiguration
purgeManagerPackages
installPackages
kernelTuning

export CC=$C_COMPILER
export CXX=$CXX_COMPILER

INSTALL_PATH="${REPO_FOLDER}/build"
CONF_PATH="${INSTALL_PATH}/conf"
SERVICES_PATH="${INSTALL_PATH}/services"

printLine "Base LEMP compiler folder ${INSTALL_PATH}" "Info"
printLine "LEMP module configuration files ${CONF_PATH}" "Info"
printLine "LEMP systemd system services ${SERVICES_PATH}" "Info"

PARALLEL_TASKS=$(nproc --all)
printLine "CPU thread count: ${PARALLEL_TASKS}" "Performance"

SYSTEMD_SERVICES_PATH="/usr/lib/systemd/system"
printLine "OS systemd services path ${SYSTEMD_SERVICES_PATH}" "Systemd"

cd build || die
source packageConfig.sh
deleteCache

chmod +x build.sh
source build.sh
