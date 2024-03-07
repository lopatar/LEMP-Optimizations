#!/bin/zsh
## Configuration

# BoringSSL not implemented in NGINX build
USE_OPENSSL=1

M_TUNE="cortex-a72"
SWAP_FACTOR=2
SWAP_MAX_MB=3072

JEMALLOC_VERSION="5.3.0"
ZLIB_VERSION="1.2.11"
LIBATOMIC_VERSION="7.8.2"
PCRE2_VERSION="10.43"
GOLANG_VERSION="1.22.0"
OPENSSL_VERSION="3.2.1"
NGINX_VERSION="1.25.4"

## Optional software

USE_REDIS=1
REDIS_VERSION="7.2.4"

## End optional software

## End configuration

## Start internal utils

PARALLEL_TASKS=$(nproc)

function deleteCache()
{
    for FILE in *
    do
        if [[ $FILE == conf || $FILE == services || $FILE == *.md || $FILE == *.sh ]]; then
            continue
        fi
        
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
        wget "${FUNC_URL}" -O ${FUNC_ARCHIVE_NAME} --max-redirect=1
        mkdir "${FUNC_FOLDER}"
        tar -xf ${FUNC_ARCHIVE_NAME} -C "./${FUNC_FOLDER}" --strip-components=1
        rm -rf ${FUNC_ARCHIVE_NAME}
    else
        git clone --recurse-submodules -j${PARALLEL_TASKS} ${FUNC_URL}
    fi
    
    if [[ -n $FUNC_BUILD_ARGS ]]; then
        cd "${FUNC_FOLDER}" || exit
        eval "${FUNC_BUILD_ARGS}"
        cd ../
    fi
}

function enableService() {
    local SERVICE_NAME=${1}

    systemctl daemon-reload

    systemctl restart "${SERVICE_NAME}"
}

function kernelTuning()
{
  # shellcheck disable=SC2155
  local ROOT_MOUNT=$(findmnt -n / | awk '{ print $2 }')
  # shellcheck disable=SC2155
  local SYSTEM_DEVICE=$(lsblk -no pkname "${ROOT_MOUNT}")

  echo deadline > "/sys/block/${SYSTEM_DEVICE}/queue/scheduler"

  ## Configure SWAP

  echo -e "CONF_SWAPFACTOR=${SWAP_FACTOR}\nCONF_MAXSWAP=${SWAP_MAX_MB}" > /etc/dphys-swapfile
  systemctl restart dphys-swapfile.service

  ## End configure SWAP

  # shellcheck disable=SC2155
  local SYSCTL_CONFIG=$(sysctl -a)

  if [[ -z $(echo "${SYSCTL_CONFIG}" | grep "vm.overcommit_memory = 1") ]]; then
    echo "vm.overcommit_memory = 1" >> /etc/sysctl.conf
  fi

  if [[ -z $(echo "${SYSCTL_CONFIG}" | grep "vm.swappiness = 1") ]]; then
    echo "vm.swappiness = 1" >> /etc/sysctl.conf
  fi

  if [[ -z $(echo "${SYSCTL_CONFIG}" | grep "net.ipv4.ip_unprivileged_port_start = 1024") ]]; then
    echo "net.ipv4.ip_unprivileged_port_start = 1024" >> /etc/sysctl.conf
  fi

  if [[ -z $(echo "${SYSCTL_CONFIG}" | grep "net.ipv4.ip_local_port_range = 1024  65535") ]]; then
    echo "net.ipv4.ip_local_port_range = 1024 65535" >> /etc/sysctl.conf
  fi

  if [[ -z $(echo "${SYSCTL_CONFIG}" | grep "fs.file-max = 524280") ]]; then
    echo "fs.file-max = 524280" >> /etc/sysctl.conf
  fi

  echo never | tee /sys/kernel/mm/transparent_hugepage/enabled /sys/kernel/mm/transparent_hugepage/defrag > /dev/null

  sysctl -p
}

function installPackages()
{
    apt update && apt upgrade -y
    apt install -y devscripts build-essential ninja-build libsystemd-dev
}

INSTALL_PATH=$(pwd)
CONF_PATH="${INSTALL_PATH}/conf"
SERVICES_PATH="${INSTALL_PATH}/services"

SYSTEMD_SERVICES_PATH="/usr/lib/systemd/system"

## End internal utils

## Start module configuration

JEMALLOC_FOLDER="jemalloc"
JEMALLOC_URL="https://github.com/jemalloc/jemalloc/releases/download/${JEMALLOC_VERSION}/jemalloc-$JEMALLOC_VERSION.tar.bz2"
JEMALLOC_BUILD_ARGS="CC=/usr/bin/clang EXTRA_CFLAGS='-mtune=${M_TUNE} -DADLER32_SIMD_NEON -DINFLATE_CHUNK_SIMD_NEON -DINFLATE_CHUNK_READ_64LE -O3 -D_LARGEFILE64_SOURCE=1 -DHAVE_HIDDEN -funroll-loops' CXX=/usr/bin/clang++ EXTRA_CXXFLAGS='-mtune=${M_TUNE} -DADLER32_SIMD_NEON -DINFLATE_CHUNK_SIMD_NEON -DINFLATE_CHUNK_READ_64LE -O3 -D_LARGEFILE64_SOURCE=1 -DHAVE_HIDDEN -funroll-loops' ./configure && make -j${PARALLEL_TASKS} && make install"

ZLIB_FOLDER="zlib"
ZLIB_URL="https://github.com/cloudflare/zlib/archive/refs/tags/v${ZLIB_VERSION}.tar.gz"
ZLIB_BUILD_ARGS="CC=/usr/bin/clang CFLAGS='-mtune=${M_TUNE} -DADLER32_SIMD_NEON -DINFLATE_CHUNK_SIMD_NEON -DINFLATE_CHUNK_READ_64LE -O3 -D_LARGEFILE64_SOURCE=1 -DHAVE_HIDDEN -funroll-loops' CPP=/usr/bin/clang++ SFLAGS='-mtune=${M_TUNE} -DADLER32_SIMD_NEON -DINFLATE_CHUNK_SIMD_NEON -DINFLATE_CHUNK_READ_64LE -O3 -D_LARGEFILE64_SOURCE=1 -DHAVE_HIDDEN -funroll-loops' LD_LIBRARY_PATH=/usr/local/lib LDFLAGS='-L/usr/local/lib -l:libjemalloc.a' ./configure && make -j${PARALLEL_TASKS} && make install"

LIBATOMIC_FOLDER="libatomic"
LIBATOMIC_URL="https://github.com/ivmai/libatomic_ops/releases/download/v${LIBATOMIC_VERSION}/libatomic_ops-$LIBATOMIC_VERSION.tar.gz"
LIBATOMIC_BUILD_ARGS="LT_SYS_LIBRARY_PATH=/usr/local/lib LD_LIBRARY_PATH=/usr/local/lib LDFLAGS='-L/usr/local/lib -l:libjemalloc.a' CC=/usr/bin/clang CCAS=/usr/bin/clang CCASFLAGS='-mtune=${M_TUNE} -DADLER32_SIMD_NEON -DINFLATE_CHUNK_SIMD_NEON -O3 -funroll-loops' CFLAGS='-mtune=${M_TUNE} -DADLER32_SIMD_NEON -DINFLATE_CHUNK_SIMD_NEON -O3 -funroll-loops' CPPFLAGS='-mtune=${M_TUNE} -DADLER32_SIMD_NEON -DINFLATE_CHUNK_SIMD_NEON -O3 -funroll-loops' ./configure && make -j${PARALLEL_TASKS} && make install"

PCRE2_FOLDER="libpcre"
PCRE2_URL="https://github.com/PCRE2Project/pcre2/releases/download/pcre2-${PCRE2_VERSION}/pcre2-${PCRE2_VERSION}.tar.gz"
PCRE2_BUILD_ARGS="LT_SYS_LIBRARY_PATH=/usr/local/lib LD_LIBRARY_PATH=/usr/local/lib LDFLAGS='-L/usr/local/lib -l:libjemalloc.a -l:libz.a' CC=/usr/bin/clang CFLAGS='-mtune=${M_TUNE} -DADLER32_SIMD_NEON -DINFLATE_CHUNK_SIMD_NEON -DINFLATE_CHUNK_READ_64LE -O3 -D_LARGEFILE64_SOURCE=1 -DHAVE_HIDDEN -funroll-loops' CPPFLAGS='-mtune=${M_TUNE} -DADLER32_SIMD_NEON -DINFLATE_CHUNK_SIMD_NEON -DINFLATE_CHUNK_READ_64LE -O3 -D_LARGEFILE64_SOURCE=1 -DHAVE_HIDDEN -funroll-loops' ./configure --enable-pcre2grep-libz --enable-jit && make -j${PARALLEL_TASKS} && make install"

GOLANG_FOLDER="golang"
GOLANG_URL="https://dl.google.com/go/go${GOLANG_VERSION}.linux-amd64.tar.gz"
GO_BIN="${INSTALL_PATH}/${GOLANG_FOLDER}/bin"

BORINGSSL_FOLDER="boringssl"
BORINGSSL_URL="https://boringssl.googlesource.com/boringssl"
BORINGSSL_BUILD_ARGS="cmake -GNinja -B build -DOPENSSL_SMALL=1 -DGO_EXECUTABLE=${GO_BIN}/go -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER=/usr/bin/clang -DCMAKE_CXX_COMPILER=/usr/bin/clang++ -DCMAKE_C_FLAGS_INIT='-mtune=${M_TUNE} -DADLER32_SIMD_NEON -DINFLATE_CHUNK_SIMD_NEON -DINFLATE_CHUNK_READ_64LE -O3 -D_LARGEFILE64_SOURCE=1 -DHAVE_HIDDEN -funroll-loops' -DCMAKE_CXX_FLAGS_INIT='-mtune=${M_TUNE} -DADLER32_SIMD_NEON -DINFLATE_CHUNK_SIMD_NEON -DINFLATE_CHUNK_READ_64LE -O3 -D_LARGEFILE64_SOURCE=1 -DHAVE_HIDDEN -funroll-loops' -DCMAKE_SHARED_LINKER_FLAGS_INIT='-L/usr/local/lib -l:libjemalloc.a' && ninja -j${PARALLEL_TASKS} -C build"

OPENSSL_FOLDER="openssl"
OPENSSL_URL="https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz"

NGX_BROTLI_FOLDER="ngx_brotli"
NGX_BROTLI_URL="https://github.com/google/ngx_brotli"

NGINX_FOLDER="nginx"
NGINX_URL="https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz"
NGINX_BUILD_ARGS="./configure --with-compat --with-cc-opt='-I/usr/local/include -mtune=${M_TUNE} -Ofast -ffast-math -funroll-loops -fPIE -fstack-protector-strong --param=ssp-buffer-size=4 -flto=auto -Wp,-D_FORTIFY_SOURCE=2 -Wno-implicit-fallthrough -Wno-implicit-function-declaration -Wno-discarded-qualifiers -Wno-unused-variable -Wno-error' --with-ld-opt='-L/usr/local/lib -l:libjemalloc.a -l:libatomic_ops.a -l:libpcre2-8.a -l:libz.a -mtune=${M_TUNE} -Ofast -ffast-math -funroll-loops -fPIE -fstack-protector-strong --param=ssp-buffer-size=4 -flto=auto -Wp,-D_FORTIFY_SOURCE=2 -fPIC' --prefix=/etc/nginx --sbin-path=/usr/sbin/nginx --modules-path=/etc/nginx/modules --conf-path=/etc/nginx/nginx.conf --error-log-path=/var/log/nginx/error.log --http-log-path=/var/log/nginx/access.log --pid-path=/var/run/nginx.pid --lock-path=/var/run/nginx.lock --http-client-body-temp-path=/var/cache/nginx/client_temp --http-proxy-temp-path=/var/cache/nginx/proxy_temp --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp --http-scgi-temp-path=/var/cache/nginx/scgi_temp --user=www-data --group=www-data --with-file-aio --with-threads --with-pcre --with-libatomic --with-pcre-jit --with-http_dav_module --with-http_gunzip_module --with-http_gzip_static_module --with-http_ssl_module --without-select_module --without-poll_module --without-http_mirror_module --without-http_geo_module --without-http_split_clients_module --without-http_uwsgi_module --without-http_scgi_module --without-http_grpc_module --without-http_memcached_module --without-http_empty_gif_module --without-mail_pop3_module --without-mail_imap_module --without-mail_smtp_module --without-stream_limit_conn_module --without-stream_access_module --without-stream_geo_module --without-stream_map_module --without-stream_split_clients_module --without-stream_return_module --without-stream_set_module --without-stream_upstream_hash_module --without-stream_upstream_least_conn_module --without-stream_upstream_random_module --without-stream_upstream_zone_module --with-http_v2_module --with-http_v3_module --with-openssl=${INSTALL_PATH}/${OPENSSL_FOLDER} --with-openssl-opt='-Wno-free-nonheap-object no-weak-ssl-ciphers no-ssl3 no-tests no-unit-test no-shared -DOPENSSL_NO_HEARTBEATS -O3 -mtune=${M_TUNE} -funroll-loops -flto=auto -ffunction-sections -fdata-sections' --add-dynamic-module=${INSTALL_PATH}/ngx_brotli && make -j${PARALLEL_TASKS} && make install"
NGINX_SYSTEMD_SERVICE_PATH="/usr/lib/systemd/system/${NGINX_FOLDER}.service"

REDIS_FOLDER="redis"
REDIS_URL="https://github.com/redis/redis/archive/${REDIS_VERSION}.tar.gz"
REDIS_BUILD_ARGS="make USE_SYSTEMD=yes MALLLOC=jemalloc BUILD_TLS=no REDIS_CFLAGS=\"-I/usr/local/include -O3 -funroll-loops --param=ssp-buffer-size=4 -flto=auto -mtune=${M_TUNE}\" REDIS_LDFLAGS=\"-L/usr/local/lib -l:libjemalloc.a \" -j${PARALLEL_TASKS} && make install"
REDIS_CONFIG_PATH="/etc/redis/${REDIS_FOLDER}.conf"
REDIS_SYSTEMD_SERVICE_PATH="${SYSTEMD_SERVICES_PATH}/${REDIS_FOLDER}.service"

## End module configuration
deleteCache

installPackages
kernelTuning

buildModule $JEMALLOC_FOLDER $JEMALLOC_URL $JEMALLOC_BUILD_ARGS

buildModule $ZLIB_FOLDER $ZLIB_URL $ZLIB_BUILD_ARGS
buildModule $LIBATOMIC_FOLDER $LIBATOMIC_URL $LIBATOMIC_BUILD_ARGS
buildModule $PCRE2_FOLDER $PCRE2_URL $PCRE2_BUILD_ARGS

if [[ $USE_OPENSSL == 1 ]]; then
    buildModule $OPENSSL_FOLDER $OPENSSL_URL
else
    # Needs to be implemented!!!
    buildModule $GOLANG_FOLDER $GOLANG_URL
    buildModule $BORINGSSL_FOLDER $BORINGSSL_URL $BORINGSSL_BUILD_ARGS
fi

buildModule $NGX_BROTLI_FOLDER $NGX_BROTLI_URL

## Start NGINX installation

buildModule $NGINX_FOLDER $NGINX_URL $NGINX_BUILD_ARGS
    
cp -rf "${SERVICES_PATH}/${NGINX_FOLDER}.service" ${NGINX_SYSTEMD_SERVICE_PATH}
cp -rf ${CONF_PATH}/${NGINX_FOLDER}/* "/etc/${NGINX_FOLDER}"

## Generate TLS ticket keys

openssl rand 80 > "/etc/${NGINX_FOLDER}/tls_tickets/first.key"
openssl rand 80 > "/etc/${NGINX_FOLDER}/tls_tickets/rotate.key"
chmod -R 644 "/etc/${NGINX_FOLDER}/tls_tickets"

enableService "${NGINX_FOLDER}.service"

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

