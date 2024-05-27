## Main Instance with user-data to install Prisma Cloud Defender
resource "aws_instance" "main_instance" {
  ami                         = data.aws_ami.aws_ubuntu.id
  instance_type               = "t2.medium"
  subnet_id                   = aws_subnet.main_sub.id
  key_name                    = aws_key_pair.keypair.key_name
  associate_public_ip_address = "true"
  vpc_security_group_ids      = [aws_security_group.instance_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.main_profile.name
  root_block_device{
      volume_size = 100
      volume_type = "gp2"
    }
  user_data = <<-BOOTSTRAP
#!/bin/bash
sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get install apt-transport-https ca-certificates wget curl gnupg-agent software-properties-common jq unzip -y
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
PC_SM_PATH="pc/defender"
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
REGION=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -v http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r '.region')
PC_USER="$(aws secretsmanager get-secret-value --region $REGION --secret-id $PC_SM_PATH --query SecretString --output text | jq -r .PC_USER)"
PC_PASS="$(aws secretsmanager get-secret-value --region $REGION --secret-id $PC_SM_PATH --query SecretString --output text | jq -r .PC_PASS)"
PC_URL="$(aws secretsmanager get-secret-value --region $REGION --secret-id $PC_SM_PATH --query SecretString --output text | jq -r .PC_URL)"
PC_SAN="$(aws secretsmanager get-secret-value --region $REGION --secret-id $PC_SM_PATH --query SecretString --output text | jq -r .PC_SAN)"
TOKEN=$(curl -sSLk -d '{"username":"'$PC_USER'","password":"'$PC_PASS'"}' -H 'content-type: application/json' "$PC_URL/api/v1/authenticate" | jq -r '.token')
curl -sSL -k --header "authorization: Bearer $TOKEN" -X POST $PC_URL/api/v1/scripts/defender.sh  | sudo bash -s -- -c "$PC_SAN" -d none --install-host
BOOTSTRAP
  tags = {
    Name   = "main-instance"
  }
}


