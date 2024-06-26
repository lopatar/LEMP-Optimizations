GLOBAL_UPPERCASE=""
CURRENT_TIME=""

SEPARATOR_STRING="------------------------------------------"

function addPhpRepository()
{
  aptWrap "install" "lsb-release"

  printLine "Downloading deb.sury.org keyring" "APT-Security"
  curl -sSLo /tmp/debsuryorg-archive-keyring.deb https://packages.sury.org/debsuryorg-archive-keyring.deb

  printLine "Installing deb.sury.org keyring" "APT-Security"
  dpkg -i /tmp/debsuryorg-archive-keyring.deb

  printLine "Adding PHP repository: packages.sury.org/php/" "PHP"
  sh -c 'echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list'

  aptWrap "update"
}

function removeOldLogFile
{
  rmWrap "${LOG_FILE}"
}

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

function logToFile()
{
  local LOG_TYPE=${1}
  local LOG_MODULE=${2}
  local LOG_OUTPUT_FILE=${3}
  local LOG_TEXT=${4}

  convertToUppercase "$LOG_TYPE"
  LOG_TYPE=$GLOBAL_UPPERCASE

  convertToUppercase "$LOG_MODULE"
  LOG_MODULE=$GLOBAL_UPPERCASE

  getCurrentTime

  local MESSAGE="[${LOG_TYPE}] [${LOG_MODULE}] [${CURRENT_TIME}] - ${LOG_TEXT}"
  echo "${MESSAGE}" | tee -a "${LOG_OUTPUT_FILE}"
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
  systemctlWrap "restart" "dphys-swapfile.service"

  ## End configure SWAP

  ## RC.LOCAL
  if [[ ! -f /etc/rc.local ]]; then
    echo "rc.local does not exist"
  fi
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
  cp -fr "${MARIADB_FOLDER}"-*/* "${MARIADB_BUILD_FOLDER}"

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
    systemctlWrap "enable" "${SERVICE_NAME}"

    printLine "Starting ${SERVICE_NAME} service" "Systemd"
    systemctlWrap "start" "${SERVICE_NAME}"
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
  local SOFTWARE=${2}

  logToFile "LOG" "${SOFTWARE}" "${LOG_FILE}" "${MESSAGE}"
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
  aptWrap "install" $PACKAGE_STRING
}

function installPackages()
{
    printLine "Installing required packages" "Build-Installer"

    printLine "Updating repositories & upgrading packages" "Build Installer"
    updateUpgrade

    installPackage "ca-certificates"
    installPackage "devscripts build-essential ninja-build libsystemd-dev apt-transport-https curl dpkg-dev gnutls-bin libgnutls28-dev libbrotli-dev clang passwd perl perl-doc python3 certbot python3-certbot python3-certbot-dns-standalone dphys-swapfile openjdk-17-jre openjdk-17-jdk clang"
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
  if [[ -z $2 ]]; then
    systemctl -q -f "${1}"
  else
    systemctl -q -f "${1}" "${2}"
  fi
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
    apt-get $APT_ARGS "${ACTION}"
  else
    apt-get $APT_ARGS "${ACTION}" "${PACKAGE}"
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

# shellcheck disable=SC2120
function die()
{
  if [[ -z $1 ]]; then
    printLine "Exiting" "Core"
  else
    printLine "Exiting [REASON: ${1}]" "Core"
  fi

  set -e
  false

  ## In case the first method does not work

  set -o pipefail
  # shellcheck disable=SC2216
  false | true
}
