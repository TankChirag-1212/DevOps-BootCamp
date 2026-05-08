# Fetch existing key pair
data "aws_key_pair" "key" {
  filter {
    name   = "tag:Owner"
    values = ["chirag.tank@einfochips.com"]
  }
}

# Public Security Group — allows SSH from specified CIDRs
resource "aws_security_group" "sg-pub" {
  name        = "Chirag-Tank-Pub-SG"
  description = "Security group for public EC2 instance"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.sg_pub_ingress_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "Chirag-Tank-Pub-SG" })
}

# Private Security Group — allows SSH only from public SG (bastion)
resource "aws_security_group" "sg-priv" {
  name        = "Chirag-Tank-Priv-SG"
  description = "Security group for private EC2 instance"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.sg-pub.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "Chirag-Tank-Priv-SG" })
}

# Public EC2 instance
resource "aws_instance" "ec2-public" {
  ami                    = "ami-04eb7809a4ed8a62d"
  instance_type          = "t2.micro"
  subnet_id              = var.public_subnet_id
  key_name               = data.aws_key_pair.key.key_name
  vpc_security_group_ids = [aws_security_group.sg-pub.id]
  tags                   = merge(var.tags, { Name = "Chirag-Tank-Pub-EC2" })
}

# Private EC2 instance
resource "aws_instance" "ec2-private" {
  ami                    = "ami-04eb7809a4ed8a62d"
  instance_type          = "t2.micro"
  subnet_id              = var.private_subnet_id
  key_name               = data.aws_key_pair.key.key_name
  vpc_security_group_ids = [aws_security_group.sg-priv.id]
  tags                   = merge(var.tags, { Name = "Chirag-Tank-Priv-EC2" })
}
