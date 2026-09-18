output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.this.id
}

output "availability_zones" {
  description = "Availability Zones used by the network."
  value       = var.availability_zones
}

output "public_subnet_ids" {
  description = "IDs of the public subnets, in Availability Zone order."
  value       = aws_subnet.public[*].id
}

output "application_subnet_ids" {
  description = "IDs of the private application subnets, in Availability Zone order."
  value       = aws_subnet.application[*].id
}

output "database_subnet_ids" {
  description = "IDs of the private database subnets, in Availability Zone order."
  value       = aws_subnet.database[*].id
}

output "public_route_table_ids" {
  description = "IDs of the public route tables, in Availability Zone order."
  value       = aws_route_table.public[*].id
}

output "application_route_table_ids" {
  description = "IDs of the private application route tables, in Availability Zone order."
  value       = aws_route_table.application[*].id
}

output "database_route_table_ids" {
  description = "IDs of the private database route tables, in Availability Zone order."
  value       = aws_route_table.database[*].id
}

output "nat_gateway_ids" {
  description = "IDs of the NAT Gateways."
  value       = aws_nat_gateway.this[*].id
}

output "s3_gateway_endpoint_id" {
  description = "ID of the S3 Gateway VPC endpoint."
  value       = aws_vpc_endpoint.s3.id
}
