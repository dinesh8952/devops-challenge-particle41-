project_name         = "simpletimeservice"
aws_region           = "ap-south-1"
environment          = "dev"
vpc_cidr             = "10.0.0.0/16"
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.10.0/24", "10.0.20.0/24"]
container_image      = "dineshreddy2025/simpletimeservice:latest"
container_port       = 5000
task_cpu             = 256
task_memory          = 512
desired_count        = 2

# To enable HTTPS: create an ACM certificate in ap-south-1 and paste the ARN here
# acm_certificate_arn = "arn:aws:acm:ap-south-1:123456789012:certificate/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
acm_certificate_arn  = ""
