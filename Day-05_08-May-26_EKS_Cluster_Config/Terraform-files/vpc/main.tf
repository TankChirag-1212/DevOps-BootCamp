data "aws_vpc" "main" {
  tags = {
    Name = "Bootcamp-vpc-do-not-delete-vpc"
  }
}

data "aws_internet_gateway" "main" {
  tags = {
    Name = "Bootcamp-vpc-do-not-delete-igw"
  }
}

# Public subnet 1 in az-a
resource "aws_subnet" "pub_sub_1" {
  vpc_id            = data.aws_vpc.main.id
  cidr_block        = var.public_subnet_1_cidr
  availability_zone = "${var.aws_region}a"
  map_public_ip_on_launch = true
  tags = merge(var.tags, {Name = "Chirag-bootcamp-pub-sub-1"})
}

# Public subnet 2 in az-b
resource "aws_subnet" "pub_sub_2" {
  vpc_id            = data.aws_vpc.main.id
  cidr_block        = var.public_subnet_2_cidr
  map_public_ip_on_launch = true
  availability_zone = "${var.aws_region}b"
  tags = merge(var.tags, {Name = "Chirag-bootcamp-pub-sub-2"})
}

# Public Route Table
resource "aws_route_table" "public_rt" {
  vpc_id = data.aws_vpc.main.id
  tags = merge(var.tags, {Name = "Chirag-bootcamp-public-rt"})

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = data.aws_internet_gateway.main.id
  }
}

# Route table association for public subnets
resource "aws_route_table_association" "pub_sub_assoc" {
  count          = 2
  subnet_id      = [aws_subnet.pub_sub_1.id, aws_subnet.pub_sub_2.id][count.index]
  route_table_id = aws_route_table.public_rt.id
}