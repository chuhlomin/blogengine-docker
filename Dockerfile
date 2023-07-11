FROM alpine:3.18.2

ARG ALPINE_PACKAGES="php82-curl php82-iconv php82-pdo_mysql php82-pdo_pgsql php82-openssl php82-simplexml php82-mbstring libpng-dev"
ARG RELEASE=4116
ARG UID=65534
ARG GID=82

ENV CONFIG_PATH=/srv/cfg
ENV PATH=$PATH:/srv/bin

RUN \
# Prepare composer dependencies
    ALPINE_PACKAGES="$(echo ${ALPINE_PACKAGES} | sed 's/,/ /g')" \
# Install dependencies
    && apk upgrade --no-cache \
    && apk add --no-cache gnupg nginx curl unzip php82 php82-fpm php82-gd php82-opcache \
        s6 tzdata ${ALPINE_PACKAGES} \
    && docker-php-ext-install mysqli \
# Stabilize php config location
    && mv /etc/php82 /etc/php \
    && ln -s /etc/php /etc/php82 \
    && ln -s $(which php82) /usr/local/bin/php \
# Remove (some of the) default nginx & php config
    && rm -f /etc/nginx.conf /etc/nginx/http.d/default.conf /etc/php/php-fpm.d/www.conf \
    && rm -rf /etc/nginx/sites-* \
# Ensure nginx logs, even if the config has errors, are written to stderr
    && ln -s /dev/stderr /var/log/nginx/error.log \
# Download and unzip Aegea
    && curl https://blogengine.ru/download/e2_distr_v${RELEASE}.zip -o a.zip \
    && unzip -q -d /var/www/ a.zip \
    && rm a.zip \
# Support running s6 under a non-root user
    && mkdir -p /etc/s6/services/nginx/supervise /etc/s6/services/php-fpm82/supervise \
    && mkfifo \
        /etc/s6/services/nginx/supervise/control \
        /etc/s6/services/php-fpm82/supervise/control \
    && chown -R ${UID}:${GID} /run /var/lib/nginx /var/www \
    && chmod o+rwx /run /var/lib/nginx /var/lib/nginx/tmp \
# Clean up
    && rm -rf /tmp/* \
    && apk del --no-cache gnupg unzip

COPY etc/ /etc/

# Fix access rights
RUN chown -R ${UID}:${GID} /etc/s6 /etc/init.d/rc.local \
    && chmod +x /etc/init.d/rc.local /etc/s6/services/nginx/run /etc/s6/services/php-fpm82/run 

WORKDIR /var/www
# user nobody, group www-data
USER ${UID}:${GID}

# mark dirs as volumes that need to be writable, allows running the container --read-only
VOLUME /run /srv/data /tmp /var/lib/nginx/tmp

EXPOSE 8080

ENTRYPOINT ["/etc/init.d/rc.local"]
