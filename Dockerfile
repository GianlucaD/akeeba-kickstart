FROM alpine:3.13
LABEL Maintainer="Gianluca Daffre <luke@daffre.com>" \
      Description="Akeeba Kickstart container based on a Lightweight container with Nginx 1.18 & PHP-FPM 8.0.30 based on Alpine Linux."

# Install packages and remove default server definition
RUN apk --no-cache add php8 php8-fpm php8-simplexml php8-opcache php8-mysqli php8-json php8-openssl php8-curl \
    php8-zlib php8-xml php8-phar php8-intl php8-pear php8-dom php8-xmlreader php8-ctype php8-session \
    php8-mbstring php8-gd nginx supervisor curl php8-zip && \
    rm /etc/nginx/conf.d/default.conf

# Configure nginx
COPY config/nginx.conf /etc/nginx/nginx.conf

# Configure PHP-FPM
COPY config/fpm-pool.conf /etc/php8/php-fpm.d/www.conf
COPY config/php.ini /etc/php8/conf.d/custom.ini

# Configure supervisord
COPY config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Setup document root
RUN mkdir -p /var/www/html

# Make sure files/folders needed by the processes are accessable when they run under the nobody user
RUN chown -R nobody.nobody /var/www/html && \
  chown -R nobody.nobody /run && \
  chown -R nobody.nobody /var/lib/nginx && \
  chown -R nobody.nobody /var/log/nginx

# Define Kickstart version
ENV AKEEBA_KICKSTART_VERSION 7-1-1

# Download package and extract to web volume
RUN v=`echo $AKEEBA_KICKSTART_VERSION | tr "." "-"` \
	&& curl -o kickstart.zip -SL https://www.akeeba.com/download/akeeba-kickstart/${v}/kickstart-core-${v}-zip.zip \
	&& php8 -r '$z = new ZipArchive; $z->open("kickstart.zip"); $z->extractTo("./kickstart");' \
	&& mv kickstart/kickstart.php /var/www/html/ \
	&& rm -rf kickstart*
	
 
# Switch to use a non-root user from here on
USER nobody

# Add application
WORKDIR /var/www/html
COPY --chown=nobody src/ /var/www/html/

# Expose the port nginx is reachable on
EXPOSE 8080

# Let supervisord start nginx & php-fpm
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]

# Configure a healthcheck to validate that everything is up&running
HEALTHCHECK --timeout=10s CMD curl --silent --fail http://127.0.0.1:8080/fpm-ping
