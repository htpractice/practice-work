#------------------VPC and Subnets-------------------
# Create a VPC with public and private subnets
module "devops-ninja-vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = ">= 3.0.0"
  name = "${var.environment}-vpc"
  cidr = var.vpc_cidr
  azs             = var.azs
  private_subnets = var.private_subnets
  private_subnet_names = ["${var.environment}-private-a, ${var.environment}-private-b"]
  public_subnets  = var.public_subnets
  public_subnet_names = ["${var.environment}-public-a, ${var.environment}-public-b"]
  #nat_gateway_azs    = ["${var.azs[0]}"] # NAT Gateway will be created in the first AZ
  single_nat_gateway = true #Only 1 NAT Gateway (in AZ-a) will be created if true, otherwise one NAT Gateway per AZ
  enable_nat_gateway = true #NAT Gateway will be created if true
  tags = {
    "Terraform" = "true"
    "Environment" = var.environment
  }
}

#-------------------Route Tables-------------------
# create route tables for public and private subnets
resource "aws_route_table" "public_rt" {
  vpc_id = module.devops-ninja-vpc.vpc_id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = module.devops-ninja-vpc.igw_id
    }

    tags = {
        Name = "${var.environment}-public-rt"
        Environment = var.environment
    }
}
resource "aws_route_table" "private_rt" {
  vpc_id = module.devops-ninja-vpc.vpc_id
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = module.devops-ninja-vpc.natgw_ids[0]
    }

    tags = {
        Name = "${var.environment}-private-rt"
        Environment = var.environment
    }
}
# associate the route tables with the subnets
resource "aws_route_table_association" "public_rt" {
  count          = length(var.public_subnets)
  subnet_id      = element(module.devops-ninja-vpc.public_subnets, count.index)
  route_table_id = aws_route_table.public_rt.id
}
resource "aws_route_table_association" "private_rt" {
  count          = length(var.private_subnets)
  subnet_id      = element(module.devops-ninja-vpc.private_subnets, count.index)
  route_table_id = aws_route_table.private_rt.id
}

#--------------------Creating Security Groups--------------------
# Fetch the self IP using a public API
data "http" "self_ip" {
  url = "http://ipv4.icanhazip.com"
}

module "bastion_sg" {
  source = "terraform-aws-modules/security-group/aws"

  name        = "${var.environment}-security-group"
  description = "Security group for Bastion Host"
  vpc_id      = module.devops-ninja-vpc.vpc_id
  ingress_with_cidr_blocks = [
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      description = "SSH from self IP"
      cidr_blocks = chomp(data.http.self_ip.response_body) + "/32" # Remove the newline character and add /32
    },
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      description = "HTTP from VPC"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      description = "HTTPS from VPC"
      cidr_blocks = "0.0.0.0/0"
    }
  ]
  egress_cidr_blocks      = ["0.0.0.0/0"]
  egress_with_cidr_blocks = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      description = "All traffic"
      cidr_blocks = "0.0.0.0/0"
    }
  ]
  tags = {
    "Terraform" = "true"
    "Environment" = var.environment
  }
}

module "private_instance_sg" {
  source = "terraform-aws-modules/security-group/aws"

  name        = "${var.environment}-private-instance-sg"
  description = "Security group for private instances"
  vpc_id      = module.devops-ninja-vpc.vpc_id
  ingress_cidr_blocks = ["${var.vpc_cidr}"]
  ingress_with_cidr_blocks = [
    {
      from_port   = 0
      to_port     = 0
      description = "All traffic"
      protocol    = "tcp"
      cidr_blocks = var.vpc_cidr
    }
    ]
    egress_cidr_blocks      = ["0.0.0.0/0"]
    egress_with_cidr_blocks = [
      {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        description = "All traffic"
        cidr_blocks = "0.0.0.0/0"
      }
      ]
      tags = {
        "Terraform" = "true"
        "Environment" = var.environment
      }
}

module "public_instance_sg" {
  source = "terraform-aws-modules/security-group/aws"

  name        = "${var.environment}-public-instance-sg"
  description = "Security group for public instances"
  vpc_id      = module.devops-ninja-vpc.vpc_id
  ingress_cidr_blocks = ["${var.vpc_cidr}"]
  ingress_with_cidr_blocks = [
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      description = "SSH from VPC"
      source_security_group_id = module.bastion_sg.security_group_id
    },
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      description = "HTTP from VPC"
      source_security_group_id = module.public_instance_sg.security_group_id
    },
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      description = "HTTPS from VPC"
      cidr_blocks = var.vpc_cidr
    }
    ]
  egress_cidr_blocks      = ["0.0.0.0/0"]
    egress_with_cidr_blocks = [
        {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        description = "All traffic"
        cidr_blocks = "0.0.0.0/0"
        }
    ]
    tags = {
        "Terraform" = "true"
        "Environment" = var.environment
    }
  
}