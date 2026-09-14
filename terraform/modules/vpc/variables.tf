variable "name_prefix" { type = string }
variable "region" { type = string }
variable "subnet_cidr" { type = string }
variable "pod_cidr" { type = string }
variable "admin_cidrs" { type = list(string) }
variable "node_tags" { type = list(string) }
variable "labels" { type = map(string) }
