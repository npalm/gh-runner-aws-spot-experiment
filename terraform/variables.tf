variable "aws_region" {
  description = "AWS region."
  type        = string
}

variable "aws_zone" {
  description = "AWS availability zone (typically 'a', 'b', or 'c')."
  type        = string
  default     = "a"
}

variable "environment" {
  description = "A name that identifies the environment, used as prefix and for tagging."
  type        = string
}

variable "vpc_id" {
  description = "The target VPC for the docker-machine and runner instances."
  type        = string
}

variable "subnet_ids_runner" {
  description = "Subnet used for hosting the runner."
  type        = list(string)
}

variable "instance_type" {
  description = "Instance type used for the runner."
  type        = string
  default     = "m5.large"
}

variable "runner_instance_spot_price" {
  description = "By setting a spot price bid price the runner agent will be created via a spot request. Be aware that spot instances can be stopped by AWS."
  type        = string
  default     = ""
}

variable "userdata_pre_install" {
  description = "User-data script snippet to insert before runner install"
  type        = string
  default     = ""
}

variable "userdata_post_install" {
  description = "User-data script snippet to insert after runner install"
  type        = string
  default     = ""
}

variable "runners_use_private_address" {
  description = "Restrict runners to the use of a private IP address"
  type        = bool
  default     = true
}

variable "runners_request_spot_instance" {
  description = "Whether or not to request spot instances via docker-machine"
  type        = bool
  default     = true
}

variable "enable_cloudwatch_logging" {
  description = "Boolean used to enable or disable the CloudWatch logging."
  type        = bool
  default     = true
}

variable "cloudwatch_logging_retention_in_days" {
  description = "Retention for cloudwatch logs. Defaults to unlimited"
  type        = number
  default     = 0
}

variable "tags" {
  description = "Map of tags that will be added to created resources. By default resources will be tagged with name and environment."
  type        = map(string)
  default     = {}
}

variable "ami_filter" {
  description = "List of maps used to create the AMI filter for the runner AMI. Currently Amazon Linux 2 `amzn2-ami-hvm-2.0.????????-x86_64-ebs` looks to *not* be working for this configuration."
  type        = map(list(string))

  default = {
    name = ["amzn2-ami-ecs-hvm-2.0.????????-x86_64-ebs"]
  }
}

variable "ami_owners" {
  description = "The list of owners used to select the AMI of runner instances."
  type        = list(string)
  default     = ["amazon"]
}

variable "enable_runner_user_data_trace_log" {
  description = "Enable bash xtrace for the user data script that creates the EC2 instance for the runner agent. Be aware this could log sensitive data such as you runner token."
  type        = bool
  default     = false
}

variable "enable_schedule" {
  description = "Flag used to enable/disable auto scaling group schedule for the runner instance. "
  type        = bool
  default     = false
}

variable "enable_runner_ssm_access" {
  type    = bool
  default = true
}
