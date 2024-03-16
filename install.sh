#!/bin/zsh

## User configuration

LOG_ENABLED=1
LOG_FOLDER="logs"
LOG_FILENAME="lemp-build.log"
LOG_ERRFILENAME="+"
LOG_TIMEZONE="Europe/Prague"

## End user configuration
LOG_FILE="${LOG_FOLDER}/${LOG_FILENAME}"

source build/helpers.sh

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

CC=$C_COMPILER
CXX=$CXX_COMPILER

INSTALL_PATH="$(pwd)/build"
CONF_PATH="${INSTALL_PATH}/conf"
SERVICES_PATH="${INSTALL_PATH}/services"

printLine "Base LEMP compiler folder ${INSTALL_PATH}" "Info"
printLine "LEMP module configuration files ${CONF_PATH}" "Info"
printLine "LEMP systemd system services ${SERVICES_PATH}" "Info"

PARALLEL_TASKS=$(nproc --all)
printLine "CPU thread count: ${PARALLEL_TASKS}" "Performance"

SYSTEMD_SERVICES_PATH="/usr/lib/systemd/system"
printLine "OS systemd services path ${SYSTEMD_SERVICES_PATH}" "Systemd"

source build/packageConfig.sh

cd build || die
deleteCache

chmod +x build/build.sh
source build.sh
