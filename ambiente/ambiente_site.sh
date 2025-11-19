# Atualiza pacotes
sudo apt update && sudo apt upgrade -y

# Dependências
sudo apt install -y ca-certificates curl

# Cria diretório de keyrings
sudo install -m 0755 -d /etc/apt/keyrings

# Baixa a chave GPG do Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo tee /etc/apt/keyrings/docker.asc > /dev/null

# Permissões da chave
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Adiciona repositório Docker
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
  https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Atualiza listas novamente
sudo apt update

# Instala Docker + Compose Plugin
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
