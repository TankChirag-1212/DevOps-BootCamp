/*
vpc = data
igw = data
nat = data
public rt = data
private rt = create
subnet public = create
subnet private = create
route association public = create
route association private = create
ec2 public = create
ec2 private = create
key pair = data
sg public  = create
sg private = create
*/

# key pair data source to fetch existing key pair for EC2 instances
data "aws_key_pair" "key" {
  filter {
    name   = "tag:Owner"
    values = ["chirag.tank@einfochips.com"]
  }
}

# Public EC2 instance

resource "aws_instance" "ec2-public" {
  ami                    = "ami-04eb7809a4ed8a62d"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.subnet-pub.id
  key_name               = data.aws_key_pair.key.key_name
  vpc_security_group_ids = [aws_security_group.sg-pub.id]

  tags = merge(var.tags, { Name = "Chirag-Tank-Pub-EC2" })
}

# Private EC2 instance

# resource "aws_instance" "ec2-private" {
#   ami                    = "ami-04eb7809a4ed8a62d"
#   instance_type          = "t2.micro"
#   subnet_id              = aws_subnet.subnet-priv.id
#   key_name               = data.aws_key_pair.key.key_name
#   vpc_security_group_ids = [aws_security_group.sg-priv.id]

#   tags = merge(var.tags, { Name = "Chirag-Tank-Priv-EC2" })
# }

# Public Security Group

resource "aws_security_group" "sg-pub" {
  name        = "Chirag-Tank-Pub-SG"
  description = "Security group for public EC2 instance"
  vpc_id      = data.aws_vpc.vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.sg-pub-ingress-cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(var.tags, { Name = "Chirag-Tank-Pub-SG" })
}

# Privater Security Group

# resource "aws_security_group" "sg-priv" {
#   name        = "Chirag-Tank-Priv-SG"
#   description = "Security group for private EC2 instance"
#   vpc_id      = data.aws_vpc.vpc.id

#   ingress {
#     from_port       = 22
#     to_port         = 22
#     protocol        = "tcp"
#     security_groups = [aws_security_group.sg-pub.id]
#   }

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
#   tags = merge(var.tags, { Name = "Chirag-Tank-Priv-SG" })
# }