#!/bin/bash


ROOT_PASS="root"        # Senha do root
DB_USER="site"          # Nome do usuário
DB_USER_PASS="synkro"    # Senha do usuário
### ================================

echo "Atualizando sistema..."
sudo apt update && sudo apt upgrade -y

echo "Instalando MySQL..."
sudo apt install -y mysql-server

echo "Iniciando serviço MySQL..."
sudo systemctl start mysql
sudo systemctl enable mysql


echo "Configurando senha do root..."
sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$ROOT_PASS'; FLUSH PRIVILEGES;"


echo "Criando usuário..."
sudo mysql -u root -p"$ROOT_PASS" -e "CREATE USER IF NOT EXISTS '$DB_USER'@'%' IDENTIFIED BY '$DB_USER_PASS';"


echo "Dando permissões ao usuário..."
sudo mysql -u root -p"$ROOT_PASS" -e "GRANT SELECT, UPDATE, INSERT, DELETE ON $DB_NAME.* TO '$DB_USER'@'%'; FLUSH PRIVILEGES;"


echo "Liberando acesso remoto no MySQL..."
sudo sed -i "s/^bind-address.*/bind-address = 0.0.0.0/" /etc/mysql/mysql.conf.d/mysqld.cnf
sudo systemctl restart mysql


echo "Liberando porta 3306 no firewall (se UFW estiver ativo)..."
sudo ufw allow 3306/tcp || true
