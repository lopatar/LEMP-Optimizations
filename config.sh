# BoringSSL not implemented yet
USE_OPENSSL=1

USE_NGINX=1
USE_MARIADB=1
USE_REDIS=1

SWAP_ENABLE=1
SWAP_FACTOR=2
SWAP_MAX_MB=8192

NGINX_VERSION="1.25.4"
MARIADB_VERSION="11.3"
REDIS_VERSION="7.2.4"

JEMALLOC_VERSION="5.3.0"
ZLIB_VERSION="1.2.11"
LIBATOMIC_VERSION="7.8.2"
PCRE2_VERSION="10.43"
GOLANG_VERSION="1.22.1"
OPENSSL_VERSION="3.2.1"

M_TUNE="cortex-a72"

C_COMPILER="/usr/bin/clang"
CXX_COMPILER="/usr/bin/clang++"

function printConfVar()
{
  # shellcheck disable=SC2028
  CONF_VAR="$1 => \"$(eval echo \$"$1")\""
  printLine "${CONF_VAR}" "Config"
}

function printConfiguration()
{
  printLine "Printing configuration" "Config"

  printConfVar USE_OPENSSL
  printConfVar USE_NGINX
  printConfVar USE_MARIADB
  printConfVar USE_REDIS

  printConfVar SWAP_ENABLE
  printConfVar SWAP_FACTOR
  printConfVar SWAP_MAX_MB

  printConfVar NGINX_VERSION
  printConfVar MARIADB_VERSION
  printConfVar REDIS_VERSION

  printConfVar JEMALLOC_VERSION
  printConfVar ZLIB_VERSION
  printConfVar LIBATOMIC_VERSION
  printConfVar PCRE2_VERSION
  printConfVar GOLANG_VERSION
  printConfVar OPENSSL_VERSION

  printConfVar M_TUNE
  printConfVar C_COMPILER
  printConfVar CXX_COMPILER
}



