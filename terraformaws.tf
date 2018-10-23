##################################################################################
# VARIABLES
##################################################################################

variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "private_key_path" {}

variable "key_name" {
  default = "awsec2nvirginia"
}

variable "network_address_space" {
  default = "172.20.0.0/16"
}

variable "subnet1_address_space" {
  default = "172.20.10.0/24"
}

variable "subnet2_address_space" {
  default = "172.20.20.0/24"
}

variable "environment_tag" {}

##################################################################################
# PROVIDERS
##################################################################################

provider "aws" {
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  region     = "us-east-1"
}

##################################################################################
# DATA
##################################################################################

data "aws_availability_zones" "available" {}

##################################################################################
# RESOURCES
##################################################################################

# NETWORKING #
resource "aws_vpc" "vpc" {
  cidr_block           = "${var.network_address_space}"
  enable_dns_hostnames = true

  tags {
    Name        = "${var.environment_tag}-vpc"
    Environment = "${var.environment_tag}"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = "${aws_vpc.vpc.id}"

  tags {
    Name        = "${var.environment_tag}-igw"
    Environment = "${var.environment_tag}"
  }
}

resource "aws_subnet" "subnet1-public" {
  cidr_block              = "${var.subnet1_address_space}"
  vpc_id                  = "${aws_vpc.vpc.id}"
  map_public_ip_on_launch = "true"
  availability_zone       = "${data.aws_availability_zones.available.names[0]}"

  tags {
    Name        = "${var.environment_tag}-subnet1-public"
    Environment = "${var.environment_tag}"
  }
}

resource "aws_subnet" "subnet2-private" {
  cidr_block              = "${var.subnet2_address_space}"
  vpc_id                  = "${aws_vpc.vpc.id}"
  map_public_ip_on_launch = "false"
  availability_zone       = "${data.aws_availability_zones.available.names[1]}"

  tags {
    Name        = "${var.environment_tag}-subnet2-private"
    Environment = "${var.environment_tag}"
  }
}

# ROUTING #
resource "aws_route_table" "rtb-public" {
  vpc_id = "${aws_vpc.vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.igw.id}"
  }

  tags {
    Name        = "${var.environment_tag}-rtb"
    Environment = "${var.environment_tag}"
  }
}

resource "aws_route_table_association" "rta-subnet1-public" {
  subnet_id      = "${aws_subnet.subnet1-public.id}"
  route_table_id = "${aws_route_table.rtb-public.id}"
}

resource "aws_eip" "terraform-nat" {
  vpc = true
}

resource "aws_nat_gateway" "terraform-nat-gw" {
  allocation_id = "${aws_eip.terraform-nat.id}"
  subnet_id     = "${aws_subnet.subnet1-public.id}"
  depends_on    = ["aws_internet_gateway.igw"]
}

resource "aws_route_table" "rtb-private" {
  vpc_id = "${aws_vpc.vpc.id}"

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = "${aws_nat_gateway.terraform-nat-gw.id}"
  }

  tags {
    Name = "terraformtraining-private-1"
  }
}

resource "aws_route_table_association" "rta-subnet2-private" {
  subnet_id      = "${aws_subnet.subnet2-private.id}"
  route_table_id = "${aws_route_table.rtb-private.id}"
}

# SECURITY GROUPS #
resource "aws_security_group" "public-sg" {
  name   = "public-sg"
  vpc_id = "${aws_vpc.vpc.id}"

  #Allow HTTP from anywhere
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  #allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name        = "${var.environment_tag}-public-sg"
    Environment = "${var.environment_tag}"
  }
}

# Nginx security group
resource "aws_security_group" "private-sg" {
  name   = "private_sg"
  vpc_id = "${aws_vpc.vpc.id}"

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.network_address_space}"]
  }

  # HTTP access from the VPC
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["${var.network_address_space}"]
  }

  # Port 8080 from the vpc
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["${var.network_address_space}"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name        = "${var.environment_tag}-private-sg"
    Environment = "${var.environment_tag}"
  }
}

# INSTANCES #
resource "aws_instance" "Devbox" {
  ami                    = "ami-0ff8a91507f77f867"
  instance_type          = "t2.micro"
  subnet_id              = "${aws_subnet.subnet1-public.id}"
  vpc_security_group_ids = ["${aws_security_group.public-sg.id}"]
  key_name               = "${var.key_name}"

  connection {
    user        = "ec2-user"
    private_key = "${file(var.private_key_path)}"
  }

  provisioner "file" {
    source      = "script.sh"
    destination = "/tmp/script.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/script.sh",
      "sudo /tmp/script.sh",
    ]
  }

  tags {
    Name        = "${var.environment_tag}-devbox"
    Environment = "${var.environment_tag}"
  }
}

resource "aws_instance" "Appbox" {
  ami                    = "ami-0ff8a91507f77f867"
  instance_type          = "t2.micro"
  subnet_id              = "${aws_subnet.subnet2-private.id}"
  vpc_security_group_ids = ["${aws_security_group.private-sg.id}"]
  key_name               = "${var.key_name}"

  tags {
    Name        = "${var.environment_tag}-Appbox"
    Environment = "${var.environment_tag}"
  }
}

output "address" {
  value = "${aws_instance.Devbox.public_dns}"
}

output "private_ip" {
  value = "${aws_instance.Appbox.private_ip}"
}
