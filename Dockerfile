FROM opsbears/dumb-init:stable

ARG MYSQL_VERSION=5.7.19-0ubuntu0.16.04.1

RUN DEBIAN_FRONTEND=noninteractive apt-get install -y mysql-server="${MYSQL_VERSION}" \
    && rm -rf /var/lib/mysql && mkdir -p /var/lib/mysql /var/run/mysqld \
    && chown -R mysql:mysql /var/lib/mysql /var/run/mysqld

COPY init.sh /init.sh

CMD ["/init.sh", "mysqld_safe", "--bind-address=0.0.0.0"]

HEALTHCHECK --interval=10s --timeout=3s CMD /usr/bin/mysql -e "SELECT 1" || exit 1
VOLUME /var/lib/mysql
EXPOSE 3306
