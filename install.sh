#!/bin/bash
# WordPress Auto Install Script for Ubuntu 22.04
# Author: ChatGPT (Final Version with DNS check, firewall auto-enable)
# Log File
LOG_FILE="/var/log/wordpress-install.log"
exec > >(tee -i $LOG_FILE)
exec 2>&1

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# --- 1) پرسیدن دامنه ---
read -rp "Enter your domain (e.g., example.com): " DOMAIN

# --- 2) چک کردن اتصال دامنه به IP سرور ---
SERVER_IP=$(hostname -I | awk '{print $1}')
DOMAIN_IP=$(dig +short $DOMAIN A | tail -n 1)

if [ -z "$DOMAIN_IP" ]; then
    echo -e "${RED}[!] Domain $DOMAIN does not have a valid A record.${NC}"
    read -rp "Do you want to continue anyway? (y/n): " CONTINUE
    if [[ ! $CONTINUE =~ ^[Yy]$ ]]; then
        echo "Installation aborted. Please fix your DNS settings first."
        exit 1
    fi
else
    if [ "$SERVER_IP" != "$DOMAIN_IP" ]; then
        echo -e "${RED}[!] Warning: Domain $DOMAIN points to $DOMAIN_IP, but your server IP is $SERVER_IP.${NC}"
        read -rp "Continue installation? (y/n): " CONTINUE
        if [[ ! $CONTINUE =~ ^[Yy]$ ]]; then
            echo "Installation aborted. Please fix your DNS settings first."
            exit 1
        fi
    else
        echo -e "${GREEN}[+] Domain $DOMAIN is correctly pointed to this server.${NC}"
    fi
fi

# --- 3) نصب و فعال‌سازی ufw در صورت نبود ---
if ! command -v ufw &>/dev/null; then
    echo "[!] ufw not found. Installing ufw..."
    apt update && apt install ufw -y
fi

if ! sudo ufw status | grep -q "Status: active"; then
    echo "[!] ufw is not active. Enabling ufw..."
    sudo ufw enable
fi

# --- 4) چک کردن و باز کردن پورت‌ها ---
check_and_open_port() {
  local port=$1
  if ! sudo ufw status | grep -qw "$port"; then
    echo "[!] Port $port is closed. Opening it..."
    sudo ufw allow "$port"/tcp
    sudo ufw reload
    echo "[+] Port $port opened successfully."
  else
    echo "[+] Port $port is already open."
  fi
}

check_and_open_port 80
check_and_open_port 443

# --- 5) بروزرسانی سیستم ---
echo -e "${GREEN}[+] Updating system...${NC}"
apt update && apt upgrade -y

# --- 6) نصب Apache, MySQL, PHP ---
echo -e "${GREEN}[+] Installing Apache, MySQL, PHP...${NC}"
apt install apache2 mysql-server php php-mysql libapache2-mod-php php-cli php-curl php-gd php-xml php-mbstring unzip curl wget dnsutils -y

systemctl enable apache2
systemctl enable mysql
systemctl start apache2
systemctl start mysql

# --- 7) تنظیم MySQL ---
MYSQL_ROOT_PASS=$(openssl rand -base64 12)
echo "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$MYSQL_ROOT_PASS'; FLUSH PRIVILEGES;" | mysql -u root

DB_NAME=wp_$(openssl rand -hex 3)
DB_USER=wpuser_$(openssl rand -hex 3)
DB_PASS=$(openssl rand -base64 12)

mysql -u root -p$MYSQL_ROOT_PASS -e "CREATE DATABASE $DB_NAME;"
mysql -u root -p$MYSQL_ROOT_PASS -e "CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
mysql -u root -p$MYSQL_ROOT_PASS -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost'; FLUSH PRIVILEGES;"

# --- 8) دانلود و تنظیم وردپرس ---
echo -e "${GREEN}[+] Downloading WordPress...${NC}"
wget https://wordpress.org/latest.zip -O /tmp/wordpress.zip
unzip /tmp/wordpress.zip -d /tmp/
rm -rf /var/www/$DOMAIN
mv /tmp/wordpress /var/www/$DOMAIN

cp /var/www/$DOMAIN/wp-config-sample.php /var/www/$DOMAIN/wp-config.php
sed -i "s/database_name_here/$DB_NAME/" /var/www/$DOMAIN/wp-config.php
sed -i "s/username_here/$DB_USER/" /var/www/$DOMAIN/wp-config.php
sed -i "s/password_here/$DB_PASS/" /var/www/$DOMAIN/wp-config.php

chown -R www-data:www-data /var/www/$DOMAIN
chmod -R 755 /var/www/$DOMAIN

# --- 9) ساخت Virtual Host ---
cat <<EOF >/etc/apache2/sites-available/$DOMAIN.conf
<VirtualHost *:80>
    ServerName $DOMAIN
    DocumentRoot /var/www/$DOMAIN
    <Directory /var/www/$DOMAIN>
        AllowOverride All
    </Directory>
    ErrorLog \${APACHE_LOG_DIR}/$DOMAIN-error.log
    CustomLog \${APACHE_LOG_DIR}/$DOMAIN-access.log combined
</VirtualHost>
EOF

a2ensite $DOMAIN.conf
a2enmod rewrite
systemctl reload apache2

# --- 10) نصب SSL با Certbot ---
apt install certbot python3-certbot-apache -y
certbot --apache -d $DOMAIN --non-interactive --agree-tos -m admin@$DOMAIN || echo "[!] SSL installation failed, check logs."

# --- 11) اطلاعات ورود ادمین ---
WP_ADMIN_USER="admin_$(openssl rand -hex 2)"
WP_ADMIN_PASS=$(openssl rand -base64 12)
WP_ADMIN_EMAIL="admin@$DOMAIN"

curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar
mv wp-cli.phar /usr/local/bin/wp

cd /var/www/$DOMAIN || exit
sudo -u www-data wp core install --url="https://$DOMAIN" --title="My WordPress Site" --admin_user="$WP_ADMIN_USER" --admin_password="$WP_ADMIN_PASS" --admin_email="$WP_ADMIN_EMAIL"

echo -e "${GREEN}==========================================${NC}"
echo -e "${GREEN} WordPress installation completed successfully!${NC}"
echo -e "Site URL: https://$DOMAIN"
echo -e "Admin Panel: https://$DOMAIN/wp-admin"
echo -e "Admin Username: $WP_ADMIN_USER"
echo -e "Admin Password: $WP_ADMIN_PASS"
echo -e "Database Name: $DB_NAME"
echo -e "Database User: $DB_USER"
echo -e "Database Password: $DB_PASS"
echo -e "MySQL Root Password: $MYSQL_ROOT_PASS"
echo -e "${GREEN}==========================================${NC}"

exit 0
