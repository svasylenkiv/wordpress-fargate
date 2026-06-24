FROM nginx:1.25-alpine

# Прибрати дефолтний конфіг
RUN rm /etc/nginx/conf.d/default.conf

# Наш конфіг
COPY conf.d/wordpress.conf /etc/nginx/conf.d/wordpress.conf

# nginx:alpine має користувача nginx (не www-data) — не змінювати user у nginx.conf

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD wget -qO- http://127.0.0.1/nginx-health || exit 1