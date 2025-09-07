variable "region" {
  default = "us-east-1"
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "public_subnets" {
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnets" {
  default = ["10.0.3.0/24", "10.0.4.0/24"]
}

variable "db_username" {
  default = "app_admin" 
}

variable "db_password" {
  default = "securepassword123" 
}

variable "instance_type" {
  default = "t3.micro"
}
