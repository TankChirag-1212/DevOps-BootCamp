provider "aws" {
  region = "ap-south-1"
}

resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow SSH inbound traffic"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.My_IP, var.Office_IP]
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = [var.My_IP, var.Office_IP]
  }

  ingress {
    from_port   = 3001
    to_port     = 3001
    protocol    = "tcp"
    cidr_blocks = [var.My_IP, var.Office_IP]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Owner        = var.Owner
    Project_Name = var.Project_Name
    Department   = var.Department
    End_Date     = var.End_Date
  }
}

resource "aws_instance" "web" {
  ami                    = var.ami_id_amd64
  instance_type          = "t2.medium"
  key_name               = var.key_pair_name
  vpc_security_group_ids = [aws_security_group.allow_ssh.id]

  user_data = <<-EOF
    #!/bin/bash
    ${file("${path.module}/../scripts/docker-install.sh")}
  EOF

  root_block_device {
    volume_size = 30
  }

  tags = {
    Name         = "BootCamp_Chirag_Tank"
    Owner        = var.Owner
    Project_Name = var.Project_Name
    Department   = var.Department
    End_Date     = var.End_Date
  }
}
