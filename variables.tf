variable "region" {
  type        = string
  description = "The AWS region to deploy infrastructure to"
}

variable "deployment_zone_name" {
  type        = string
  description = "The display name of this deployment zone, shown in the CloudWright UI. Can contain spaces, special characters etc."
}

variable "deployment_zone_namespace" {
  type        = string
  description = "The 'slug' used to namespace resources created for this deployment zone. Should only contain lower-case letters, numbers, and hyphens"
}