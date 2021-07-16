terraform {
  required_version = ">= 0.12"
}

provider "aws" {
  region = var.region
}
resource "aws_key_pair" "deployer" {
  key_name   = "aws_private_key"
  public_key = "ssh-rsa ***"
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_route53_zone" "default" {
  name = var.r53_zone_name
}

data "template_file" "user_data" {
  template = file("/scripts/cloud-init.yaml")
}

#AMI Filter for Windows Server 2019 Base
data "aws_ami" "windows" {
  most_recent = true

  filter {
    name   = "name"
    values = ["Windows_Server-2019-English-Full-Base-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["801119661308"] # Canonical
}

resource "aws_vpc" "main" {
  cidr_block                       = "10.0.0.0/16"
  assign_generated_ipv6_cidr_block = "true"
  enable_dns_support               = "true"
  enable_dns_hostnames             = "true"

  tags = {
    Name = "cdn-${var.region}"
  }
}

resource "aws_internet_gateway" "default" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "cdn-${var.region}-igw"
  }
}

resource "aws_subnet" "public" {
  vpc_id                          = aws_vpc.main.id
  cidr_block = cidrsubnet(aws_vpc.main.cidr_block, 8,0)
  map_public_ip_on_launch         = true
  availability_zone = var.availability_zone

  tags = {
    Name = "subnet-example-public"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.default.id
  }
}


resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}


resource "aws_security_group" "default" {
  vpc_id = aws_vpc.main.id
  
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks =  [aws_vpc.main.cidr_block]
  }

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks =  [aws_vpc.main.cidr_block]
  }
  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "RDP"
    from_port        = 3389
    to_port          = 3389
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

   ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


#AWS Instance
resource "aws_instance" "example" {
    ami = data.aws_ami.windows.id
    instance_type = "t2.micro"
    availability_zone = var.availability_zone
    subnet_id = aws_subnet.public.id
    vpc_security_group_ids = [aws_security_group.default.id, aws_vpc.main.default_security_group_id]
    key_name = aws_key_pair.deployer.key_name
    user_data  = data.template_file.user_data.rendered

  lifecycle {
    ignore_changes = [ami]
  }
  tags = {
    Name = "ec2-example"
  }
}

#EBS Volume and Attachment

resource "aws_ebs_volume" "example" {
  availability_zone = var.availability_zone
  size              = 40
}

resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.example.id
  instance_id = aws_instance.example.id
}

resource "aws_route53_record" "www" {
  zone_id = aws_route53_zone.default.zone_id
  name = format(
    "%s.%s",
    var.r53_domain_name,
    aws_route53_zone.default.name,
  )
  type    = "A"
  ttl     = "300"
  records = [aws_instance.example.public_ip]
  set_identifier = "cdn-${var.region}-v4"
  
  
  geolocation_routing_policy {
    country = "*"
  }
}