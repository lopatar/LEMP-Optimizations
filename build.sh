#!/bin/zsh
## Essential utils

LOG_ENABLED=1
LOG_FILE="LEMP-build.log"

function logToFile()
{
  local CURRENT_DATE=$(date)
  local MESSAGE="LOG [${CURRENT_DATE}]: ${1}"
  echo "${MESSAGE}" | tee -a "${LOG_FILE}"
}

function printLine()
{
  local MESSAGE="${1}......"

  if [[ $LOG_ENABLED == 1 ]]; then
    logToFile "${MESSAGE}"
  else
    echo "${MESSAGE}"
  fi
}

function die()
{
  printLine "Exiting"

  set -e
  /bin/false
}

function checkRoot()
{
  printLine "Checking for root"

  if [[ $EUID != 0 ]]; then
      printLine "Must be run as root!"
      die
  fi
}

## End essential utils

## Configuration

rm -rf "${LOG_FILE}"
checkRoot

printLine "Loading configuration"
source ./config.sh
printConfiguration

## End configuration

PARALLEL_TASKS=$(nproc)
printLine "Detected parallel tasks: ${PARALLEL_TASKS}"

function purgePackage()
{
  local PACKAGE_NAME="${1}*"
  printLine "Removing ${PACKAGE_NAME}"

  apt remove "${PACKAGE_NAME}" -yq
}

function purgeManagerPackages()
{
  printLine "Removing package manager installed packages that are going to be replaced"

  if [[ $USE_OPENSSL == 1 ]]; then
    purgePackage "openssl"
  fi

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

function deleteCache()
{
    printLine "Deleting cache files"

    for FILE in *
    do
        if [[ $FILE == conf || $FILE == services || $FILE == *.md || $FILE == *.sh ]]; then
            continue
        fi

        printLine "Deleted cache file ${FILE}"
        rm -rf "${FILE}"
    done
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
        printLine "Downloading ${FUNC_FOLDER} from ${FUNC_URL}"
        wget "${FUNC_URL}" -O ${FUNC_ARCHIVE_NAME} --max-redirect=1

        printLine "Creating extraction folder ${FUNC_FOLDER} for ${FUNC_FOLDER}"
        mkdir "${FUNC_FOLDER}"

        printLine "Extracting ${FUNC_ARCHIVE_NAME} to ./${FUNC_FOLDER}"
        tar -xf ${FUNC_ARCHIVE_NAME} -C "./${FUNC_FOLDER}" --strip-components=1

        printLine "Removing old ${FUNC_ARCHIVE_NAME}"
        rm -rf ${FUNC_ARCHIVE_NAME}
    else
        printLine "Cloning ${FUNC_FOLDER} from ${FUNC_URL}"
        git clone --recurse-submodules -j${PARALLEL_TASKS} ${FUNC_URL}
    fi
    
    if [[ -n $FUNC_BUILD_ARGS ]]; then
        printLine "Entering ${FUNC_FOLDER} folder"
        cd "${FUNC_FOLDER}" || die

        printLine "Executing ${FUNC_FOLDER} build arguments"
        eval "${FUNC_BUILD_ARGS}"
        cd ../
    fi
}

function enableService() {
    local SERVICE_NAME=${1}
    printLine "Installing ${SERVICE_NAME} service"

    printLine "Reloading systemd daemon"
    systemctl daemon-reload

    printLine "Enabling ${SERVICE_NAME} service"
    systemctl enable "${SERVICE_NAME}"

    printLine "Starting ${SERVICE_NAME} service"
    systemctl start "${SERVICE_NAME}"
}

function kernelTuning()
{
  printLine "Doing system tuning"

  # shellcheck disable=SC2155
  local ROOT_MOUNT=$(findmnt -n / | awk '{ print $2 }')
  # shellcheck disable=SC2155
  local SYSTEM_DEVICE=$(lsblk -no pkname "${ROOT_MOUNT}")

  printLine "Setting mq-deadline scheduler for ${SYSTEM_DEVICE}"
  echo mq-deadline > "/sys/block/${SYSTEM_DEVICE}/queue/scheduler"

  ## Configure SWAP

  if [[ $SWAP_ENABLE == 1 ]]; then
      printLine "Configuring SWAP with factor: ${SWAP_FACTOR} and max: ${SWAP_MAX_MB}"
      echo -e "CONF_SWAPFACTOR=${SWAP_FACTOR}\nCONF_MAXSWAP=${SWAP_MAX_MB}" > /etc/dphys-swapfile
  else
    printLine "Uninstalling SWAP"
    dphys-swapfile uninstall
  fi

  printLine "Restarting dphys-swapfile.service"
  systemctl restart dphys-swapfile.service

  ## End configure SWAP

  # shellcheck disable=SC2155
  local SYSCTL_CONFIG=$(sysctl -a)

  if [[ -z $(echo "${SYSCTL_CONFIG}" | grep "vm.overcommit_memory = 1") ]]; then
    printLine "Setting vm.overcommit_memory = 1"
    echo "vm.overcommit_memory = 1" >> /etc/sysctl.conf
  fi

  if [[ -z $(echo "${SYSCTL_CONFIG}" | grep "vm.swappiness = 1") ]]; then
    printLine "Setting vm.swappiness = 1"
    echo "vm.swappiness = 1" >> /etc/sysctl.conf
  fi

  if [[ -z $(echo "${SYSCTL_CONFIG}" | grep "net.ipv4.ip_unprivileged_port_start = 1024") ]]; then
    printLine "Setting net.ipv4.ip_unprivileged_port_start = 1024"
    echo "net.ipv4.ip_unprivileged_port_start = 1024" >> /etc/sysctl.conf
  fi

  if [[ -z $(echo "${SYSCTL_CONFIG}" | grep "fs.file-max = 524280") ]]; then
    printLine "Setting fs.file-max = 524280"
    echo "fs.file-max = 524280" >> /etc/sysctl.conf
  fi

  printLine "Disabling hugepages & defrag"
  echo never | tee /sys/kernel/mm/transparent_hugepage/enabled /sys/kernel/mm/transparent_hugepage/defrag > /dev/null

  printLine "Reloading systemd configuration"
  sysctl -p
}

function installPackage()
{
  local PACKAGE_STRING=${1}

  printLine "Installing ${PACKAGE_NAME}"
  apt install -yq --no-install-suggests --fix-broken "${PACKAGE_STRING}"
}

function installPackages()
{
    printLine "Installing required packages"

    printLine "Updating repositories & upgrading packages"
    apt update && apt upgrade -yq

    installPackage "ca-certificates"
    installPackage "devscripts build-essential ninja-build libsystemd-dev apt-transport-https curl dpkg-dev gnutls-bin libgnutls28-dev libbrotli-dev clang passwd perl perl-doc python3 certbot python3-certbot python3-certbot-dns-standalone python3-certbot-nginx dphys-swapfile openjdk-17-jre openjdk-17-jdk"
}

INSTALL_PATH=$(pwd)
CONF_PATH="${INSTALL_PATH}/conf"
SERVICES_PATH="${INSTALL_PATH}/services"

SYSTEMD_SERVICES_PATH="/usr/lib/systemd/system"

## End internal utils

## Start module configuration

CC=/usr/bin/clang
CXX=/usr/bin/clang++

JEMALLOC_FOLDER="jemalloc"
JEMALLOC_URL="https://github.com/jemalloc/jemalloc/releases/download/${JEMALLOC_VERSION}/jemalloc-$JEMALLOC_VERSION.tar.bz2"
JEMALLOC_BUILD_ARGS="CC=/usr/bin/clang EXTRA_CFLAGS='-mtune=${M_TUNE} -DADLER32_SIMD_NEON -DINFLATE_CHUNK_SIMD_NEON -DINFLATE_CHUNK_READ_64LE -O3 -D_LARGEFILE64_SOURCE=1 -DHAVE_HIDDEN -funroll-loops -fPIC' CXX=/usr/bin/clang++ EXTRA_CXXFLAGS='-mtune=${M_TUNE} -DADLER32_SIMD_NEON -DINFLATE_CHUNK_SIMD_NEON -DINFLATE_CHUNK_READ_64LE -Ofast -D_LARGEFILE64_SOURCE=1 -DHAVE_HIDDEN -funroll-loops -fPIC' ./configure && make -j${PARALLEL_TASKS} && make install"

ZLIB_FOLDER="zlib"
ZLIB_URL="https://github.com/cloudflare/zlib/archive/refs/tags/v${ZLIB_VERSION}.tar.gz"
ZLIB_BUILD_ARGS="CC=/usr/bin/clang CFLAGS='-mtune=${M_TUNE} -DADLER32_SIMD_NEON -DINFLATE_CHUNK_SIMD_NEON -DINFLATE_CHUNK_READ_64LE -O3 -D_LARGEFILE64_SOURCE=1 -DHAVE_HIDDEN -funroll-loops -fPIC' CPP=/usr/bin/clang++ SFLAGS='-mtune=${M_TUNE} -DADLER32_SIMD_NEON -DINFLATE_CHUNK_SIMD_NEON -DINFLATE_CHUNK_READ_64LE -Ofast -D_LARGEFILE64_SOURCE=1 -DHAVE_HIDDEN -funroll-loops -fPIC' LD_LIBRARY_PATH=/usr/local/lib LDFLAGS='-L/usr/local/lib -l:libjemalloc.a' ./configure && make -j${PARALLEL_TASKS} && make install"

LIBATOMIC_FOLDER="libatomic"
LIBATOMIC_URL="https://github.com/ivmai/libatomic_ops/releases/download/v${LIBATOMIC_VERSION}/libatomic_ops-$LIBATOMIC_VERSION.tar.gz"
LIBATOMIC_BUILD_ARGS="LT_SYS_LIBRARY_PATH=/usr/local/lib LD_LIBRARY_PATH=/usr/local/lib LDFLAGS='-L/usr/local/lib -l:libjemalloc.a' CC=/usr/bin/clang CCAS=/usr/bin/clang CCASFLAGS='-mtune=${M_TUNE} -DADLER32_SIMD_NEON -DINFLATE_CHUNK_SIMD_NEON -Ofast -funroll-loops -fPIC' CFLAGS='-mtune=${M_TUNE} -DADLER32_SIMD_NEON -DINFLATE_CHUNK_SIMD_NEON -Ofast -funroll-loops -fPIC' CPPFLAGS='-mtune=${M_TUNE} -DADLER32_SIMD_NEON -DINFLATE_CHUNK_SIMD_NEON -Ofast -funroll-loops -fPIC' ./configure && make -j${PARALLEL_TASKS} && make install"

PCRE2_FOLDER="libpcre"
PCRE2_URL="https://github.com/PCRE2Project/pcre2/releases/download/pcre2-${PCRE2_VERSION}/pcre2-${PCRE2_VERSION}.tar.gz"
PCRE2_BUILD_ARGS="LT_SYS_LIBRARY_PATH=/usr/local/lib LD_LIBRARY_PATH=/usr/local/lib LDFLAGS='-L/usr/local/lib -l:libjemalloc.a -l:libz.a' CC=/usr/bin/clang CFLAGS='-mtune=${M_TUNE} -DADLER32_SIMD_NEON -DINFLATE_CHUNK_SIMD_NEON -DINFLATE_CHUNK_READ_64LE -Ofast -D_LARGEFILE64_SOURCE=1 -DHAVE_HIDDEN -funroll-loops -fPIC' CPPFLAGS='-mtune=${M_TUNE} -DADLER32_SIMD_NEON -DINFLATE_CHUNK_SIMD_NEON -DINFLATE_CHUNK_READ_64LE -O3 -D_LARGEFILE64_SOURCE=1 -DHAVE_HIDDEN -funroll-loops -fPIC' ./configure --enable-pcre2grep-libz --enable-jit --enable-pcre2-16 --enable-pcre2-32 && make -j${PARALLEL_TASKS} && make install"

GOLANG_FOLDER="golang"
GOLANG_URL="https://dl.google.com/go/go${GOLANG_VERSION}.linux-amd64.tar.gz"
GO_BIN="${INSTALL_PATH}/${GOLANG_FOLDER}/bin"

BORINGSSL_FOLDER="boringssl"
BORINGSSL_URL="https://boringssl.googlesource.com/boringssl"
BORINGSSL_BUILD_ARGS="cmake -GNinja -B build -DOPENSSL_SMALL=1 -DGO_EXECUTABLE=${GO_BIN}/go -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER=/usr/bin/clang -DCMAKE_CXX_COMPILER=/usr/bin/clang++ -DCMAKE_C_FLAGS_INIT='-mtune=${M_TUNE} -DADLER32_SIMD_NEON -DINFLATE_CHUNK_SIMD_NEON -DINFLATE_CHUNK_READ_64LE -O3 -D_LARGEFILE64_SOURCE=1 -DHAVE_HIDDEN -funroll-loops' -DCMAKE_CXX_FLAGS_INIT='-mtune=${M_TUNE} -DADLER32_SIMD_NEON -DINFLATE_CHUNK_SIMD_NEON -DINFLATE_CHUNK_READ_64LE -O3 -D_LARGEFILE64_SOURCE=1 -DHAVE_HIDDEN -funroll-loops' -DCMAKE_SHARED_LINKER_FLAGS_INIT='-L/usr/local/lib -l:libjemalloc.a' && ninja -j${PARALLEL_TASKS} -C build"

OPENSSL_FOLDER="openssl"
OPENSSL_URL="https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz"
OPENSSL_BUILD_ARGS="KERNEL_BITS=64 ./config -Wno-free-nonheap-object no-weak-ssl-ciphers no-docs no-legacy no-ssl3 no-tests enable-brotli enable-ktls no-unit-test threads thread-pool default-thread-pool zlib -DOPENSSL_SMALL=1 -DOPENSSL_NO_HEARTBEATS -O3 -mtune=${M_TUNE} -funroll-loops -flto=auto -ffunction-sections -fdata-sections -I/usr/local/include -fPIC -Wl,-rpath,/usr/local/lib -Wl,-ljemalloc && make -j${PARALLEL_TASKS} && make install"

NGX_BROTLI_FOLDER="ngx_brotli"
NGX_BROTLI_URL="https://github.com/google/ngx_brotli"

NGINX_FOLDER="nginx"
NGINX_URL="https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz"
NGINX_BUILD_ARGS="./configure --with-compat --with-cc-opt='-I/usr/local/include -mtune=${M_TUNE} -Ofast -ffast-math -funroll-loops -fPIE -fstack-protector-strong --param=ssp-buffer-size=4 -flto=auto -Wp,-D_FORTIFY_SOURCE=2 -Wno-implicit-fallthrough -Wno-implicit-function-declaration -Wno-discarded-qualifiers -Wno-unused-variable -Wno-error' --with-ld-opt='-L/usr/local/lib -l:libjemalloc.a -l:libatomic_ops.a -l:libpcre2-8.a -l:libz.a -mtune=${M_TUNE} -Ofast -ffast-math -funroll-loops -fPIE -fstack-protector-strong --param=ssp-buffer-size=4 -flto=auto -Wp,-D_FORTIFY_SOURCE=2 -fPIC' --prefix=/etc/nginx --sbin-path=/usr/sbin/nginx --modules-path=/etc/nginx/modules --conf-path=/etc/nginx/nginx.conf --error-log-path=/var/log/nginx/error.log --http-log-path=/var/log/nginx/access.log --pid-path=/run/nginx.pid --lock-path=/run/nginx.lock --http-client-body-temp-path=/var/cache/nginx/client_temp --http-proxy-temp-path=/var/cache/nginx/proxy_temp --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp --http-scgi-temp-path=/var/cache/nginx/scgi_temp --user=www-data --group=www-data --with-file-aio --with-threads --with-pcre --with-libatomic --with-pcre-jit --with-http_dav_module --with-http_gunzip_module --with-http_gzip_static_module --with-http_ssl_module --without-select_module --without-poll_module --without-http_mirror_module --without-http_geo_module --without-http_split_clients_module --without-http_uwsgi_module --without-http_scgi_module --without-http_grpc_module --without-http_memcached_module --without-http_empty_gif_module --without-mail_pop3_module --without-mail_imap_module --without-mail_smtp_module --without-stream_limit_conn_module --without-stream_access_module --without-stream_geo_module --without-stream_map_module --without-stream_split_clients_module --without-stream_return_module --without-stream_set_module --without-stream_upstream_hash_module --without-stream_upstream_least_conn_module --without-stream_upstream_random_module --without-stream_upstream_zone_module --with-http_v2_module --with-http_v3_module --add-dynamic-module=${INSTALL_PATH}/ngx_brotli --with-openssl=${INSTALL_PATH}/openssl --with-openssl-opt='-Wno-free-nonheap-object no-weak-ssl-ciphers no-docs no-legacy no-ssl3 no-tests' && make -j${PARALLEL_TASKS} && make install"
NGINX_SYSTEMD_SERVICE_PATH="/usr/lib/systemd/system/${NGINX_FOLDER}.service"

REDIS_FOLDER="redis"
REDIS_URL="https://github.com/redis/redis/archive/${REDIS_VERSION}.tar.gz"
REDIS_BUILD_ARGS="make USE_SYSTEMD=yes MALLLOC=jemalloc BUILD_TLS=no REDIS_CFLAGS=\"-I/usr/local/include -Ofast -funroll-loops --param=ssp-buffer-size=4 -flto=auto -mtune=${M_TUNE}\" REDIS_LDFLAGS=\"-L/usr/local/lib -l:libjemalloc.a \" -j${PARALLEL_TASKS} && make install"
REDIS_CONFIG_PATH="/etc/redis/${REDIS_FOLDER}.conf"
REDIS_SYSTEMD_SERVICE_PATH="${SYSTEMD_SERVICES_PATH}/${REDIS_FOLDER}.service"

MARIADB_FOLDER="mariadb"
MARIADB_BUILD_FOLDER="${MARIADB_FOLDER}/${MARIADB_FOLDER}-${MARIADB_VERSION}-build"
MARIADB_SIGNING_KEY_URL="https://mariadb.org/mariadb_release_signing_key.pgp"
MARIADB_BUILD_ARGS="cmake ../ -DCMAKE_C_FLAGS='-I/usr/local/include -O3 -fno-strict-aliasing -funroll-loops --param=ssp-buffer-size=4 -flto=auto -mtune=${M_TUNE}' -DCMAKE_CXX_FLAGS='-I/usr/local/include -O3 -funroll-loops --param=ssp-buffer-size=4 -flto=auto -mtune=${M_TUNE}' -DBUILD_CONFIG=mysql_release -DMYSQL_MAINTAINER_MODE=OFF -DCMAKE_EXE_LINKER_FLAGS='-l:libjemalloc.a -l:libatomic_ops.a -l:libpcre2-8.a -l:libz.a' -DWITH_SAFEMALLOC=OFF && cmake --build . -j${PARALLEL_TASKS} && make install -j${PARALLEL_TASKS}"
MARIADB_CONF_FOLDER="/etc/mysql"
MARIADB_SOCKET_FOLDER="/run/mysqld"
MARIADB_CONF_FILE="my.cnf"
MARIADB_INSTALLATION_FOLDER="/usr/local/mysql"

## End module configuration

## Start module utils

function getMariaDbSource()
{
  mkdir -p /etc/apt/keyrings
  wget -O "/etc/apt/keyrings/${MARIADB_FOLDER}-keyring.pgp" ${MARIADB_SIGNING_KEY_URL}
  echo "deb-src [signed-by=/etc/apt/keyrings/${MARIADB_FOLDER}-keyring.pgp] https://deb.${MARIADB_FOLDER}.org/${MARIADB_VERSION}/debian bookworm main" > /etc/apt/sources.list.d/${MARIADB_FOLDER}.list

  apt update && apt upgrade -y
  apt build-dep -y ${MARIADB_FOLDER}-server

  apt source ${MARIADB_FOLDER}-server

  mkdir -p "${MARIADB_BUILD_FOLDER}"
  mv ${MARIADB_FOLDER}-*/* ${MARIADB_FOLDER}

  rm -rf ${MARIADB_FOLDER}*.*

  cd "${MARIADB_BUILD_FOLDER}" || exit
}

## End module utils

deleteCache

purgeManagerPackages
installPackages

kernelTuning

buildModule $JEMALLOC_FOLDER $JEMALLOC_URL "$JEMALLOC_BUILD_ARGS"
buildModule $ZLIB_FOLDER $ZLIB_URL "$ZLIB_BUILD_ARGS"
buildModule $PCRE2_FOLDER $PCRE2_URL "$PCRE2_BUILD_ARGS"
buildModule $OPENSSL_FOLDER $OPENSSL_URL "$OPENSSL_BUILD_ARGS"

## Start NGINX installation

if [[ $USE_NGINX == 1 ]]; then
  buildModule $LIBATOMIC_FOLDER $LIBATOMIC_URL $LIBATOMIC_BUILD_ARGS

  if [[ $USE_OPENSSL == 0 ]]; then
      # Needs to be implemented!!!
      buildModule $GOLANG_FOLDER $GOLANG_URL
      buildModule $BORINGSSL_FOLDER $BORINGSSL_URL $BORINGSSL_BUILD_ARGS
  fi

  buildModule $NGX_BROTLI_FOLDER $NGX_BROTLI_URL

  buildModule $NGINX_FOLDER $NGINX_URL $NGINX_BUILD_ARGS

  cp -rf "${SERVICES_PATH}/${NGINX_FOLDER}.service" ${NGINX_SYSTEMD_SERVICE_PATH}
  cp -rf ${CONF_PATH}/${NGINX_FOLDER}/* "/etc/${NGINX_FOLDER}"

  ## Generate TLS ticket keys

  openssl rand 80 > "/etc/${NGINX_FOLDER}/tls_tickets/first.key"
  openssl rand 80 > "/etc/${NGINX_FOLDER}/tls_tickets/rotate.key"
  chmod -R 644 "/etc/${NGINX_FOLDER}/tls_tickets"

  enableService "${NGINX_FOLDER}.service"
fi

## End NGINX installation

## Start Redis installation

if [[ $USE_REDIS == 1 ]]; then
    buildModule $REDIS_FOLDER $REDIS_URL $REDIS_BUILD_ARGS

    cp -rf "${CONF_PATH}/${REDIS_FOLDER}.conf" ${REDIS_CONFIG_PATH}
    cp -rf "${SERVICES_PATH}/${REDIS_FOLDER}.service" ${REDIS_SYSTEMD_SERVICE_PATH}

    usermod -aG redis www-data

    enableService "${REDIS_FOLDER}.service"
fi

## End Redis installation

## Start MariaDB upgrade
if [[ $USE_MARIADB == 1 ]]; then
  getMariaDbSource
  eval "${MARIADB_BUILD_ARGS}"

  groupadd mysql
  useradd -g mysql mysql
  usermod -aG mysql www-data

  cd "${MARIADB_INSTALLATION_FOLDER}" || exit

  ln -s "${MARIADB_INSTALLATION_FOLDER}/bin/*" "/usr/sbin/"
  cp -rf "${MARIADB_INSTALLATION_FOLDER}/support-files/systemd/${MARIADB_FOLDER}.service" "/lib/systemd/system/"
  chmod 644 "/lib/systemd/system/${MARIADB_FOLDER}.service"

  mkdir -p "${MARIADB_CONF_FOLDER}/conf.d"
  mkdir -p "${MARIADB_CONF_FOLDER}/mariadb.conf.d"

  cp -rf "${CONF_PATH}/${MARIADB_CONF_FILE}" "${MARIADB_CONF_FOLDER}"

  chown -R mysql:mysql "${MARIADB_CONF_FOLDER}"
  chmod -R 770 "${MARIADB_CONF_FOLDER}"

  mkdir -p "${MARIADB_SOCKET_FOLDER}"
  chown -R mysql:mysql "${MARIADB_SOCKET_FOLDER}"
  chmod -R 755 "${MARIADB_SOCKET_FOLDER}"

  scripts/mysql_install_db --user=mysql

  chown -R mysql:mysql "${MARIADB_INSTALLATION_FOLDER}"

  systemctl daemon-reload
  systemctl enable "${MARIADB_FOLDER}.service"

  systemctl start "${MARIADB_FOLDER}.service"
fi
## End MariaDB upgrade

die