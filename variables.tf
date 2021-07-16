#Variable for AZ
variable "availability_zone" {
    type = string
    # default = "us-east-1a"
    # default = "us-east-1d"
    default = "us-east-1a"
}

variable "region" {
    default = "us-east-1"
}

variable "instance_type" {
  default = "t3.nano"
}

variable "r53_zone_name" {
  default = "sha3de.xyz"
}

variable "r53_domain_name" {
  default = "cdn"
}

