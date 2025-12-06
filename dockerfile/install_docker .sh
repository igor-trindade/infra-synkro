#!/bin/bash

# Atualiza pacotes
sudo apt update -y
sudo apt upgrade -y

# Remove versões antigas
sudo apt remove docker docker-engine docker.io containerd runc -y

# Instala dependências
sudo apt install ca-certificates curl gnupg lsb-release -y

# Adiciona chave oficial Docker
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Adiciona repositório estável do Docker
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Atualiza lista de pacotes
sudo apt update -y

# Instala Docker e Docker Compose
sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y

# Ativa e inicia o serviço
sudo systemctl enable docker
sudo systemctl start docker

# Cria grupo docker (se não existir)
sudo groupadd docker 2>/dev/null

# Adiciona usuário atual ao grupo docker
sudo usermod -aG docker $USER

# Aplica permissões sem reiniciar
newgrp docker <<EONG
echo "Permissões do grupo docker aplicadas."
EONG

# Teste básico
docker --version
docker compose version
docker run hello-world

echo "Docker instalado e usuário adicionado ao grupo docker!"
