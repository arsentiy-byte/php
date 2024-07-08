FROM php:8.1-fpm-alpine

# Установка необходимых пакетов и PHP расширений
RUN apk add --no-cache --update \
    autoconf \
    build-base \
    git \
    postgresql-dev \
    linux-headers \
    shadow \
    libxml2-dev \
    oniguruma-dev \
    supervisor \
    && pecl install redis \
    && docker-php-ext-enable redis \
    && docker-php-ext-install pdo pdo_pgsql pcntl \
    && pecl install apcu \
    && docker-php-ext-enable apcu opcache \
    && rm -rf /var/cache/apk/*

# Установка Composer
COPY --from=composer:latest /usr/bin/composer /usr/local/bin/composer

# Переменная окружения для установки xdebug в режиме разработки
ARG APP_ENV=development

# Установка xdebug в режиме разработки
RUN if [ "$APP_ENV" = "development" ]; then \
        pecl install xdebug && docker-php-ext-enable xdebug; \
    fi

# Копирование конфигурационных файлов
COPY ./config/uploads.ini "$PHP_INI_DIR/conf.d/"
COPY ./config/uploads-opcache.ini "$PHP_INI_DIR/conf.d/"
COPY ./config/supervisord.conf /etc/supervisor/supervisord.conf
COPY ./entrypoint.sh /usr/local/bin/entrypoint
RUN chmod +x /usr/local/bin/entrypoint

# Настройка конфигурации в зависимости от окружения
RUN if [ "$APP_ENV" = "development" ]; then \
        rm "$PHP_INI_DIR/conf.d/uploads-opcache.ini"; \
    else \
        rm "$PHP_INI_DIR/conf.d/uploads.ini" && mv "$PHP_INI_DIR/conf.d/uploads-opcache.ini" "$PHP_INI_DIR/conf.d/uploads.ini"; \
    fi

# Установка рабочей директории
WORKDIR /app

# Копирование файлов приложения
COPY ./index.php /app/public/

# Установка пользователя и группы
ARG WORKER_UID=1000
RUN addgroup -g $WORKER_UID -S app && \
    adduser -u $WORKER_UID -S app -G app

# Установка прав на рабочую директорию
RUN chown -R app:app /app

# Установка entrypoint
ENTRYPOINT ["/usr/local/bin/entrypoint"]
