# Data for AZs and latest AMI
data "aws_availability_zones" "available" {}

data "aws_ssm_parameter" "amazon_linux_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# VPC Setup
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  tags = { Name = "main-vpc" }
}

resource "aws_subnet" "public" {
  count = 2
  vpc_id = aws_vpc.main.id
  cidr_block = var.public_subnets[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  tags = { Name = "public-subnet-${count.index}" }
}

resource "aws_subnet" "private" {
  count = 2
  vpc_id = aws_vpc.main.id
  cidr_block = var.private_subnets[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = { Name = "private-subnet-${count.index}" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = { Name = "main-igw" }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id = aws_subnet.public[0].id
  tags = { Name = "main-nat" }
}

resource "aws_eip" "nat" {}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "public-rt" }
}

resource "aws_route_table_association" "public" {
  count = 2
  subnet_id = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = { Name = "private-rt" }
}

resource "aws_route_table_association" "private" {
  count = 2
  subnet_id = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# Application Load Balancer
resource "aws_lb" "alb" {
  name = "app-alb"
  internal = false
  load_balancer_type = "application"
  security_groups = [aws_security_group.alb.id]
  subnets = aws_subnet.public[*].id
  tags = { Name = "app-alb" }
}

resource "aws_lb_target_group" "app" {
  name = "app-tg"
  port = 80
  protocol = "HTTP"
  vpc_id = aws_vpc.main.id
  target_type = "instance"  # For EC2 ASG
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port = 80
  protocol = "HTTP"
  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# Auto Scaling Group with EC2 in private subnets
resource "aws_launch_template" "app_lt" {
  name_prefix   = "app-lt-"
  image_id      = data.aws_ssm_parameter.amazon_linux_ami.value
  instance_type = var.instance_type
  key_name      = aws_key_pair.bastion.key_name
  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.ec2.id]
  }
  user_data = base64encode("#!/bin/bash\necho 'User data for initial setup'")

  lifecycle {
    create_before_destroy = true
  }
}

# Auto Scaling Group (updated to use launch template)
resource "aws_autoscaling_group" "app_asg" {
  name                = "app-asg"
  launch_template {
    id      = aws_launch_template.app_lt.id
    version = "$Latest"
  }
  min_size            = 1
  max_size            = 3
  desired_capacity    = 2
  vpc_zone_identifier = aws_subnet.private[*].id
  target_group_arns   = [aws_lb_target_group.app.arn]
  health_check_type   = "ELB"

  tag {
    key                 = "Name"
    value               = "app-instance"
    propagate_at_launch = true
  }
}

# RDS PostgreSQL
resource "aws_db_subnet_group" "rds" {
  name = "rds-subnet-group"
  subnet_ids = aws_subnet.private[*].id
}

resource "aws_db_instance" "postgres" {
  allocated_storage = 20
  storage_type = "gp2"
  engine = "postgres"
  engine_version = "17.6"  # Update to latest if needed
  instance_class = "db.t3.micro"
  db_name = "appdb"
  username = var.db_username
  password = var.db_password
  db_subnet_group_name = aws_db_subnet_group.rds.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  multi_az = false  # For cost savings
  publicly_accessible = false
  skip_final_snapshot = true
  tags = { Name = "app-rds" }
}

# Security Groups
resource "aws_security_group" "alb" {
  vpc_id = aws_vpc.main.id
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "alb-sg" }
}

resource "aws_security_group" "ec2" {
  vpc_id = aws_vpc.main.id
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    security_groups = [aws_security_group.alb.id]
  }
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "ec2-sg" }
}

resource "aws_security_group" "rds" {
  vpc_id = aws_vpc.main.id
  ingress {
    from_port = 5432
    to_port = 5432
    protocol = "tcp"
    security_groups = [aws_security_group.ec2.id]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "rds-sg" }
}

resource "aws_security_group" "bastion" {
  vpc_id = aws_vpc.main.id
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Restrict to your IP in production: ["<your-ip>/32"]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "bastion-sg" }
}

# Bastion Host
resource "aws_key_pair" "bastion" {
  key_name = "bastion-key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCqOQCh3Rnp5vnB7Elm1tl0ndXKs8J/LViA5I2Pt1YPhz/8AOH+U4O2EizWpw6P3pLx8LSqqbur2vqe8Sbl2QsfQm+CrV9ohyPT9mXvzvovRMeh8qoPSyuMTsNnYMXhG2vSBiPBGusn4d6IbsnP087unfBSfExeuwDdar5aRvAmo0eRxLABZg30JPmKGjXgKg7pR69In8MyFGzWhlQ4JBkG+GqRXeqT4CFx2Q67u3D3qGiGVt8l95T3sXYpyBuBiGRGCAY0pvNN5IP62Y4eX0tkVybiFEeXGmXkFumUZTm60PCd02dKPOseZ+fTtAkCrgm7eDSyuUE+qorKshu+Loeg6yaY36ZrwRfNmF1469Q5M4EHGyrfiY/G2D7/Mao5HN1In7G2M+YMORCoeymPUuB8+JiZ+GjYR3bNZYr2KePXV357Q1YMaKGWt5nuOG+44NE8l77RIdpQ+KDNnGOrtDRoAzF9VgbQR3ihcQM4WJb28w+W1GwFukI/fN01S+0w77cKdQpY8oV/DPmhftrCBkhx1CP7k2GoOvNvKo4rWiJtj5WSJpsBtSyFcLKbtFyR4MGWrCAnz3TlrmjUyB0iC/5YuJSi/FEeDZNIebe39ONylz2Bm0jC1/66cAg+Wwovq84dRNOSxY2C2SVvgq0EHim+az7zOtLH6uKLgngXka1iBw== vsiva@Siva"  # generate with ssh-keygen if needed
}
resource "aws_instance" "bastion" {
  ami = data.aws_ssm_parameter.amazon_linux_ami.value
  instance_type = var.instance_type
  subnet_id = aws_subnet.public[0].id
  security_groups = [aws_security_group.bastion.id]
  key_name = aws_key_pair.bastion.key_name
  tags = { Name = "bastion" }
}
