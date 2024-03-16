#!/bin/zsh

## User configuration

# shellcheck disable=SC2034
LOG_ENABLED=1
LOG_TIMEZONE="Europe/Prague"

LOG_FOLDER="logs"
LOG_STDERR_FILENAME="script-stderr.log"
LOG_STDOUT_FILENAME="script-stdout.log"
LOG_FILENAME="script-logger.log"

## End user configuration
# shellcheck disable=SC2034
LOG_FILE="${LOG_FOLDER}/${LOG_FILENAME}"
# shellcheck disable=SC2034
LOG_STDERR_FILE="${LOG_FOLDER}/${LOG_STDERR_FILENAME}"
# shellcheck disable=SC2034
LOG_STDOUT_FILE="${LOG_FOLDER}/${LOG_STDOUT_FILENAME}"

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
source build.sh > ${LOG_STDOUT_FILENAME} 2> ${LOG_STDERR_FILENAME}
