data "aws_vpc" "vpc" {
  tags = {
    Name = "Bootcamp-vpc-do-not-delete-vpc"
  }
}

# data "aws_nat_gateway" "nat" {
#   vpc_id = data.aws_vpc.vpc.id
# }

data "aws_internet_gateway" "igw" {
  tags = {
    Name = "Bootcamp-vpc-do-not-delete-igw"
  }
}

data "aws_route_table" "rtb-pub" {
  route_table_id = "rtb-0898c89baeb6ebb57"
}

# -------------------------------------------------------------

# Public Subnet
resource "aws_subnet" "subnet-pub" {
  vpc_id                  = data.aws_vpc.vpc.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.subnet_az
  map_public_ip_on_launch = true
  tags                    = merge(var.tags, { Name = "Chirag-Tank-pub-subnet" })
}

# Public route table association with public subnet
resource "aws_route_table_association" "rtb-pub-assoc" {
  subnet_id      = aws_subnet.subnet-pub.id
  route_table_id = data.aws_route_table.rtb-pub.id
}

# Private Subnet
# resource "aws_subnet" "subnet-priv" {
#   vpc_id            = data.aws_vpc.vpc.id
#   cidr_block        = var.private_subnet_cidr
#   availability_zone = var.subnet_az
#   tags              = merge(var.tags, { Name = "Chirag-Tank-priv-subnet" })
# }

# Private route table
# resource "aws_route_table" "rtb-priv" {
#   vpc_id = data.aws_vpc.vpc.id

#   route {
#     cidr_block     = "0.0.0.0/0"
#     nat_gateway_id = data.aws_nat_gateway.nat.id
#   }

#   tags = merge(var.tags, { Name = "Chirag-Tank-private-rt" })
# }

# Private route table association with private subnet
# resource "aws_route_table_association" "rtb-priv-assoc" {
#   subnet_id      = aws_subnet.subnet-priv.id
#   route_table_id = aws_route_table.rtb-priv.id
# }