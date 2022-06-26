variable "region" {
  type = string
  description = "Your AWS region"
  default = "ap-northeast-2"
}

variable "aws_account" {
  type = string
  description = "Your AWS Account ID"
  default = "99999999"
}

variable "db_host" {
  type = string
  description = "INPUT Database HOST"
}

variable "db_name" {
  type = string
  description = "INPUT Database NAME"
}

variable "db_pw" {
  type = string
  description = "INPUT Database Password"
}

variable "db_user" {
  type = string
  description = "INPUT Database User"
}