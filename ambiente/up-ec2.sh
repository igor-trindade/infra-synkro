#!/bin/bash
set -e  # Encerra o script em caso de erro

KEY_NAME="synkro-key$(date +%Y%m%d%H%M%S)"
AMI_ID="ami-053b0d53c279acc90"
INSTANCE_TYPE="t3.small"
USER_DATA_FILE="./preparacao_ambiente.sh"
SECURITY_GROUP_NAME="launch-wizard-42"
SECURITY_GROUP_DESC="grupo-seguranca-042"

REGION="us-east-1"
SO="Ubuntu"

echo "===== PEGANDO A VPC E SUB-REDE ====="
VPC_ID=$(aws ec2 describe-vpcs --query "Vpcs[0].VpcId" --region "$REGION" --output text)
echo "VPC ID: $VPC_ID"

SUBNET_ID=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query "Subnets[0].SubnetId" --region "$REGION" --output text)
echo "Subnet ID: $SUBNET_ID"

IGW_ID=$(aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$VPC_ID" --region "$REGION" --query "InternetGateways[0].InternetGatewayId" --output text)

if [ "$IGW_ID" == "None" ]; then
    echo "Nenhum Gateway de Internet encontrado. Criando um novo..."
    IGW_ID=$(aws ec2 create-internet-gateway --region "$REGION" --query "InternetGateway.InternetGatewayId" --output text)
    aws ec2 attach-internet-gateway --internet-gateway-id "$IGW_ID" --vpc-id "$VPC_ID" --region "$REGION"
    echo "Gateway de Internet criado e associado: $IGW_ID"
else
    echo "Gateway de Internet já existe: $IGW_ID"
fi
echo
echo
echo "===== CRIANDO CHAVE .PEM ====="

    aws ec2 create-key-pair \
        --key-name "$KEY_NAME" \
        --region "$REGION" \
        --query 'KeyMaterial' \
        --output text > "$KEY_NAME.pem"
    chmod 400 "$KEY_NAME.pem"
    echo "Chave criada: $KEY_NAME.pem"

echo
echo
echo "===== VERIFICANDO SE O GRUPO DE SEGURANÇA JÁ EXISTE ====="
SG_ID=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=$SECURITY_GROUP_NAME" "Name=vpc-id,Values=$VPC_ID" \
    --query "SecurityGroups[0].GroupId" \
    --region "$REGION" --output text || echo "None")

if [ "$SG_ID" == "None" ]; then
    echo "Grupo de segurança $SECURITY_GROUP_NAME não encontrado. Criando novo..."
    SG_ID=$(aws ec2 create-security-group \
        --group-name "$SECURITY_GROUP_NAME" \
        --description "$SECURITY_GROUP_DESC" \
        --vpc-id "$VPC_ID" \
        --tag-specifications "ResourceType=security-group,Tags=[{Key=Name,Value=sg-042}]" \
        --region "$REGION" \
        --query 'GroupId' \
        --output text)
    echo "Grupo de segurança criado: $SG_ID"
else
    echo "Grupo de segurança $SECURITY_GROUP_NAME já existe. Usando o existente."
fi
echo
echo
echo "===== ADICIONANDO REGRAS DE ENTRADA ====="

HTTP_EXISTS=$(aws ec2 describe-security-group-rules \
    --region "$REGION" \
    --filters "Name=group-id,Values=$SG_ID" \
    --query "SecurityGroupRules[?FromPort==\`80\` && ToPort==\`80\` && IpProtocol=='tcp' && CidrIpv4=='0.0.0.0/0'] | length(@)" \
    --output text)

if [ "$HTTP_EXISTS" -ge 1 ]; then
    echo "Regra de entrada para HTTP (porta 80) já existe."
else
    aws ec2 authorize-security-group-ingress \
        --group-id "$SG_ID" \
        --protocol tcp \
        --port 80 \
        --cidr "0.0.0.0/0" \
        --region "$REGION"
    echo "Regra de entrada para HTTP (porta 80) adicionada com sucesso."
fi


SSH_EXISTS=$(aws ec2 describe-security-group-rules \
    --region "$REGION" \
    --filters "Name=group-id,Values=$SG_ID" \
    --query "SecurityGroupRules[?FromPort==\`22\` && ToPort==\`22\` && IpProtocol=='tcp' && CidrIpv4=='0.0.0.0/0'] | length(@)" \
    --output text)

if [ "$SSH_EXISTS" -ge 1 ]; then
    echo "Regra de entrada para SSH (porta 22) já existe."
else
    aws ec2 authorize-security-group-ingress \
        --group-id "$SG_ID" \
        --protocol tcp \
        --port 22 \
        --cidr "0.0.0.0/0" \
        --region "$REGION"
    echo "Regra de entrada para SSH (porta 22) adicionada com sucesso."
fi

DB_EXISTS=$(aws ec2 describe-security-group-rules \
    --region "$REGION" \
    --filters "Name=group-id,Values=$SG_ID" \
    --query "SecurityGroupRules[?FromPort==\`3306\` && ToPort==\`3306\` && IpProtocol=='tcp'] | length(@)" \
    --output text)

if [ "$DB_EXISTS" -ge 1 ]; then
    echo "Regra de entrada para DB (3306) já existe."
else
    aws ec2 authorize-security-group-ingress \
        --group-id "$SG_ID" \
        --protocol tcp \
        --port 3306 \
        --source-group "$SG_ID" \
        --region "$REGION"
    echo "Regra de entrada para DB (3306) adicionada **somente entre instâncias**."
fi

echo "Regras de entrada verificadas (HTTP, SSH e DB)."
echo
echo

echo "===== CRIANDO AS INSTÂNCIAS EC2 ====="


USER_DATA_FILES=("ambiente_site.sh" "ambiente_banco.sh" "ambiente_java.sh")
TAG_NAMES=("EC2-SYNKRO-SITE" "EC2-SYNKRO-DB" "EC2-SYNKRO-JAVA")

for i in "${!USER_DATA_FILES[@]}"; do
    USER_DATA_FILE="${USER_DATA_FILES[$i]}"
    TAG_NAME="${TAG_NAMES[$i]}"

    INSTANCE_ID=$(aws ec2 run-instances \
        --image-id "$AMI_ID" \
        --count 1 \
        --instance-type "$INSTANCE_TYPE" \
        --security-group-ids "$SG_ID" \
        --subnet-id "$SUBNET_ID" \
        --key-name "$KEY_NAME" \
        --block-device-mappings '[{"DeviceName":"/dev/sda1","Ebs":{"VolumeSize":20,"VolumeType":"gp3","DeleteOnTermination":true}}]' \
        --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$TAG_NAME}]" \
        --user-data file://"$USER_DATA_FILE" \
        --region "$REGION" \
        --query 'Instances[0].InstanceId' \
        --output text)

    echo "Instância criada: $INSTANCE_ID"
    echo "Aguardando inicialização..."
    aws ec2 wait instance-running --instance-ids "$INSTANCE_ID" --region "$REGION"

    PUBLIC_IP=$(aws ec2 describe-instances \
        --instance-ids "$INSTANCE_ID" \
        --region "$REGION" \
        --query 'Reservations[0].Instances[0].PublicIpAddress' \
        --output text)

    TYPE=$(aws ec2 describe-instances \
        --instance-ids "$INSTANCE_ID" \
        --region "$REGION" \
        --query 'Reservations[0].Instances[0].InstanceType' \
        --output text)

    echo
    echo "=========== INSTÂNCIA CRIADA $TAG_NAME ==========="
    echo "Tipo: $TYPE | SO: $SO | User-data: $USER_DATA_FILE | IP Público: $PUBLIC_IP"
    echo "SSH:"
    echo "ssh -i $KEY_NAME.pem ubuntu@$PUBLIC_IP"
    echo
done
