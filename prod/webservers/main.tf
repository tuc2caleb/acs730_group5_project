# Terraform Config file (main.tf). This has provider block (AWS) and config for provisioning one EC2 instance resource.  

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.27"
    }
  }

  required_version = ">=0.14"
}
provider "aws" {
  profile = "default"
  region  = "us-east-1"
}

data "terraform_remote_state" "private_caleb" { // This is to use Outputs from Remote State
  backend = "s3"
  config = {
    bucket = "acs730-ass1-caleb"         // Bucket from where to GET Terraform State
    key    = "prod/network/terraform.tfstate" // Object name in the bucket to GET Terraform State
    region = "us-east-1"                      // Region where bucket created
  }
}

# Data source for AMI id
data "aws_ami" "latest_amazon_linux" {
  owners      = ["amazon"]
  most_recent = true
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Data source for availability zones in us-east-1
data "aws_availability_zones" "available" {
  state = "available"
}

# Define tags locally
locals {
  default_tags = merge(var.default_tags, { "env" = var.env })
  name_prefix  = "${var.prefix}-${var.env}"
}

resource "aws_instance" "acs73026" {

  ami                         = data.aws_ami.latest_amazon_linux.id
  count                       = length(data.terraform_remote_state.private_caleb.outputs.private_subnet_ids)
  instance_type               = lookup(var.instance_type, var.env)
  key_name                    = aws_key_pair.prodweek7.key_name
  security_groups             = [aws_security_group.acs730w7.id]
  subnet_id                   = data.terraform_remote_state.private_caleb.outputs.private_subnet_ids[count.index]
  associate_public_ip_address = false
  user_data = templatefile("${path.module}/install_httpd.sh.tpl",
    {
      env    = upper(var.env),
      prefix = upper(var.prefix)
    }
  )
  #user_data  = file("${path.module}/install_httpd.sh")
  # user_data  =<<-EOF
  #           #!/bin/bash
  #           sudo yum -y update
  #           sudo yum -y install httpd
  #           echo "<h1>Welcome to ACS730 Week 6!" >  /var/www/html/index.html
  #           sudo systemctl start httpd
  #           sudo systemctl enable httpd
  #       EOF

  root_block_device {
    encrypted = var.env == "prod" ? true : false
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(local.default_tags,
    {
      "Name" = "${var.prefix}-Amazon-Linux"
    }
  )
}

# Adding SSH  key to instance
resource "aws_key_pair" "prodweek7" {
  key_name   = var.prefix
  public_key = file("prodkey.pub")
}

#security Group
resource "aws_security_group" "acs730w7" {
  name        = "allow_http_ssh"
  description = "Allow HTTP and SSH inbound traffic"
  vpc_id      = data.terraform_remote_state.private_caleb.outputs.vpc_id

  ingress {
    description      = "HTTP from everywhere"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "SSH from everywhere"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = merge(local.default_tags,
    {
      "Name" = "${var.prefix}-EBS"
    }
  )
}


# Elastic IP
#resource "aws_eip" "static_eip" {
 # instance = aws_instance.acs73026.id
 # tags = merge(local.default_tags,
  #  {
  #    "Name" = "${var.prefix}-eip"
  #  }
 # )
#}

# Attach EBS volume
# resource "aws_volume_attachment" "ebs_att" {
#   count       = var.env == "prod" ? 1 : 0
#   device_name = "/dev/sdh"
#   volume_id   = aws_ebs_volume.web_ebs[count.index].id
#   instance_id = aws_instance.acs73026.id
# }

# # Create another EBS volume
# resource "aws_ebs_volume" "web_ebs" {
#   count             = var.env == "prod" ? 1 : 0
#   availability_zone = data.aws_availability_zones.available.names[0]
#   size              = 40

#   tags = merge(local.default_tags,
#     {
#       "Name" = "${var.prefix}-EBS"
#     }
#   )
# }
