data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "2.21"

  name = "vpc-${var.environment}"
  cidr = "10.0.0.0/16"

  azs             = [data.aws_availability_zones.available.names[0]]
  private_subnets = ["10.0.1.0/24"]
  public_subnets  = ["10.0.101.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true

  tags = {
    Environment = var.environment
  }
}

module "runner" {
  source = "../../"

  aws_region  = var.aws_region
  environment = "niek-ghrunner"

  vpc_id                   = module.vpc.vpc_id
  subnet_ids_runner        = module.vpc.private_subnets
  enable_runner_ssm_access = true

  tags = {
    "tf-aws-github-runner:example"           = "default"
    "tf-aws-github-runner:instancelifecycle" = "spot:yes"
  }

}

output "subnets" {
  value = module.vpc.private_subnets
}
output "launch_template" {
  value = {
    name    = module.runner.launch_template.name
    version = module.runner.launch_template.latest_version
  }
}
