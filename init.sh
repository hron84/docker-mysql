#!/bin/bash

set -e

DATADIR=/var/lib/mysql

#if [ ! "$(ls -A $DATADIR)" ]; then
if [ ! -d "${DATADIR}/mysql" ]; then
    SOCKET=/var/run/mysqld/mysqld.sock

    mkdir -p $(dirname ${SOCKET})

    if [ -z "${MYSQL_ROOT_PASSWORD}" ]; then
        echo "No MySQL database in /var/lib/mysql and no root password was provied in MYSQL_ROOT_PASSWORD for initialization, generating random MySQL root password."
        MYSQL_ROOT_PASSWORD=$(pwgen 16)
    fi
    if [ -z "${MYSQL_ROOT_HOST}" ]; then
        echo "No MySQL database in /var/lib/mysql and no root host was provided in MYSQL_ROOT_HOST, using localhost."
        MYSQL_ROOT_HOST="localhost"
    fi

    echo 'Initializing database...'
    /usr/sbin/mysqld --initialize-insecure

    /usr/sbin/mysqld --skip-networking --socket="${SOCKET}" &

    PID="$!"

    echo -n "Waiting for MySQL server to become available"
    set +e
    for i in $(seq 0 30); do
        /usr/bin/mysql --protocol=socket -uroot -hlocalhost --socket=${SOCKET} -e "SELECT 1" 1>/dev/null 2>/dev/null
        if [ $? -eq 0 ]; then
            break
        fi
        echo -n "."
        sleep 1
    done
    set -e
    echo ""

    if [ "$i" -ge 30 ]; then
        echo 'MySQL init process failed, server is not available.' >&2
        exit 1
    fi

    INIT_SQL=""
    INIT_SQL="${INIT_SQL} SET @@SESSION.SQL_LOG_BIN=0;"
    INIT_SQL="${INIT_SQL} DELETE FROM mysql.user WHERE user NOT IN ('mysql.sys', 'mysqlxsys', 'root') OR host NOT IN ('localhost', '${MYSQL_ROOT_HOST}');"
    INIT_SQL="${INIT_SQL} SET PASSWORD FOR 'root'@'localhost'=PASSWORD('${MYSQL_ROOT_PASSWORD}');"
    if [ ! -z "$MYSQL_ROOT_HOST" -a "$MYSQL_ROOT_HOST" != 'localhost' ]; then
        INIT_SQL="${INIT_SQL} CREATE USER 'root'@'${MYSQL_ROOT_HOST}' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';"
        INIT_SQL="${INIT_SQL} GRANT ALL ON *.* TO 'root'@'${MYSQL_ROOT_HOST}' WITH GRANT OPTION;"
    fi
    INIT_SQL="${INIT_SQL} GRANT ALL ON *.* TO 'root'@'localhost' WITH GRANT OPTION ;"
    INIT_SQL="${INIT_SQL} DROP DATABASE IF EXISTS test ;"
    INIT_SQL="${INIT_SQL} FLUSH PRIVILEGES;"
    echo "${INIT_SQL}" | /usr/bin/mysql --protocol=socket -uroot -hlocalhost --socket=${SOCKET}
    INIT_SQL=""

    if ! kill -s TERM "$PID" || ! wait "$PID"; then
        echo 'MySQL initialization failed, could not stop MySQL server' >&2
        exit 1
    fi

    echo "[client]" > "${HOME}/.my.cnf"
    echo "user=root" >> "${HOME}/.my.cnf"
    echo "password=${MYSQL_ROOT_PASSWORD}" >> "${HOME}/.my.cnf"
    chmod 0400 "${HOME}/.my.cnf"

    export MYSQL_ROOT_PASSWORD=""

    echo "MySQL initialization complete."
fi

exec "$@"
