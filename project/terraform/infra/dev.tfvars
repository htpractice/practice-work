vpc_cidr = "10.1.0.0/16"
azs = ["us-east-1a", "us-east-1b"]
environment = "dev"
private_subnets = ["10.1.1.0/24", "10.1.2.0/24"]
public_subnets = ["10.1.10.0/24", "10.1.11.0/24"]
instance_type = "t2.micro"
ami = "ami-04b4f1a9cf54c11d0"
app_count = 2