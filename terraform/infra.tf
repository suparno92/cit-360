
  # --- import secret variables ----
  variable "vpc_id" {}
  variable "my_publicip" {}
  variable "db_password" {}
  variable "db_username" {}
  variable "aws_access_key" {}
  variable "aws_secret_key" {}
  variable "aws_key_path" {}
  variable "aws_key_name" {}

  # -- set aws region and keys ----
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

  	ingress {
  		from_port = 22
  		to_port = 22
  		protocol = "tcp"
  		cidr_blocks = ["${var.my_publicip}"]
  	}
    ingress {
      from_port   = 0
      to_port     = 65535
      protocol    = "TCP"
      cidr_blocks = ["172.31.0.0/16"]
    }

    egress {
      from_port = 0
      to_port = 0
      protocol = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }

  	vpc_id = "${var.vpc_id}"
  }

  resource "aws_instance" "bastion_2a_public" {
  	ami                  = "ami-5ec1673e"
  	availability_zone    = "us-west-2a"
  	instance_type        = "t2.micro"
  	key_name             = "${var.aws_key_name}"
        associate_public_ip_address = true
  	security_groups      = ["${aws_security_group.sg_bastion_server.id}"]
  	subnet_id            = "${aws_subnet.public_subnet_a.id}"

      tags = {
        Name = "bastion_access_point"
      }
  }

# ---- Part2 ----

resource "aws_security_group" "sg_load_balancer" {
  name        = "main_elb_sg"
  description = "Allow all inbound HTTP traffic"
  vpc_id      = "${var.vpc_id}"

    ingress {
      from_port   = 80
      to_port     = 80
      protocol    = "TCP"
      cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
      from_port   = 80
      to_port     = 80
      protocol    = "TCP"
      cidr_blocks = ["0.0.0.0/0"]
    }

  tags {
    Name = "sg_elb"
  }
}

# ---- Database Security ---
resource "aws_security_group" "sg_db_instance" {
  name        = "main_database_sg"
  description = "Allow all inbound traffic within VPC"
  vpc_id      = "${var.vpc_id}"

    ingress {
      from_port   = 80
      to_port     = 80
      protocol    = "TCP"
      cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }

  tags {
    Name = "sg_db"
  }
}
# ---- Database Subnet Group ---
resource "aws_db_subnet_group" "grp_db_private_a_b" {
  name        = "db_subnet_group"
  description = "database subnets"
  subnet_ids  = ["${aws_subnet.private_subnet_a.id}", "${aws_subnet.private_subnet_b.id}"]
}
# ---- Database Instance ---
resource "aws_db_instance" "db001" {
  identifier             = "main-database-west"
  storage_type           = "gp2"
  allocated_storage      = "5"
  engine                 = "mariadb"
  engine_version         = "10.0.24"
  instance_class         = "db.t2.micro"
  username               = "${var.db_username}"
  password               = "${var.db_password}"
  multi_az               = "false"
  port                   = "3306"
  publicly_accessible    = "false"
  apply_immediately      = "true"
  vpc_security_group_ids = ["${aws_security_group.sg_db_instance.id}"]
  db_subnet_group_name   = "${aws_db_subnet_group.grp_db_private_a_b.name}"
}



# ---  Private Webservers Security group ----
resource "aws_security_group" "sg_web_servers" {
  name        = "main_web_sg"
  description = "Allow all inbound traffic"
  vpc_id      = "${var.vpc_id}"

    ingress {
      from_port   = 80
      to_port     = 80
      protocol    = "TCP"
      cidr_blocks = ["172.31.0.0/16"]
    }

    ingress {
      from_port   = 22
      to_port     = 22
      protocol    = "TCP"
      cidr_blocks = ["172.31.0.0/16"]
    }

    egress {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }


  tags {
    Name = "sg_web"
  }
}

# --- Private Webservers ----
resource "aws_instance" "web_s1" {
	ami                  = "ami-5ec1673e"
	availability_zone    = "us-west-2b"
	instance_type        = "t2.micro"
	key_name             = "${var.aws_key_name}"
  
	security_groups      = ["${aws_security_group.sg_web_servers.id}"]
	subnet_id            = "${aws_subnet.private_subnet_b.id}"
  tags {
        Name = "webserver-b"
        Service = "curriculum"
    }
}
resource "aws_instance" "web_s2" {
	ami                  = "ami-5ec1673e"
	availability_zone    = "us-west-2c"
	instance_type        = "t2.micro"
	key_name             = "${var.aws_key_name}"
  
	security_groups      = ["${aws_security_group.sg_web_servers.id}"]
	subnet_id            = "${aws_subnet.private_subnet_c.id}"
  tags {
        Name = "webserver-c"
        Service = "curriculum"
    }
}


# --- Public Elastic Load Balance ----
resource "aws_elb" "web-elb" {

  security_groups    = ["${aws_security_group.sg_load_balancer.id}"]

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5s
    target              = "HTTP:80/"
    interval            = 30
  }

  instances = ["${aws_instance.web_s1.id}","${aws_instance.web_s2.id}"]

  cross_zone_load_balancing   = true
  idle_timeout                = 60
  connection_draining         = true
  connection_draining_timeout = 60

    tags {
        name = "elb-cit360"
    }
}
