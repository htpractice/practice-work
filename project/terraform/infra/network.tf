#------------------VPC and Subnets-------------------
# Create a VPC with public and private subnets
module "devops-ninja-vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = ">= 3.0.0"
  name = "${var.environment}-vpc"
  cidr = var.vpc_cidr
  azs             = var.azs
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets
  nat_gateway_tags = {
    Name = "${var.environment}-nat-gateway"
    Environment = var.environment
  }
  igw_tags = {
    Name = "${var.environment}-igw"
    Environment = var.environment
  }
  public_route_table_tags = {
    Name = "${var.environment}-public-rt"
    Environment = var.environment
  }
  private_route_table_tags = {
    Name = "${var.environment}-private-rt"
    Environment = var.environment
  }
  single_nat_gateway = true #Only 1 NAT Gateway (in AZ-a) will be created if true, otherwise one NAT Gateway per AZ
  enable_nat_gateway = true #NAT Gateway will be created if true
  tags = {
    "Terraform" = "true"
    "Environment" = var.environment
  }
}
#--------------------Creating Security Groups--------------------
# Fetch the self IP using a public API
data "http" "self_ip" {
  url = "http://ipv4.icanhazip.com"
}

module "bastion_sg" {
  source = "terraform-aws-modules/security-group/aws"

  name        = "${var.environment}-bastion-sg"
  description = "Security group for Bastion Host"
  vpc_id      = module.devops-ninja-vpc.vpc_id
  ingress_with_cidr_blocks = [
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      description = "SSH from self IP"
      cidr_blocks = "${chomp(data.http.self_ip.response_body)}/32" # Remove the newline character and add /32
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
      cidr_blocks = "${chomp(data.http.self_ip.response_body)}/32" # Remove the newline character and add /32
    },
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      description = "HTTP from SELF IP"
      cidr_blocks = "${chomp(data.http.self_ip.response_body)}/32" # Remove the newline character and add /32
    },
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      description = "HTTPS from VPC"
      cidr_blocks = "${chomp(data.http.self_ip.response_body)}/32" # Remove the newline character and add /32
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