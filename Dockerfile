FROM php:8.1.19-apache
# Install apt packages
#
# Required for php extensions
# * gd: libpng-dev, libjpeg62-turbo-dev
# * imagick: libmagickwand-dev
# * imap: libc-client-dev, libkrb5-dev
# * intl: libicu-dev
# * soap: libxml2-dev
# * zip: libzip-dev
#
# Used in the build process
# * git
# * nodejs
# * sudo
# * unzip
# * zip
#
# Other Utilities
# * bash-completion
# * iproute2 (required to get host ip from container)
# * msmtp-mta (for routing mail to maildev)
# * rsync
# * nano
# * vim
# * less

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
  apt-transport-https

  RUN curl -sL https://deb.nodesource.com/setup_14.x | bash - \
    && apt-get update \
  && apt-get install -y --no-install-recommends \
  bash-completion \
  default-mysql-client \
  git \
  iproute2 \
  libc-client-dev \
  libicu-dev \
  libjpeg62-turbo-dev \
  libkrb5-dev \
  libmagickwand-dev \
  libpng-dev \
  libxml2-dev \
  libzip-dev \
  msmtp-mta \
  nano \
  nodejs \
  rsync \
  sudo \
  unzip \
  vim \
  zip \
  vpnc \
  wget \
  memcached \
  telnet \
  && rm -r /var/lib/apt/lists/*

# Install php extensions (curl, json, mbstring, openssl, posix, phar
# are installed already and don't need to be specified here)
RUN docker-php-ext-install bcmath \
  && docker-php-ext-configure gd \
  && docker-php-ext-install gd \
  && docker-php-ext-install gettext \
  && docker-php-ext-configure imap --with-kerberos --with-imap-ssl \
  && docker-php-ext-install imap \
  && docker-php-ext-install intl \
  && docker-php-ext-install mysqli \
  && docker-php-ext-install opcache \
  && docker-php-ext-install pdo_mysql \
  && docker-php-ext-install soap \
  && docker-php-ext-install zip \
  && docker-php-ext-install filter

# Install and enable imagick PECL extensions
RUN pecl install imagick \
  && docker-php-ext-enable imagick

# Install xdebug PECL extension
RUN pecl install xdebug\
    && docker-php-ext-enable xdebug

RUN a2enmod rewrite

RUN a2enmod headers

# Need to create this before we configure apache, otherwise it will complain
RUN mkdir -p .amp/apache.d

RUN mkdir -p .cache/bower

RUN mkdir .composer

RUN mkdir .drush

RUN mkdir .npm

COPY php.ini /usr/local/etc/php/conf.d/php.ini

COPY 000-default.conf /etc/apache2/conf-enabled/

USER root

COPY ./docker-civicrm-entrypoint /usr/local/bin

## Add drush, the next releases(8) of drush not working
RUN curl -sS https://getcomposer.org/installer | php
RUN mv composer.phar /usr/local/bin/composer
RUN composer global require drush/drush:8.*
RUN echo 'export PATH="$HOME/.composer/vendor/drush/drush:$PATH"' >> /root/.bashrc

## Add PHPUnit
RUN composer global require "phpunit/phpunit"
ENV PATH /root/.composer/vendor/bin:$PATH
RUN ln -s /root/.composer/vendor/bin/phpunit /usr/bin/phpunit

## Colors

RUN echo "" >> /root/.bashrc
RUN echo "" >> /root/.bashrc
RUN echo "alias ll='ls -alF --color=auto'" >> /root/.bashrc
RUN echo "alias la='ls -A'" >> /root/.bashrc
RUN echo "alias l='ls -CF'" >> /root/.bashrc

## Add civicrm_buildkit
WORKDIR /buildkit

ENV PATH="/buildkit/bin:${PATH}"

RUN git init . \
    && git remote add origin https://github.com/rubofvil/civicrm-buildkit.git \
    && git pull origin master

RUN git clone https://github.com/squizlabs/PHP_CodeSniffer

WORKDIR /tmp
RUN curl -OL https://squizlabs.github.io/PHP_CodeSniffer/phpcs.phar && \
    cp /tmp/phpcs.phar /usr/local/bin/phpcs && \
    chmod +x /usr/local/bin/phpcs

WORKDIR /buildkit

RUN git clone https://github.com/civicrm/coder.git
RUN phpcs --config-set installed_paths /buildkit/coder/coder_sniffer

USER root

COPY ./docker-civicrm-entrypoint /usr/local/bin

RUN chmod u+x /usr/local/bin/docker-civicrm-entrypoint

CMD ["apache2-foreground"]

RUN rm /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini

## Install cv
RUN sudo curl -LsS https://download.civicrm.org/cv/cv.phar -o /usr/local/bin/cv
RUN sudo chmod +x /usr/local/bin/cv

## Install drupal console
RUN curl https://drupalconsole.com/installer -L -o drupal.phar
RUN mv drupal.phar /usr/local/bin/drupal
RUN chmod +x /usr/local/bin/drupal

ENV CONTAINER_IP=$("hostname -i")
