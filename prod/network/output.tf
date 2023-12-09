output "public_subnet_ids" {
  value = module.vpc-dev.subnet_id
}

output "vpc_id" {
  value = module.vpc-dev.vpc_id
}

output "private_subnet_ids" {
  value = module.vpc-dev.private_subnet_id
}