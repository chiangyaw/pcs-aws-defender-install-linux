# Installing Prisma Cloud Defender at Launch with user-data script

This is an example of a Terraform script which covers the following:
1. Create necessary infrastructure for a EC2 instance with internet access
2. Create a Ubuntu EC2 instance which runs a user-data script that installs the necessary binaries and Prisma Cloud Defender

To execute the Terraform script, you will need to have an AWS account, with the credentials stored as environment variables before executing ```terraform apply```.