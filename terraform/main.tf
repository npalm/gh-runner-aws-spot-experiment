data "aws_caller_identity" "current" {}


resource "aws_launch_template" "runner" {
  name = "${var.environment}-runner"

  # block_device_mappings {
  #   device_name = "/dev/sda1"

  #   ebs {
  #     volume_size = 20
  #   }
  # }

  ebs_optimized = true

  iam_instance_profile {
    name = aws_iam_instance_profile.instance.name
  }

  image_id = data.aws_ami.runner.id

  instance_initiated_shutdown_behavior = "terminate"

  instance_market_options {
    market_type = "spot"
    spot_options {
      max_price = "0.1"
    }
  }

  # network_interfaces {
  #   associate_public_ip_address = false
  # }

  vpc_security_group_ids = [aws_security_group.runner.id]

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "test"
    }
  }

  user_data = base64encode(data.template_file.user_data.rendered)
}



data "template_file" "user_data" {
  template = file("${path.module}/template/user-data.tpl")

  vars = {
    logging             = var.enable_cloudwatch_logging ? data.template_file.logging.rendered : ""
    runner              = data.template_file.runner.rendered
    user_data_trace_log = var.enable_runner_user_data_trace_log
  }
}

data "template_file" "logging" {
  template = file("${path.module}/template/logging.tpl")

  vars = {
    environment = var.environment
  }
}

data "template_file" "runner" {
  template = file("${path.module}/template/runner.tpl")

  vars = {
    pre_install  = var.userdata_pre_install
    post_install = var.userdata_post_install
  }
}


data "aws_ami" "runner" {
  most_recent = "true"

  dynamic "filter" {
    for_each = var.ami_filter
    content {
      name   = filter.key
      values = filter.value
    }
  }

  owners = var.ami_owners
}

resource "aws_security_group" "runner" {
  name_prefix = "${var.environment}-security-group"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags
}


################################################################################
### policy
################################################################################
resource "aws_iam_instance_profile" "instance" {
  name = "${var.environment}-instance-profile"
  role = aws_iam_role.instance.name
}

data "template_file" "instance_role_trust_policy" {
  template = file("${path.module}/policies/instance-role-trust-policy.json")
}

resource "aws_iam_role" "instance" {
  name               = "${var.environment}-instance-role"
  assume_role_policy = data.template_file.instance_role_trust_policy.rendered
}

data "template_file" "instance_session_manager_policy" {
  count = var.enable_runner_ssm_access ? 1 : 0

  template = file(
    "${path.module}/policies/instance-session-manager-policy.json",
  )
}

resource "aws_iam_policy" "instance_session_manager_policy" {
  count = var.enable_runner_ssm_access ? 1 : 0

  name        = "${var.environment}-session-manager"
  path        = "/"
  description = "Policy session manager."

  policy = data.template_file.instance_session_manager_policy[0].rendered
}

resource "aws_iam_role_policy_attachment" "instance_session_manager_policy" {
  count = var.enable_runner_ssm_access ? 1 : 0

  role       = aws_iam_role.instance.name
  policy_arn = aws_iam_policy.instance_session_manager_policy[0].arn
}

resource "aws_iam_role_policy_attachment" "instance_session_manager_aws_managed" {
  count = var.enable_runner_ssm_access ? 1 : 0

  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

