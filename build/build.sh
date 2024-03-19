#!/bin/zsh
buildModule $JEMALLOC_FOLDER $JEMALLOC_URL "$JEMALLOC_BUILD_ARGS"
buildModule $ZLIB_FOLDER $ZLIB_URL "$ZLIB_BUILD_ARGS"
buildModule $PCRE2_FOLDER $PCRE2_URL "$PCRE2_BUILD_ARGS"

## Start NGINX installation

if [[ $USE_NGINX == 1 ]]; then
  buildModule $LIBATOMIC_FOLDER "$LIBATOMIC_URL" $LIBATOMIC_BUILD_ARGS

  if [[ $USE_OPENSSL == 0 ]]; then
      die "Must use OpenSSL, BoringSSL not yet supported!"
      # Needs to be implemented!!!
      #buildModule $GOLANG_FOLDER "$GOLANG_URL"
      #buildModule $BORINGSSL_FOLDER $BORINGSSL_URL $BORINGSSL_BUILD_ARGS
  else
    buildModule $OPENSSL_FOLDER $OPENSSL_URL
  fi

  buildModule $NGX_BROTLI_FOLDER $NGX_BROTLI_URL

  buildModule $NGINX_FOLDER "$NGINX_URL" $NGINX_BUILD_ARGS

  printLine "Installing optimized systemd service: ${NGINX_SYSTEMD_SERVICE_PATH}/${NGINX_FOLDER}.service" "Systemd"
  cp -rf "${SERVICES_PATH}/${NGINX_FOLDER}.service" ${NGINX_SYSTEMD_SERVICE_PATH}

  # shellcheck disable=SC2086
  printLine "Copying optimized configuration to /etc/${NGINX_FOLDER}" "NGINX"
  cp -rf ${CONF_PATH}/${NGINX_FOLDER}/* "/etc/${NGINX_FOLDER}"
  printLine "NGINX configuration files: $(ls /etc/${NGINX_FOLDER})" "NGINX"

  ## Generate TLS ticket keys

  printLine "Generating base AES256 TLS ticket key" "Security"
  openssl rand 80 > "/etc/${NGINX_FOLDER}/tls_tickets/first.key"

  printLine "Generating rotational AES256 TLS ticket key" "Security"
  openssl rand 80 > "/etc/${NGINX_FOLDER}/tls_tickets/rotate.key"

  printLine "Doing chmod 400 on /etc/${NGINX_FOLDER}/tls_tickets" "Security"
  chmod -R 440 "/etc/${NGINX_FOLDER}/tls_tickets"

  enableService "${NGINX_FOLDER}.service"
fi

## End NGINX installation

## Start Redis installation

if [[ $USE_REDIS == 1 ]]; then
    buildModule $REDIS_FOLDER "$REDIS_URL" $REDIS_BUILD_ARGS

    printLine "Copying optimized configuration to ${REDIS_CONFIG_PATH}" "Redis"
    cp -rf "${CONF_PATH}/${REDIS_FOLDER}.conf" ${REDIS_CONFIG_PATH}

    printLine "Installing optimized systemd service to ${REDIS_SYSTEMD_SERVICE_PATH}/${REDIS_FOLDER}.service" "Systemd"
    cp -rf "${SERVICES_PATH}/${REDIS_FOLDER}.service" ${REDIS_SYSTEMD_SERVICE_PATH}

    printLine "Granting www-data the redis group" "Security"
    usermod -aG redis www-data

    enableService "${REDIS_FOLDER}.service"
fi

## End Redis installation

## Start MariaDB upgrade
if [[ $USE_MARIADB == 1 ]]; then
  getMariaDbSource

  printLine "Executing MariaDB build arguments" "Compiler"
  eval "${MARIADB_BUILD_ARGS}"

  printLine "Creating MySQL group" "Security"
  groupadd mysql

  printLine "Creating MySQL user" "Security"
  useradd -g mysql mysql

  printLine "Granting www-data the mysql group" "Security"
  usermod -aG mysql www-data

  printLine "Entering ${MARIADB_INSTALLATION_FOLDER}" "MariaDB"
  cd "${MARIADB_INSTALLATION_FOLDER}" || exit

  printLine "Linking ${MARIADB_INSTALLATION_FOLDER}/bin/ -> /usr/sbin/" "Module-Installer"
  ln -s "${MARIADB_INSTALLATION_FOLDER}/bin/*" "/usr/sbin/"

  MARIADB_SERVICE_FILE_PATH="/lib/systemd/system/${MARIADB_FOLDER}.service"

  printLine "Installing optimized systemd service to ${MARIADB_SERVICE_FILE_PATH}" "Systemd"
  cp -rf "${MARIADB_INSTALLATION_FOLDER}/support-files/systemd/${MARIADB_FOLDER}.service" "/lib/systemd/system/"

  printLine "Doing chmod 644 on ${MARIADB_SERVICE_FILE_PATH}" "Security"
  chmod 644 ${MARIADB_SERVICE_FILE_PATH}

  printLine "Creating ${MARIADB_CONF_FOLDER}/conf.d" "MariaDB"
  mkdir -p "${MARIADB_CONF_FOLDER}/conf.d"

  printLine "Creating ${MARIADB_CONF_FOLDER}/mariadb.conf.d" "MariaDB"
  mkdir -p "${MARIADB_CONF_FOLDER}/mariadb.conf.d"

  printLine "Copying optimized configuration to ${MARIADB_CONF_FOLDER}" "MariaDB"
  cp -rf "${CONF_PATH}/${MARIADB_CONF_FILE}" "${MARIADB_CONF_FOLDER}"

  printLine "Doing chown -R mysql:mysql to ${MARIADB_CONF_FOLDER}" "Security"
  chown -R mysql:mysql "${MARIADB_CONF_FOLDER}"

  printLine "Doing chmod -R 600 to ${MARIADB_CONF_FOLDER}" "Security"
  chmod -R 600 "${MARIADB_CONF_FOLDER}"

  printLine "Creating ${MARIADB_SOCKET_FOLDER} UNIX socket folder" "MariaDB"
  mkdir -p "${MARIADB_SOCKET_FOLDER}"

  printLine "Doing chown -R mysql:mysql to ${MARIADB_SOCKET_FOLDER}" "Security"
  chown -R mysql:mysql "${MARIADB_SOCKET_FOLDER}"

  printLine "Doing chmod -R 600 to ${MARIADB_SOCKET_FOLDER}" "Security"
  chmod -R 600 "${MARIADB_SOCKET_FOLDER}"

  printLine "Running scripts/mysql_install_db --user=mysql"
  scripts/mysql_install_db --user=mysql

  printLine "Doing chown -R mysql:mysql to ${MARIADB_INSTALLATION_FOLDER}" "Security"
  chown -R mysql:mysql "${MARIADB_INSTALLATION_FOLDER}"

  printLine "Reloading systemd daemon" "Systemd"
  systemctlWrap "daemon-reload"

  printLine "Enabling ${MARIADB_FOLDER}.service" "Systemd"
  systemctlWrap "enable" "${MARIADB_FOLDER}.service"

  printLine "Starting ${MARIADB_FOLDER}.service" "Systemd"
  systemctlWrap "start" "${MARIADB_FOLDER}.service"

  printLine "MariaDB configuration files $(ls "${MARIADB_CONF_FOLDER}")" "MariaDB"
fi
## End MariaDB upgrade

die