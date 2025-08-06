#!/bin/bash

# =========================
# WordPress Auto Installer
# Version: Updated with Music & Upload Center
# Author: ashkanr66
# =========================

# Colors
GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
NC="\e[0m"

echo -e "${GREEN}=========================================="
echo "   WordPress Auto Installer for Ubuntu 22.04"
echo -e "==========================================${NC}"

# --- Check if running as root ---
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run this script as root or using sudo.${NC}"
    exit 1
fi

# --- Ask for domain name ---
read -p "Enter your domain name (e.g., example.com): " DOMAIN

# --- Check domain DNS resolution ---
SERVER_IP=$(curl -s http://checkip.amazonaws.com)
DOMAIN_IP=$(dig +short "$DOMAIN" | tail -n 1)

if [ "$DOMAIN_IP" != "$SERVER_IP" ]; then
    echo -e "${YELLOW}Warning: Your domain IP ($DOMAIN_IP) does not match server IP ($SERVER_IP)."
    echo -e "Please make sure your domain's DNS is correctly pointing to this server before continuing.${NC}"
    read -p "Press ENTER to continue anyway or CTRL+C to abort."
fi

# --- Check and open ports 80 and 443 ---
for PORT in 80 443; do
    if ! ss -tuln | grep -q ":$PORT "; then
        echo -e "${YELLOW}Opening port $PORT...${NC}"
        ufw allow $PORT/tcp
    fi
done

# Enable UFW if not enabled
if ! ufw status | grep -q "Status: active"; then
    ufw --force enable
fi

# --- Update system ---
apt update && apt upgrade -y

# --- Install required packages ---
apt install -y apache2 mysql-server php php-mysql libapache2-mod-php php-cli unzip curl wget php-curl php-xml php-mbstring php-zip php-gd php-bcmath php-intl php-soap php-imagick certbot python3-certbot-apache

# --- Enable Apache and MySQL ---
systemctl enable apache2
systemctl enable mysql
systemctl start apache2
systemctl start mysql

# --- Secure MySQL installation ---
MYSQL_ROOT_PASSWORD=$(openssl rand -base64 16)
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$MYSQL_ROOT_PASSWORD'; FLUSH PRIVILEGES;"

# --- Create Database and User ---
DB_NAME="wp_$(openssl rand -hex 3)"
DB_USER="wpuser_$(openssl rand -hex 3)"
DB_PASS=$(openssl rand -base64 16)

mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "CREATE DATABASE $DB_NAME;"
mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost'; FLUSH PRIVILEGES;"

# --- Download WordPress ---
cd /tmp
wget https://wordpress.org/latest.zip
unzip latest.zip
rm latest.zip
mv wordpress /var/www/$DOMAIN

# --- Configure WordPress ---
cp /var/www/$DOMAIN/wp-config-sample.php /var/www/$DOMAIN/wp-config.php
sed -i "s/database_name_here/$DB_NAME/" /var/www/$DOMAIN/wp-config.php
sed -i "s/username_here/$DB_USER/" /var/www/$DOMAIN/wp-config.php
sed -i "s/password_here/$DB_PASS/" /var/www/$DOMAIN/wp-config.php

# --- Set permissions ---
chown -R www-data:www-data /var/www/$DOMAIN
chmod -R 755 /var/www/$DOMAIN

# --- Create Apache Virtual Host ---
cat <<EOF >/etc/apache2/sites-available/$DOMAIN.conf
<VirtualHost *:80>
    ServerName $DOMAIN
    ServerAlias www.$DOMAIN
    DocumentRoot /var/www/$DOMAIN
    <Directory /var/www/$DOMAIN>
        AllowOverride All
        Require all granted
    </Directory>
    ErrorLog \${APACHE_LOG_DIR}/$DOMAIN-error.log
    CustomLog \${APACHE_LOG_DIR}/$DOMAIN-access.log combined
</VirtualHost>
EOF

a2ensite $DOMAIN.conf
a2enmod rewrite
systemctl reload apache2

# --- Obtain SSL Certificate ---
certbot --apache -d $DOMAIN -d www.$DOMAIN --non-interactive --agree-tos -m admin@$DOMAIN || {
    echo -e "${YELLOW}Warning: SSL certificate issuance failed. You can try running certbot manually later.${NC}"
}

# --- Install WP-CLI ---
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar
mv wp-cli.phar /usr/local/bin/wp

# --- Generate random admin credentials ---
WP_ADMIN_USER="admin_$(openssl rand -hex 2)"
WP_ADMIN_PASS=$(openssl rand -base64 16)

# --- Install WordPress with WP-CLI ---
sudo -u www-data wp core install --path="/var/www/$DOMAIN" --url="https://$DOMAIN" --title="My Music Site" --admin_user="$WP_ADMIN_USER" --admin_password="$WP_ADMIN_PASS" --admin_email="admin@$DOMAIN"

# --- Install and activate music-related plugins ---
sudo -u www-data wp plugin install audioigniter --activate
sudo -u www-data wp plugin install video-player --activate
sudo -u www-data wp plugin install filebird --activate
sudo -u www-data wp plugin install increase-max-upload-file-size --activate

# --- Increase upload limits in PHP ---
PHP_INI="/etc/php/$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')/apache2/php.ini"
sed -i "s/upload_max_filesize = .*/upload_max_filesize = 1024M/" $PHP_INI
sed -i "s/post_max_size = .*/post_max_size = 1024M/" $PHP_INI
sed -i "s/memory_limit = .*/memory_limit = 1024M/" $PHP_INI
systemctl restart apache2

# --- Final info display ---
clear
echo -e "${GREEN}=========================================="
echo " WordPress installation completed successfully!"
echo "Site URL: https://$DOMAIN"
echo "Admin Panel: https://$DOMAIN/wp-admin"
echo "Admin Username: $WP_ADMIN_USER"
echo "Admin Password: $WP_ADMIN_PASS"
echo "Database Name: $DB_NAME"
echo "Database User: $DB_USER"
echo "Database Password: $DB_PASS"
echo "MySQL Root Password: $MYSQL_ROOT_PASSWORD"
echo -e "==========================================${NC}"
