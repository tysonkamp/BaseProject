terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

provider "aws" { 
  region = "us-east-1" 
  # access_key = "never_do_this"
  # secret_key = "never_do_this_either"
}

# data "aws_vpc" "default" { default = true }
# data "aws_subnet_ids" "all" { vpc_id = data.aws_vpc.default.id }

resource "aws_vpc" "base-project-vpc" {
  cidr_block = "10.0.0.0/16"
}
resource "aws_subnet" "base-project-subnet-1" {
  vpc_id = aws_vpc.base-project-vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  tags = { Name = "base-project-subnet-1" }
}
resource "aws_subnet" "base-project-subnet-2" {
  vpc_id = aws_vpc.base-project-vpc.id
  cidr_block = "10.0.2.0/24"
  tags = { Name = "base-project-subnet-2" }
}

resource "aws_internet_gateway" "base-project-internet-gateway-1"{
  vpc_id = aws_vpc.base-project-vpc.id
}
resource "aws_route_table" "base-project-route-table-main" {
  vpc_id = aws_vpc.base-project-vpc.id

  route {
    cidr_block = "0.0.0.0/0" #"10.0.1.0/24"
    gateway_id = aws_internet_gateway.base-project-internet-gateway-1.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    # THIS MIGHT BE A SECURITY ISSUE
    #egress_only_gateway_id = aws_egress_only_internet_gateway.foo.id
  }

  tags = {
    Name = "base-project-route-table-main"
  }
}

resource "aws_network_interface" "base-project-NIC-1" {
  subnet_id       = aws_subnet.base-project-subnet-1.id
  private_ips     = ["10.0.1.2"]
  security_groups = [aws_security_group.base-project-https.id]

  attachment {
    instance     = aws_instance.test.id
    device_index = 1
  }
}

resource "aws_security_group" "base-project-https" {
  name        = "base-project-https"
  description = "Security group for example usage with EC2 instance"
  vpc_id      = aws_vpc.base-project-vpc.id

  ingress {
    description = "https from vpc"
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # world now, load balancer later?
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
  }
}

data "aws_ami" "base-project-ami" {
    most_recent = true
    owners = ["amazon"]

    filter {
        name = "name"
        values = ["amzn2-ami-hvm-2.0.20210126.0-x86_64-gp2"]  # free tier   64 bit AWS Linux, SSD
    }
}

module "ec2_cluster" {
  source                 = "terraform-aws-modules/ec2-instance/aws"
  version                = "~> 2.0"

  instance_count = 2

  name          = "base-project-cluster"
  ami           = data.aws_ami.base-project-ami.id
  instance_type = "c5.large"
  subnet_id     = aws_subnet.base-project-subnet-1.id
  # private_ips                 = ["172.31.32.5", "172.31.46.20"]
  vpc_security_group_ids      = [aws_security_group.base-project-https.id]
  associate_public_ip_address = true
  # placement_group             = aws_placement_group.web.id

  # user_data_base64 = base64encode(local.user_data)

  root_block_device = [
    {
      volume_type = "gp2"
      volume_size = 10
    },
  ]

#   ebs_block_device = [
#     {
#       device_name = "/dev/sdf"
#       volume_type = "gp2"
#       volume_size = 5
#       encrypted   = true
#       kms_key_id  = aws_kms_key.this.arn
#     }
#   ]

  tags = {
    "Env"      = "Private"
    "Location" = "Secret"
  }
}

# resource "aws_security_group" "allow_tls" {
#   name        = "allow_tls"
#   description = "Allow TLS inbound traffic"
# #  vpc_id      = default.aws_vpc.default.id

#   ingress {
#     description = "TLS from VPC"
#     from_port   = 443
#     to_port     = 443
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   tags = {
#     Name = "allow_tls"
#   }
# }