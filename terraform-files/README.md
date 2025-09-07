# DevOps Assignment: Scalable Web Application Infrastructure

## Part 1: Infrastructure as Code

### What Was Done
This repository contains Terraform code to provision the following AWS infrastructure:
- **VPC and Subnets**: A VPC with CIDR `10.0.0.0/16`, two public subnets, and two private subnets across two Availability Zones.
- **Internet and NAT Gateways**: An Internet Gateway for public access and a NAT Gateway for private subnet outbound traffic, with configured route tables.
- **Application Load Balancer (ALB)**: An ALB in public subnets with a listener on port 80 and a target group for EC2 instances.
- **Auto Scaling Group (ASG)**: An ASG with 2 desired EC2 instances (min 1, max 3) in private subnets, using a launch template.
- **RDS PostgreSQL**: A PostgreSQL database in private subnets with username `app_admin` and 20 GB storage.
- **Security Groups**: 
  - ALB: HTTP (port 80) and HTTPS (port 443) from `0.0.0.0/0`.
  - EC2: Port 80 from ALB, SSH (port 22) from Bastion.
  - RDS: Port 5432 from EC2.
  - Bastion: SSH (port 22) from `0.0.0.0/0`.
- **Bastion Host**: An EC2 instance in a public subnet for SSH access to private instances.

### Prerequisites
- AWS account with CLI configured (`aws configure`).
- Terraform installed (e.g., `sudo apt-get install terraform`). 
- Git installed.
- SSH key pair (e.g., `~/.ssh/bastion-key.pem`) for Bastion access.

### Deployment Instructions
1. Clone the repository:
   ```bash
   git clone https://github.com/siva0199/devops-assignment.git
   cd devops-assignment
2. Initialize Terraform:
   - terraform init
3. validate
   - terraform validate
5. Review the plan:
   - terraform plan
6. Apply the configuration:
   - terraform apply


