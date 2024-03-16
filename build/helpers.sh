GLOBAL_UPPERCASE=""
CURRENT_TIME=""
SEPARATOR_STRING="------------------------------------------"

function getCurrentTime()
{
  CURRENT_TIME=$(TZ="${LOG_TIMEZONE}" date)
  convertToUppercase "$CURRENT_TIME"
  CURRENT_TIME=${GLOBAL_UPPERCASE}
}

function prepareLogging()
{
  mkdirWrap "${LOG_FOLDER}"
  printLine "Prepared logging system" "Logging"
}

function logStdErr()
{
    read -r -s STDERR_DATA
    echo "$STDERR_DATA" | tee -a "${LOG_STDERR_FILE}"
}

function logToFile()
{
  local MESSAGE="[LOG] ${1}"
  echo "${MESSAGE}" | tee -a "${LOG_FILE}"
}

function removeOldLogFile()
{
  printLine "Removing old logfile ${LOG_FILE}" "Cleanup"
  rmWrap "$LOG_FILE"

  printLine "Removing old logfile ${LOG_STDERR_FILE}" "Cleanup"
  rmWrap "$LOG_STDERR_FILE"
}

function buildModule() {
    local FUNC_FOLDER=${1}
    local FUNC_URL=${2}
    local FUNC_BUILD_ARGS=${3}

    if [[ $FUNC_URL == *.bz2 ]]; then
        FUNC_ARCHIVE_NAME=${FUNC_FOLDER}.tar.bz2
    elif [[ $FUNC_URL == *.gz ]]; then
        FUNC_ARCHIVE_NAME=${FUNC_FOLDER}.tar.gz
    else
        FUNC_ARCHIVE_NAME=".git.clone"
    fi

    if [[ $FUNC_ARCHIVE_NAME == *.tar.?z* ]]; then
        printLine "Downloading ${FUNC_FOLDER} from ${FUNC_URL}}" "Module-Installer"
        wget "${FUNC_URL}" -O ${FUNC_ARCHIVE_NAME} --max-redirect=1 -nv --no-proxy -q

        printLine "Creating extraction folder ${FUNC_FOLDER} for ${FUNC_FOLDER}" "Module-Installer"
        mkdir "${FUNC_FOLDER}"

        printLine "Extracting ${FUNC_ARCHIVE_NAME} to ./${FUNC_FOLDER}" "Module-Installer"
        tar -xf ${FUNC_ARCHIVE_NAME} -C "./${FUNC_FOLDER}" --strip-components=1

        printLine "Removing old ${FUNC_ARCHIVE_NAME}" "Module-Cleanup"
        rmWrap "${FUNC_ARCHIVE_NAME}"
    else
        printLine "Cloning ${FUNC_FOLDER} from ${FUNC_URL}" "Module-Installer"
        git clone --recurse-submodules -j"${PARALLEL_TASKS}" "${FUNC_URL}"
    fi

    if [[ -n $FUNC_BUILD_ARGS ]]; then
        printLine "Entering ${FUNC_FOLDER} folder" "Core"
        cd "${FUNC_FOLDER}" || die

        printLine "Executing ${FUNC_FOLDER} build arguments" "Compiler"
        eval "${FUNC_BUILD_ARGS}"
        cd ../
    fi
}

function kernelTuning()
{
  printLine "Doing system tuning" "Core"

  # shellcheck disable=SC2155
  local ROOT_MOUNT=$(findmnt -n / | awk '{ print $2 }')
  # shellcheck disable=SC2155
  local SYSTEM_DEVICE=$(lsblk -no pkname "${ROOT_MOUNT}")

  printLine "Setting mq-deadline scheduler for ${SYSTEM_DEVICE}" "IO-Optimization"
  echo mq-deadline > "/sys/block/${SYSTEM_DEVICE}/queue/scheduler"

  ## Configure SWAP

  if [[ $SWAP_ENABLE == 1 ]]; then
      printLine "Configuring SWAP with factor: ${SWAP_FACTOR} and max: ${SWAP_MAX_MB}" "ram-optimizer"
      echo -e "CONF_SWAPFACTOR=${SWAP_FACTOR}\nCONF_MAXSWAP=${SWAP_MAX_MB}" > /etc/dphys-swapfile
  else
    printLine "Uninstalling SWAP" "MEMORY-Optimization"
    dphys-swapfile uninstall
  fi

  printLine "Restarting dphys-swapfile.service" "MEMORY-Optimization"
  systemctlWrap "restart dphys-swapfile.service"

  ## End configure SWAP

  # shellcheck disable=SC2155
  local SYSCTL_CONFIG=$(sysctl -a)

  if [[ -z $(echo "${SYSCTL_CONFIG}" | grep -s "vm.overcommit_memory = 1") ]]; then
    printLine "Setting vm.overcommit_memory = 1" "MEMORY-Optimization"
    echo "vm.overcommit_memory = 1" >> /etc/sysctl.conf
  fi

  if [[ -z $(echo "${SYSCTL_CONFIG}" | grep -s "vm.swappiness = 1") ]]; then
    printLine "Setting vm.swappiness = 1" "IO-Optimization"
    echo "vm.swappiness = 1" >> /etc/sysctl.conf
  fi

  if [[ -z $(echo "${SYSCTL_CONFIG}" | grep -s "net.ipv4.ip_unprivileged_port_start = 1024") ]]; then
    printLine "Setting net.ipv4.ip_unprivileged_port_start = 1024" "NETWORK-Optimization"
    echo "net.ipv4.ip_unprivileged_port_start = 1024" >> /etc/sysctl.conf
  fi

  if [[ -z $(echo "${SYSCTL_CONFIG}" | grep -s "fs.file-max = 524280") ]]; then
    printLine "Setting fs.file-max = 524280" "IO-Optimization"
    echo "fs.file-max = 524280" >> /etc/sysctl.conf
  fi

  printLine "Disabling hugepages & defrag" "MEMORY-Optimization"
  echo never | tee /sys/kernel/mm/transparent_hugepage/enabled /sys/kernel/mm/transparent_hugepage/defrag > /dev/null

  printLine "Reloading systemd configuration" "Systemd"
  sysctl -p -q
}

function getMariaDbSource()
{
  mkdir -p /etc/apt/keyrings

  printLine "Getting MariaDB deb-src signing key" "MariaDB"
  wget -O "/etc/apt/keyrings/${MARIADB_FOLDER}-keyring.pgp" ${MARIADB_SIGNING_KEY_URL} -nv --no-proxy -q

  printLine "Creating MariaDB deb-src entry" "MariaDB"
  echo "deb-src [signed-by=/etc/apt/keyrings/${MARIADB_FOLDER}-keyring.pgp] https://deb.${MARIADB_FOLDER}.org/${MARIADB_VERSION}/debian bookworm main" > /etc/apt/sources.list.d/${MARIADB_FOLDER}.list

  printLine "Updating & upgrading package repositories" "Build-Installer"
  updateUpgrade
  printLine "Installing required packages to build MariaDB" "Build-Installer"
  aptWrap "build-dep" "${MARIADB_FOLDER}-server"

  printLine "Dowloading MariaDB source code" "MariaDB"
  aptWrap "source" "${MARIADB_FOLDER}-server"

  printLine "Creating folder ${MARIADB_BUILD_FOLDER}" "MariaDB"
  mkdir -p "${MARIADB_BUILD_FOLDER}"

  printLine "Moving original MariaDB data to build folder" "MariaDB"
  mv "${MARIADB_FOLDER}"-*/* "${MARIADB_FOLDER}"

  printLine "Removing: $(ls "${MARIADB_FOLDER}"*.*)" "Cleanup"
  rmWrap "${MARIADB_FOLDER}"*.*

  printLine "Entering ${MARIADB_BUILD_FOLDER}" "MariaDB"
  cd "${MARIADB_BUILD_FOLDER}" || exit
}

function convertToUppercase()
{
  GLOBAL_UPPERCASE=${${1}:u}
}

function enableService() {
    local SERVICE_NAME=${1}
    printLine "Installing ${SERVICE_NAME} service" "Systemd"

    printLine "Reloading systemd daemon" "Systemd"
    systemctlWrap "daemon-reload"

    printLine "Enabling ${SERVICE_NAME} service" "Systemd"
    systemctlWrap "enable ${SERVICE_NAME}"

    printLine "Starting ${SERVICE_NAME} service" "Systemd"
    systemctlWrap "start ${SERVICE_NAME}"
}

function deleteCache()
{
    printLine "Deleting old/cached files" "Cache"

    for FILE in *
    do
        if [[ $FILE == conf || $FILE == services || $FILE == *.md || $FILE == *.sh || $FILE == .log ]]; then
            continue
        fi

        printLine "Deleted old/cached file ${FILE}" "Cache"
        rmWrap "${FILE}"
    done
}

function printLine()
{
  local MESSAGE=${1}

  convertToUppercase "${2}"
  local SOFTWARE=${GLOBAL_UPPERCASE}

  convertToUppercase "$MESSAGE"
  MESSAGE=${GLOBAL_UPPERCASE}

  getCurrentTime

  MESSAGE="[${SOFTWARE}] [${CURRENT_TIME}] - ${MESSAGE}"

  if [[ $LOG_ENABLED == 1 ]]; then
    logToFile "${MESSAGE}"
  else
    echo "${MESSAGE}"
  fi
}

function purgePackage()
{
  local PACKAGE_NAME=${1}

  printLine "Stopping services matching regex ${PACKAGE_NAME}*.service" "Cleanup"
  service "$PACKAGE_NAME"\* stop

  printLine "Removing packages matching regex ^${PACKAGE_NAME}" "Cleanup"

  aptWrap "remove" "^${PACKAGE_NAME}"
}

function installPackage()
{
  local PACKAGE_STRING=${1}

  printLine "Installing ${PACKAGE_STRING}" "Build-Installer"
  aptWrap "install" "${PACKAGE_STRING}"
}

function installPackages()
{
    printLine "Installing required packages" "Build-Installer"

    printLine "Updating repositories & upgrading packages" "Build Installer"
    updateUpgrade

    installPackage "ca-certificates"
    installPackage "devscripts build-essential ninja-build libsystemd-dev apt-transport-https curl dpkg-dev gnutls-bin libgnutls28-dev libbrotli-dev clang passwd perl perl-doc python3 certbot python3-certbot python3-certbot-dns-standalone python3-certbot-nginx dphys-swapfile openjdk-17-jre openjdk-17-jdk"
}

function purgeManagerPackages()
{
  printLine "Removing package manager installed packages that are going to be replaced" "Cleanup"

  if [[ $USE_NGINX == 1 ]]; then
      purgePackage "nginx"
  fi

  if [[ $USE_MARIADB == 1 ]]; then
      purgePackage "mariadb"
      purgePackage "mysql"
  fi

  if [[ $USE_REDIS == 1 ]]; then
      purgePackage "redis"
  fi
}

function printHeader()
{
  echo $SEPARATOR_STRING

  echo "This script was made by Jiří Lopatář"
  echo "https://github.com/lopatar/LEMP-Optimizations"
  echo "https://linkedin.com/in/lopatar-jiri"

  echo $SEPARATOR_STRING
}

function checkRoot()
{
  printLine "Checking for root privileges" "Core"

  if [[ $EUID != 0 ]]; then
      printLine "Must be run as root!" "Core"
      die
  fi
}

function systemctlWrap()
{
  systemctl -q -f "${1}"
}

function rmWrap()
{
  rm -rfd --interactive=never "${1}"
}

function aptWrap()
{
  local ACTION=${1}
  local PACKAGE=${2}

  ## For later expansion until i find a way to use the proper flags.
  local APT_ARGS="-qq"

  if [[ -z $PACKAGE ]]; then
    apt-get $APT_ARGS $ACTION
  else
    apt-get $APT_ARGS $ACTION $PACKAGE
  fi

}

function updateUpgrade()
{
  aptWrap "update"
  aptWrap "upgrade"
}

function mkdirWrap()
{
  mkdir -p "${1}"
}

function die()
{
  printLine "Exiting" "Core"

  set -e
  false

  ## In case the first method does not work

  set -o pipefail
  # shellcheck disable=SC2216
  false | true
}
