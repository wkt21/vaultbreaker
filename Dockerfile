FROM php:7.4-apache

# Flag 2 lives only in the runtime environment, never in any committed source file.
ENV VAULT_FLAG2=HTB{cr4ck3d_th3_4dm1n_p4ssw0rd}

# sudo = privesc primitive (GTFOBins `find`); sqlite3 = DB init in entrypoint.
RUN apt-get update \
    && apt-get install -y --no-install-recommends sudo sqlite3 \
    && rm -rf /var/lib/apt/lists/* \
    && docker-php-ext-install pdo pdo_sqlite

COPY html/ /var/www/html/
COPY flags/flag1.txt /var/www/flag1.txt
COPY flags/flag3.txt /root/flag3.txt

RUN mkdir -p /var/www/html/data /var/www/html/uploads /var/www/html/pages \
    && chown -R www-data:www-data /var/www/html \
    && chown www-data:www-data /var/www/flag1.txt \
    && chmod 644 /var/www/flag1.txt \
    && chmod 600 /root/flag3.txt \
    && chown root:root /root/flag3.txt \
    && echo 'www-data ALL=(ALL) NOPASSWD: /usr/bin/find' >> /etc/sudoers

COPY docker-entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 80

ENTRYPOINT ["/entrypoint.sh"]
