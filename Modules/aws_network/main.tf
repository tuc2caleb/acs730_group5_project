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

# Data source for availability zones in us-east-1
data "aws_availability_zones" "available" {
  state = "available"
}

# Define tags locally
locals {
  default_tags = merge(var.default_tags, { "env" = var.env })
}

# Create a new VPC 
resource "aws_vpc" "main" {
  cidr_block       = var.vpc_cidr
  instance_tenancy = "default"
  tags = merge(
    local.default_tags, {
      Name = "${var.prefix}-public-subnet"
    }
  )
}

# Add provisioning of the public subnetin the default VPC
resource "aws_subnet" "public_subnet" {
  count             = var.env == "prod" ?  0 : length(var.public_cidr_blocks)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_cidr_blocks[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = merge(
    local.default_tags, {
      Name = "${var.prefix}-public-subnet-${count.index}"
    }
  )
}

# Add provisioning of the private subnetin the default VPC
resource "aws_subnet" "private_subnet" {
  count             = length(var.private_cidr_blocks)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_cidr_blocks[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = merge(
    local.default_tags, {
      Name = "${var.prefix}-private-subnet-${count.index}"
    }
  )
}

# Create Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.default_tags,
    {
      "Name" = "${var.prefix}-igw"
    }
  )
}

resource "aws_nat_gateway" "nat" {
count = var.env == "prod" ? 0 : 1
  allocation_id = aws_eip.nat_gateway_eip[0].id
  subnet_id     =  aws_subnet.public_subnet[1].id
  tags = {
    Name = "${var.env}-nat"
  }
}

# Route table to route add default gateway pointing to Internet Gateway (IGW)
resource "aws_route_table" "public_subnets" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "${var.prefix}-route-public-subnets"
  }
}

resource "aws_route_table" "private_routes" {
count = var.env == "prod" ? 0 : 1
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat[0].id
  }
  tags = merge(local.default_tags, {
    "Name" = "${var.env}-private-route"
  })
}

# Associate subnets with the custom route table
resource "aws_route_table_association" "public_route_table_association" {
  count          = length(aws_subnet.public_subnet[*].id)
  route_table_id = aws_route_table.public_subnets.id
  subnet_id      = aws_subnet.public_subnet[count.index].id
}

resource "aws_route_table_association" "private_route_table_association" {
  count          = var.env == "prod" ? 0 : length(var.private_cidr_blocks)
  subnet_id      = aws_subnet.private_subnet[count.index].id
  route_table_id = aws_route_table.private_routes[0].id
}

# Elastic IP
resource "aws_eip" "nat_gateway_eip" {
count = var.env == "prod" ? 0 : 1
  domain = "vpc"
  tags = {
    Name = "${var.env}-NAT-eip"
  }
}

# resource "aws_vpc_peering_connection" "peering" {
#   vpc_id        = data.terraform_remote_state.private_caleb.outputs.vpc_id
#   peer_vpc_id   = data.terraform_remote_state.private_caleb.outputs.vpc_id
# # peer_owner_id = data.aws_caller_identity.current.account_id

#   auto_accept   = true
# }

resource "aws_vpc_peering_connection" "peering" {
  provider = aws

  vpc_id        = var.vpc_id1
  peer_vpc_id   = var.vpc_id2
  auto_accept   = true

  tags = {
    Name = "peering-${var.vpc_id1}-${var.vpc_id2}"
    # Add other tags as needed
  }
}

output "peering_connection_id" {
  value = aws_vpc_peering_connection.peering.id
}
