
# --- import secrets ----
variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "aws_key_path" {}
variable "aws_key_name" {}

# --- My vpc id ----
variable "vpc_id" {
  description       = "VPC ID"
  default           = "vpc-d09f68b7"
}

provider "aws" {
  access_key    = "${var.aws_access_key}"
  secret_key    = "${var.aws_secret_key}"
  region        = "us-west-2"
}


#  --- Main Internet Gateway Router ----
resource "aws_internet_gateway" "gw" {
    vpc_id    = "${var.vpc_id}"

  tags = {
    Name = "default_InternetGateway"
  }
}



#  --- Public Subnets ----
resource "aws_subnet" "public_subnet_a" {
    vpc_id              = "${var.vpc_id}"
    cidr_block          = "172.31.1.0/24"
    availability_zone   = "us-west-2a"

    tags {
        Name = "public_a"
    }
}
resource "aws_subnet" "public_subnet_b" {
    vpc_id              = "${var.vpc_id}"
    cidr_block          = "172.31.2.0/24"
    availability_zone   = "us-west-2b"

    tags {
        Name = "public_b"
    }
}
resource "aws_subnet" "public_subnet_c" {
    vpc_id              = "${var.vpc_id}"
    cidr_block          = "172.31.3.0/24"
    availability_zone   = "us-west-2c"

    tags {
        Name = "public_c"
    }
}

# --- Private Subnets ----
resource "aws_subnet" "private_subnet_a" {
    vpc_id              = "${var.vpc_id}"
    cidr_block          = "172.31.4.0/22"
    availability_zone   = "us-west-2a"

    tags {
        Name = "private_a"
    }
}
resource "aws_subnet" "private_subnet_b" {
    vpc_id                = "${var.vpc_id}"
    cidr_block            = "172.31.8.0/22"
    availability_zone     = "us-west-2b"

    tags {
        Name = "private_b"
    }
}
resource "aws_subnet" "private_subnet_c" {
    vpc_id                = "${var.vpc_id}"
    cidr_block            = "172.31.12.0/22"
    availability_zone     = "us-west-2c"

    tags {
        Name = "private_c"
    }
}



# --- NAT Gateway ----

resource "aws_eip" "nat" {
  vpc = true
}

resource "aws_nat_gateway" "nat" {
  allocation_id     = "${aws_eip.nat.id}"
  subnet_id         = "${aws_subnet.public_subnet_a.id}"

  depends_on        = ["aws_internet_gateway.gw"]

}


#  --- Route tables ----
resource "aws_route_table" "public_routing_table" {
  vpc_id = "${var.vpc_id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.gw.id}"
  }

  tags {
    Name = "public_routing_table"
  }
}

resource "aws_route_table" "private_routing_table" {
  vpc_id = "${var.vpc_id}"
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = "${aws_nat_gateway.nat.id}"
  }

  tags {
    Name = "private_routing_table"
  }
}

#  --- Public Route table associations ----
resource "aws_route_table_association" "public_subnet_a_rt_assoc" {
    subnet_id = "${aws_subnet.public_subnet_a.id}"
    route_table_id = "${aws_route_table.public_routing_table.id}"
}
resource "aws_route_table_association" "public_subnet_b_rt_assoc" {
    subnet_id = "${aws_subnet.public_subnet_b.id}"
    route_table_id = "${aws_route_table.public_routing_table.id}"
}
resource "aws_route_table_association" "public_subnet_c_rt_assoc" {
    subnet_id = "${aws_subnet.public_subnet_c.id}"
    route_table_id = "${aws_route_table.public_routing_table.id}"
}

#  --- Private Route table associations ----
resource "aws_route_table_association" "private_subnet_a_rt_assoc" {
    subnet_id = "${aws_subnet.private_subnet_a.id}"
    route_table_id = "${aws_route_table.private_routing_table.id}"
}
resource "aws_route_table_association" "private_subnet_b_rt_assoc" {
    subnet_id = "${aws_subnet.private_subnet_b.id}"
    route_table_id = "${aws_route_table.private_routing_table.id}"
}
resource "aws_route_table_association" "private_subnet_c_rt_assoc" {
    subnet_id = "${aws_subnet.private_subnet_c.id}"
    route_table_id = "${aws_route_table.private_routing_table.id}"
}



# --- launch an Instance on Public Subnet ---- AMI Linux
resource "aws_security_group" "sg_bastion_server" {
   name = "bastion_public_server"
   description = "Allow SSH traffic from the internet"
   vpc_id = "${var.vpc_id}"
	
   ingress {
	from_port = 22
	to_port = 22
	protocol = "tcp"
	cidr_blocks = ["108.185.241.221/24"]
	}
   egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}

resource "aws_instance" "bastion_2a_public" {
	ami                  = "ami-5ec1673e"
	availability_zone    = "us-west-2a"
	instance_type        = "t2.micro"
	key_name             = "${var.aws_key_name}"
	security_groups      = ["${aws_security_group.sg_bastion_server.id}"]
	subnet_id            = "${aws_subnet.public_subnet_a.id}"
}

resource "aws_eip" "bastion_2a_public" {
	instance = "${aws_instance.bastion_2a_public.id}"
	vpc = true
}

output "ip" {
    value = "${aws_eip.bastion_2a_public.public_ip}"
}
