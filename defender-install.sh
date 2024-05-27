#!/bin/bash
## This document just served as an explaination on each section of the script
## Updating existing libraries & installing required binaries
sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get install apt-transport-https ca-certificates wget curl gnupg-agent software-properties-common jq unzip -y

## Installing AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

## Setting path for AWS Secret Manager & Retriving credentials for Prisma Cloud
PC_SM_PATH="pc/defender"
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
REGION=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -v http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r '.region')
PC_USER="$(aws secretsmanager get-secret-value --region $REGION --secret-id $PC_SM_PATH --query SecretString --output text | jq -r .PC_USER)"
PC_PASS="$(aws secretsmanager get-secret-value --region $REGION --secret-id $PC_SM_PATH --query SecretString --output text | jq -r .PC_PASS)"
PC_URL="$(aws secretsmanager get-secret-value --region $REGION --secret-id $PC_SM_PATH --query SecretString --output text | jq -r .PC_URL)"
PC_SAN="$(aws secretsmanager get-secret-value --region $REGION --secret-id $PC_SM_PATH --query SecretString --output text | jq -r .PC_SAN)"

## Authenticating to Prisma Cloud
TOKEN=$(curl -sSLk -d '{"username":"'$PC_USER'","password":"'$PC_PASS'"}' -H 'content-type: application/json' "$PC_URL/api/v1/authenticate" | jq -r '.token')

## Generate installation script and install Defender
curl -sSL -k --header "authorization: Bearer $TOKEN" -X POST $PC_URL/api/v1/scripts/defender.sh  | sudo bash -s -- -c "$PC_SAN" -d none --install-host