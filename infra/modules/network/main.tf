data "aws_region" "current" {}

locals {
  public_subnet_names = [
    "public-a",
    "public-b",
  ]

  application_subnet_names = [
    "application-a",
    "application-b",
  ]

  database_subnet_names = [
    "database-a",
    "database-b",
  ]

  base_tags = merge(var.tags, {
    Component = "network"
  })
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.base_tags, {
    Name = "${var.name_prefix}-vpc"
  })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.base_tags, {
    Name = "${var.name_prefix}-igw"
  })
}

resource "aws_subnet" "public" {
  count = length(var.availability_zones)

  vpc_id                  = aws_vpc.this.id
  availability_zone       = var.availability_zones[count.index]
  cidr_block              = var.public_subnet_cidrs[count.index]
  map_public_ip_on_launch = true

  tags = merge(local.base_tags, {
    Name = "${var.name_prefix}-${local.public_subnet_names[count.index]}"
    Tier = "public"
  })
}

resource "aws_subnet" "application" {
  count = length(var.availability_zones)

  vpc_id                  = aws_vpc.this.id
  availability_zone       = var.availability_zones[count.index]
  cidr_block              = var.application_subnet_cidrs[count.index]
  map_public_ip_on_launch = false

  tags = merge(local.base_tags, {
    Name = "${var.name_prefix}-${local.application_subnet_names[count.index]}"
    Tier = "private-application"
  })
}

resource "aws_subnet" "database" {
  count = length(var.availability_zones)

  vpc_id                  = aws_vpc.this.id
  availability_zone       = var.availability_zones[count.index]
  cidr_block              = var.database_subnet_cidrs[count.index]
  map_public_ip_on_launch = false

  tags = merge(local.base_tags, {
    Name = "${var.name_prefix}-${local.database_subnet_names[count.index]}"
    Tier = "private-database"
  })
}

resource "aws_route_table" "public" {
  count = length(var.availability_zones)

  vpc_id = aws_vpc.this.id

  tags = merge(local.base_tags, {
    Name = "${var.name_prefix}-public-rt-${count.index + 1}"
    Tier = "public"
  })
}

resource "aws_route" "public_default" {
  count = length(var.availability_zones)

  route_table_id         = aws_route_table.public[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  count = length(var.availability_zones)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[count.index].id
}

resource "aws_eip" "nat" {
  count = var.nat_gateway_count

  domain = "vpc"

  tags = merge(local.base_tags, {
    Name = "${var.name_prefix}-nat-eip-${count.index + 1}"
  })
}

resource "aws_nat_gateway" "this" {
  count = var.nat_gateway_count

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  depends_on = [aws_internet_gateway.this]

  tags = merge(local.base_tags, {
    Name = "${var.name_prefix}-nat-${count.index + 1}"
  })
}

resource "aws_route_table" "application" {
  count = length(var.availability_zones)

  vpc_id = aws_vpc.this.id

  tags = merge(local.base_tags, {
    Name = "${var.name_prefix}-application-rt-${count.index + 1}"
    Tier = "private-application"
  })
}

resource "aws_route" "application_default" {
  count = length(var.availability_zones)

  route_table_id         = aws_route_table.application[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = var.nat_gateway_count == 1 ? aws_nat_gateway.this[0].id : aws_nat_gateway.this[count.index].id
}

resource "aws_route_table_association" "application" {
  count = length(var.availability_zones)

  subnet_id      = aws_subnet.application[count.index].id
  route_table_id = aws_route_table.application[count.index].id
}

resource "aws_route_table" "database" {
  count = length(var.availability_zones)

  vpc_id = aws_vpc.this.id

  tags = merge(local.base_tags, {
    Name = "${var.name_prefix}-database-rt-${count.index + 1}"
    Tier = "private-database"
  })
}

resource "aws_route_table_association" "database" {
  count = length(var.availability_zones)

  subnet_id      = aws_subnet.database[count.index].id
  route_table_id = aws_route_table.database[count.index].id
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.current.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids = concat(
    aws_route_table.application[*].id,
    aws_route_table.database[*].id,
  )

  tags = merge(local.base_tags, {
    Name = "${var.name_prefix}-s3-endpoint"
  })
}
