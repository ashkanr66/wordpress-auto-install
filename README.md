# WordPress Auto Installer for Ubuntu 22.04

This script automates the full installation of a WordPress website on a fresh Ubuntu 22.04 server.

---

## Features

- Automatic installation and setup of Apache, MySQL, PHP (LAMP stack)  
- Automatic creation of MySQL database and user with secure random passwords  
- Download and configure the latest WordPress version  
- Apache virtual host configuration based on your domain  
- Automatic installation and renewal setup of SSL certificate using Let's Encrypt  
- Automatic firewall (`ufw`) installation, activation, and opening of ports 80 and 443  
- Domain DNS resolution and IP match checking before installation  
- Generates and displays admin username and password after installation  

---

## Prerequisites

- A fresh Ubuntu 22.04 server with root or sudo user access  
- A domain name pointed to your server's public IP address  
- Ports 80 and 443 open and accessible  

---

## Installation

Run the following command on your server terminal:

```bash
bash <(curl -s https://raw.githubusercontent.com/ashkanr66/wordpress-auto-install/main/install.sh)
```

---

## How the Script Works

1. Asks for your domain name  
2. Checks your domain DNS and confirms it points to your server IP  
3. Installs and configures the required software stack (Apache, MySQL, PHP)  
4. Sets up the WordPress site automatically  
5. Configures SSL certificate using Let's Encrypt  
6. Shows you the WordPress admin panel URL, username, and password  

---

## Example Output

```
==========================================
 WordPress installation completed successfully!
Site URL: https://yourdomain.com
Admin Panel: https://yourdomain.com/wp-admin
Admin Username: admin_xx12
Admin Password: sX8+9zGh7yKQ
Database Name: wp_a1b2c3
Database User: wpuser_4d5e6f
Database Password: Qw3rTyUiOp
MySQL Root Password: AbCdEfGhIj
==========================================
```

---

## Security Notes

- Keep your WordPress admin credentials safe  
- Change your MySQL root password regularly  
- Regularly update your system and WordPress  
- Backup your site and database frequently  

---

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

---

## Contact

For any issues or suggestions, please open an issue on the [GitHub Repository](https://github.com/ashkanr66/wordpress-auto-install)  
or contact me via my GitHub profile: [https://github.com/ashkanr66](https://github.com/ashkanr66)

---

**Enjoy your WordPress site!**
