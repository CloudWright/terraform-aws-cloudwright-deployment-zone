output "admin_user_arn" {
  value = "${aws_iam_user.cloudwright_admin.arn}"
}

output "kms_key_arn" {
  value = "${aws_kms_key.cloudwright_key.arn}"
}

output "api_gateway_id" {
  value = "${aws_api_gateway_rest_api.gateway.id}"
}