# ─── Base: офіційний wordpress php-fpm на alpine (мінімальний розмір) ───────
FROM wordpress:6.5-php8.2-fpm-alpine

# ─── Системні залежності для PHP розширень ───────────────────────────────────
RUN apk add --no-cache \
    freetype-dev \
    libjpeg-turbo-dev \
    libpng-dev \
    libwebp-dev \
    libzip-dev \
    && docker-php-ext-configure gd \
        --with-freetype \
        --with-jpeg \
        --with-webp \
    && docker-php-ext-install -j"$(nproc)" \
        gd \
        zip \
        opcache \
        mysqli \
        pdo_mysql \
        exif \
    && docker-php-ext-enable opcache

# ─── Кастомний php.ini (production налаштування) ──────────────────────────────
COPY php.ini /usr/local/etc/php/conf.d/99-custom.ini

# ─── php-fpm pool конфіг ──────────────────────────────────────────────────────
# Слухати на 0.0.0.0:9000 (не unix socket) — потрібно для Docker networking
RUN sed -i 's|listen = /run/php/php-fpm.sock|listen = 9000|' \
    /usr/local/etc/php-fpm.d/www.conf 2>/dev/null || true

# ─── Non-root user ───────────────────────────────────────────────────────────
# www-data (uid 82) вже існує в alpine-based образах
# WordPress files повинні належати www-data
RUN chown -R www-data:www-data /var/www/html

USER www-data

EXPOSE 9000

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD php-fpm -t 2>&1 | grep -q "configuration file" || exit 1