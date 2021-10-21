FROM alpine:3.12
LABEL Maintainer="Gianluca Daffre <luke@daffre.com>" \
      Description="Akeeba Kickstart container based on a Lightweight container with Nginx 1.18 & PHP-FPM 7.3 based on Alpine Linux."

# Install packages and remove default server definition
RUN apk --no-cache add php7 php7-fpm php7-simplexml php7-opcache php7-mysqli php7-json php7-openssl php7-curl \
    php7-zlib php7-xml php7-phar php7-intl php7-pear php7-dom php7-xmlreader php7-ctype php7-session \
    php7-mbstring php7-gd nginx supervisor curl php7-zip&& \
    rm /etc/nginx/conf.d/default.conf

# Configure nginx
COPY config/nginx.conf /etc/nginx/nginx.conf

# Configure PHP-FPM
COPY config/fpm-pool.conf /etc/php7/php-fpm.d/www.conf
COPY config/php.ini /etc/php7/conf.d/custom.ini

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
ENV AKEEBA_KICKSTART_VERSION 7-1-0

# Download package and extract to web volume
RUN v=`echo $AKEEBA_KICKSTART_VERSION | tr "." "-"` \
	&& curl -o kickstart.zip -SL https://www.akeeba.com/download/akeeba-kickstart/${v}/kickstart-core-${v}-zip.zip \
	&& php -r '$z = new ZipArchive; $z->open("kickstart.zip"); $z->extractTo("./kickstart");' \
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
