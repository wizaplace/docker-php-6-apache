FROM debian:jessie

RUN apt-get update && \
    apt-get install -y --no-install-recommends git ca-certificates wget \
        make build-essential autoconf libicu-dev \
        apache2-bin apache2.2-common apache2-dev && \
    rm -rf /var/lib/apt/lists/*

# PHP dependencies
RUN wget https://ftp.gnu.org/gnu/bison/bison-2.4.1.tar.gz && \
    tar xzf bison-2.4.1.tar.gz && \
    cd bison-2.4.1 && \
    ./configure && \
    make -j "$(nproc)" && \
    make install && \
    cd .. && \
    rm -rf bison-2.4.1 bison-2.4.1.tar.gz

RUN wget ftp://xmlsoft.org/libxml2/libxml2-2.8.0.tar.gz && \
    tar xzf libxml2-2.8.0.tar.gz && \
    cd libxml2-2.8.0 && \
    ./configure && \
    make -j "$(nproc)" && \
    make install && \
    cd .. && \
    rm -rf libxml2-2.8.0 libxml2-2.8.0.tar.gz

# PHP
RUN git clone -b experimental/first_unicode_implementation --single-branch https://github.com/php/php-src.git && \
    cd php-src && \
    ./buildconf && \
    ./configure --with-apxs2 && \
    make -j "$(nproc)" && \
    make install && \
    cd .. && \
    rm -rf php-src

# APACHE
ENV APACHE_CONFDIR /etc/apache2
ENV APACHE_ENVVARS $APACHE_CONFDIR/envvars

RUN set -ex \
	\
# generically convert lines like
#   export APACHE_RUN_USER=www-data
# into
#   : ${APACHE_RUN_USER:=www-data}
#   export APACHE_RUN_USER
# so that they can be overridden at runtime ("-e APACHE_RUN_USER=...")
	&& sed -ri 's/^export ([^=]+)=(.*)$/: ${\1:=\2}\nexport \1/' "$APACHE_ENVVARS" \
	\
# setup directories and permissions
	&& . "$APACHE_ENVVARS" \
	&& for dir in \
		"$APACHE_LOCK_DIR" \
		"$APACHE_RUN_DIR" \
		"$APACHE_LOG_DIR" \
		/var/www/html \
	; do \
		rm -rvf "$dir" \
		&& mkdir -p "$dir" \
		&& chown -R "$APACHE_RUN_USER:$APACHE_RUN_GROUP" "$dir"; \
	done

# Apache + PHP requires preforking Apache for best results
RUN a2dismod mpm_event && a2enmod mpm_prefork

# logs should go to stdout / stderr
RUN set -ex \
	&& . "$APACHE_ENVVARS" \
	&& ln -sfT /dev/stderr "$APACHE_LOG_DIR/error.log" \
	&& ln -sfT /dev/stdout "$APACHE_LOG_DIR/access.log" \
	&& ln -sfT /dev/stdout "$APACHE_LOG_DIR/other_vhosts_access.log"

# PHP files should be handled by PHP, and should be preferred over any other file type
RUN { \
		echo '<FilesMatch \.php$>'; \
		echo '\tSetHandler application/x-httpd-php'; \
		echo '</FilesMatch>'; \
		echo; \
		echo 'DirectoryIndex disabled'; \
		echo 'DirectoryIndex index.php index.html'; \
		echo; \
		echo '<Directory /var/www/>'; \
		echo '\tOptions -Indexes'; \
		echo '\tAllowOverride All'; \
		echo '</Directory>'; \
	} | tee "$APACHE_CONFDIR/conf-available/docker-php.conf" \
&& a2enconf docker-php

COPY apache2-foreground /usr/local/bin/
WORKDIR /var/www/html

EXPOSE 80
CMD ["apache2-foreground"]
