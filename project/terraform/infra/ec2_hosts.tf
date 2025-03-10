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
# Store th ekey in a file
resource "local_file" "private_key_pem" {
  content              = tls_private_key.instance_key.private_key_pem
  filename             = "private_key.pem"
  file_permission      = "0600"
}

# Create the bastion host
module "bastion" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 3.0"

  name           = "${var.environment}-bastion"
  ami            = var.ami
  instance_type  = var.instance_type
  associate_public_ip_address = true
  key_name       = aws_key_pair.generated_key.key_name
  subnet_id      = module.devops-ninja-vpc.public_subnets[0]
  vpc_security_group_ids = [module.bastion_sg.security_group_id]

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
  vpc_security_group_ids = [module.private_instance_sg.security_group_id]

  tags = {
    Name = "${var.environment}-jenkins"
  }
}

# Create the app instance
module "app" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 3.0"
  for_each = var.azs_map
  name           = "${var.environment}-app-${each.value + 1}"
  ami            = var.ami
  instance_type  = var.instance_type
  key_name       = aws_key_pair.generated_key.key_name
  subnet_id      = module.devops-ninja-vpc.public_subnets[0]
  vpc_security_group_ids = [module.public_instance_sg.security_group_id]
  availability_zone = each.key
  tags = {
    Name = "${var.environment}-app-${each.value + 1}"
  }
}