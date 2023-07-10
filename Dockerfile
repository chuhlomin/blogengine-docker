FROM alpine:3.18.2

ARG ALPINE_PACKAGES="php82-iconv php82-pdo_mysql php82-pdo_pgsql php82-openssl php82-simplexml libpng-dev"
ARG RELEASE=4116
ARG UID=65534
ARG GID=82

ENV CONFIG_PATH=/srv/cfg
ENV PATH=$PATH:/srv/bin

RUN \
# Prepare composer dependencies
    ALPINE_PACKAGES="$(echo ${ALPINE_PACKAGES} | sed 's/,/ /g')" ;\
    ALPINE_COMPOSER_PACKAGES="" ;\
    if [ -n "${COMPOSER_PACKAGES}" ] ; then \
        ALPINE_COMPOSER_PACKAGES="php82-phar" ;\
        if [ -n "${ALPINE_PACKAGES##*php82-curl*}" ] ; then \
            ALPINE_COMPOSER_PACKAGES="php82-curl ${ALPINE_COMPOSER_PACKAGES}" ;\
        fi ;\
        if [ -n "${ALPINE_PACKAGES##*php82-mbstring*}" ] ; then \
            ALPINE_COMPOSER_PACKAGES="php82-mbstring ${ALPINE_COMPOSER_PACKAGES}" ;\
        fi ;\
    fi \
# Install dependencies
    && apk upgrade --no-cache \
    && apk add --no-cache gnupg nginx curl unzip php82 php82-fpm php82-gd php82-opcache \
        s6 tzdata ${ALPINE_PACKAGES} ${ALPINE_COMPOSER_PACKAGES} \
# Stabilize php config location
    && mv /etc/php82 /etc/php \
    && ln -s /etc/php /etc/php82 \
    && ln -s $(which php82) /usr/local/bin/php \
# Remove (some of the) default nginx & php config
    && rm -f /etc/nginx.conf /etc/nginx/http.d/default.conf /etc/php/php-fpm.d/www.conf \
    && rm -rf /etc/nginx/sites-* \
# Ensure nginx logs, even if the config has errors, are written to stderr
    && ln -s /dev/stderr /var/log/nginx/error.log \
# Support running s6 under a non-root user
    && mkdir -p /etc/s6/services/nginx/supervise /etc/s6/services/php-fpm82/supervise \
    && mkfifo \
        /etc/s6/services/nginx/supervise/control \
        /etc/s6/services/php-fpm82/supervise/control \
    && chown -R ${UID}:${GID} /etc/s6 /run /srv/* /var/lib/nginx /var/www \
    && chmod o+rwx /run /var/lib/nginx /var/lib/nginx/tmp \
# Clean up
    && rm -rf /tmp/* \
    && apk del --no-cache gnupg curl unzip ${ALPINE_COMPOSER_PACKAGES}

COPY etc/ /etc/

RUN curl https://blogengine.ru/download/e2_distr_v${RELEASE}.zip -o a.zip && unzip a.zip && rm a.zip

WORKDIR /var/www
# user nobody, group www-data
USER ${UID}:${GID}

# mark dirs as volumes that need to be writable, allows running the container --read-only
VOLUME /run /srv/data /tmp /var/lib/nginx/tmp

EXPOSE 8080

ENTRYPOINT ["/etc/init.d/rc.local"]
