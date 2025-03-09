# Generate a new SSH key pair and use it to launch EC2 instances
resource "tls_private_key" "instance_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create a key pair for the instances to use for SSH access
resource "aws_key_pair" "generated_key" {
  key_name   = "${var.environment}-key"
  public_key = tls_private_key.instance_key.public_key_openssh
}

# Create the bastion host
module "bastion" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 3.0"

  name           = "${var.environment}-bastion"
  ami            = var.ami
  instance_type  = var.instance_type
  key_name       = aws_key_pair.generated_key.key_name
  subnet_id      = module.devops-ninja-vpc.public_subnets[0]
  vpc_security_group_ids = [module.bastion_sg.this_security_group_id]

  tags = {
    Name = "${var.environment}-bastion"
  }
}

# Create the Jenkins server
module "jenkins" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 3.0"

  name           = "${var.environment}-jenkins"
  ami            = var.ami
  instance_type  = var.instance_type
  key_name       = aws_key_pair.generated_key.key_name
  subnet_id      = module.devops-ninja-vpc.private_subnets[0]
  vpc_security_group_ids = [module.private_instance_sg.this_security_group_id]

  tags = {
    Name = "${var.environment}-jenkins"
  }
}

# Create the app instance
module "app" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 3.0"

  name           = "${var.environment}-app"
  ami            = var.ami
  instance_type  = var.instance_type
  key_name       = aws_key_pair.generated_key.key_name
  subnet_id      = module.devops-ninja-vpc.public_subnets[0]
  vpc_security_group_ids = [module.public_instance_sg.this_security_group_id]
  count          = var.app_count

  tags = {
    Name = "${var.environment}-app-${count.index + 1}"
  }
}