terraform {
required_providers {
aws = {
      source = "hashicorp/aws"
      version = "5.74.0"
    }
  }
}

provider "aws" {
  region = "us-west-1"
}

resource "aws_vpc" "main" {
  cidr_block       = "10.10.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "myvpc"
  }
}
resource "aws_subnet" "main1" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.10.1.0/24"
  availability_zone = "us-west-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "Public1"
  }
}
resource "aws_subnet" "main2" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.10.2.0/24"
  availability_zone = "us-west-1b"
  map_public_ip_on_launch = false

  tags = {
    Name = "Private1"
  }
}
resource "aws_internet_gateway" "gw" {
vpc_id = aws_vpc.main.id

  tags = {
    Name = "IGW"
  }
}
resource "aws_route_table" "MRT" {
vpc_id = aws_vpc.main.id

  route {
cidr_block = "0.0.0.0/0"
gateway_id = aws_internet_gateway.gw.id
  }


  tags = {
    Name = "MRT"
  }
}
resource "aws_eip" "nat_eip1" {
vpc=true
}
resource "aws_nat_gateway" "NGW1" {
allocation_id = aws_eip.nat_eip1.id
subnet_id     = aws_subnet.main1.id
  tags = {
    Name = "NAT1"
  }
}
resource "aws_route_table" "CRT1" {
vpc_id = aws_vpc.main.id

  route {
cidr_block     = "0.0.0.0/0"
nat_gateway_id = aws_nat_gateway.NGW1.id
  }

  tags = {
    Name = "CRT1"
  }
}
resource "aws_route_table_association" "Public_association1" {
subnet_id      = aws_subnet.main1.id
route_table_id = aws_route_table.MRT.id
}
resource "aws_route_table_association" "Private_association2" {
subnet_id      = aws_subnet.main2.id
route_table_id = aws_route_table.CRT1.id
}

variable "sg_ports" {
  type        = list
  description = "list of ingress ports"
  default     = [22,80,8080,443]
}
resource "aws_security_group" "dynamicsg" {
vpc_id     = aws_vpc.main.id
  name        = "dynamic-sg"
  description = "Ingress for Vault"

  dynamic "ingress" {
    for_each = var.sg_ports
    iterator = port
    content {
      from_port   = port.value
      to_port     = port.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
}
resource "aws_key_pair" "deployer" {
  key_name   = "mykey"
  public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO+hH81N7t/sQTYfBbcGqnVzil3RQ0BsD6iR/Gyybwoe Dell@DESKTOP-MDQ9LEM"
}

resource "aws_instance" "my_ec2_instance1" {
  ami           = "ami-038bba9a164eb3dc1" 
  instance_type = "t2.micro"
  key_name = aws_key_pair.deployer.key_name
  subnet_id     = aws_subnet.main1.id
  #associate_public_ip_address = true
  vpc_security_group_ids = [aws_security_group.dynamicsg.id]
  tags = {
    Name = "pub1"
  }
}
  resource "aws_instance" "my_ec2_instance2" {
  ami           = "ami-038bba9a164eb3dc1" 
  instance_type = "t2.micro"
  key_name = aws_key_pair.deployer.key_name
  subnet_id     = aws_subnet.main2.id
  vpc_security_group_ids = [aws_security_group.dynamicsg.id]
  tags = {
    Name = "pri1"
  }
  }