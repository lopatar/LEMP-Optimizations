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
#OPENSSL_BUILD_ARGS="KERNEL_BITS=64 ./config -Wno-free-nonheap-object no-weak-ssl-ciphers no-docs no-legacy no-ssl3 no-tests enable-brotli enable-ktls no-unit-test threads thread-pool zlib -DOPENSSL_SMALL=1 -DOPENSSL_NO_HEARTBEATS -O3 -mtune=${M_TUNE} -funroll-loops -flto=auto -ffunction-sections -fdata-sections -I/usr/local/include -fPIC -Wl,-rpath,/usr/local/lib -Wl,-ljemalloc && make -j${PARALLEL_TASKS} && make install"

NGX_BROTLI_FOLDER="ngx_brotli"
NGX_BROTLI_URL="https://github.com/google/ngx_brotli"

NGINX_FOLDER="nginx"
NGINX_URL="https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz"
# shellcheck disable=SC2034
NGINX_BUILD_ARGS="./configure --with-compat --with-cc-opt='-I/usr/local/include -mtune=${M_TUNE} -Ofast -ffast-math -funroll-loops -fPIE -fPIC -fstack-protector-strong --param=ssp-buffer-size=4 -flto=auto -Wp,-D_FORTIFY_SOURCE=2 -Wno-implicit-fallthrough -Wno-implicit-function-declaration -Wno-ignored-qualifiers -Wno-unused-variable -Wno-error' --with-ld-opt='-L/usr/local/lib -l:libjemalloc.a -l:libatomic_ops.a -l:libpcre2-8.a -l:libz.a -mtune=${M_TUNE} -Ofast -ffast-math -funroll-loops -fPIE -fstack-protector-strong --param=ssp-buffer-size=4 -flto=auto -Wp,-D_FORTIFY_SOURCE=2 -fPIC' --prefix=/etc/nginx --sbin-path=/usr/sbin/nginx --modules-path=/etc/nginx/modules --conf-path=/etc/nginx/nginx.conf --error-log-path=/var/log/nginx/error.log --http-log-path=/var/log/nginx/access.log --pid-path=/var/run/nginx.pid --lock-path=/var/run/nginx.lock --http-client-body-temp-path=/var/cache/nginx/client_temp --http-proxy-temp-path=/var/cache/nginx/proxy_temp --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp --http-scgi-temp-path=/var/cache/nginx/scgi_temp --user=www-data --group=www-data --with-file-aio --with-threads --with-pcre --with-libatomic --with-pcre-jit --with-http_dav_module --with-http_gunzip_module --with-http_gzip_static_module --with-http_ssl_module --without-select_module --without-poll_module --without-http_mirror_module --without-http_geo_module --without-http_split_clients_module --without-http_uwsgi_module --without-http_scgi_module --without-http_grpc_module --without-http_memcached_module --without-http_empty_gif_module --without-mail_pop3_module --without-mail_imap_module --without-mail_smtp_module --without-stream_limit_conn_module --without-stream_access_module --without-stream_geo_module --without-stream_map_module --without-stream_split_clients_module --without-stream_return_module --without-stream_set_module --without-stream_upstream_hash_module --without-stream_upstream_least_conn_module --without-stream_upstream_random_module --without-stream_upstream_zone_module --with-http_v2_module --with-http_v3_module --add-dynamic-module=${INSTALL_PATH}/ngx_brotli --with-openssl=${INSTALL_PATH}/openssl --with-openssl-opt='-Wno-free-nonheap-object no-weak-ssl-ciphers no-docs no-legacy no-ssl3 no-tests'  && make -j${PARALLEL_TASKS} && make install"
NGINX_SYSTEMD_SERVICE_PATH="/usr/lib/systemd/system/${NGINX_FOLDER}.service"

REDIS_FOLDER="redis"
REDIS_URL="https://github.com/redis/redis/archive/${REDIS_VERSION}.tar.gz"
REDIS_BUILD_ARGS="make USE_SYSTEMD=yes MALLLOC=jemalloc BUILD_TLS=no REDIS_CFLAGS=\"-I/usr/local/include -O3 -funroll-loops -mtune=${M_TUNE}\" REDIS_LDFLAGS=\"-L/usr/local/lib -l:libjemalloc.a \" -j${PARALLEL_TASKS} && make install"
REDIS_CONFIG_PATH="/etc/redis/${REDIS_FOLDER}.conf"
REDIS_SYSTEMD_SERVICE_PATH="${SYSTEMD_SERVICES_PATH}/${REDIS_FOLDER}.service"

MARIADB_FOLDER="mariadb"
MARIADB_BUILD_FOLDER="${MARIADB_FOLDER}/${MARIADB_FOLDER}-${MARIADB_VERSION}-build"
MARIADB_SIGNING_KEY_URL="https://mariadb.org/mariadb_release_signing_key.pgp"
MARIADB_BUILD_ARGS="cmake ../ -DCMAKE_C_FLAGS='-I/usr/local/include -O3 -fno-strict-aliasing -funroll-loops --param=ssp-buffer-size=4 -flto=auto -mtune=${M_TUNE}' -DCMAKE_CXX_FLAGS='-I/usr/local/include -O3 -funroll-loops --param=ssp-buffer-size=4 -flto=auto -mtune=${M_TUNE}' -DBUILD_CONFIG=mysql_release -DMYSQL_MAINTAINER_MODE=OFF -DCMAKE_EXE_LINKER_FLAGS='-l:libjemalloc.a -l:libatomic_ops.a -l:libpcre2-8.a -l:libz.a' -DWITH_SAFEMALLOC=OFF && cmake --build . -j${PARALLEL_TASKS} && make install -j${PARALLEL_TASKS}"
MARIADB_CONF_FOLDER="/etc/mysql"
MARIADB_SOCKET_FOLDER="/var/run/mysqld"
MARIADB_CONF_FILE="my.cnf"
MARIADB_INSTALLATION_FOLDER="/usr/local/mysql"

PHP_PREFIX="php${PHP_VERSION}"