locals {
  iam_path = "/cloudwright/${var.deployment_zone_namespace}/"
}


resource "aws_iam_user" "cloudwright_admin" {
  name = "${var.deployment_zone_namespace}-cw-admin"
  path = locals.iam_path
}

resource "aws_iam_role" "cloudwright_function" {
  name = "${var.deployment_zone_namespace}-cw-fn"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": [
          "${aws_iam_user.cloudwright_admin.arn}"
        ]
      },
      "Action": "sts:AssumeRole"
    },
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role" "cloudwright_invoker" {
  name = "${var.deployment_zone_namespace}-cw-invoke"

  assume_role_policy = <<EOF
{
 "Version": "2012-10-17",
  "Statement": {
    "Effect": "Allow",
    "Principal": {
      "AWS": [
        "${aws_iam_user.cloudwright_admin.arn}"
      ],
      "Service": "events.amazonaws.com"
    },
    "Action": "sts:AssumeRole"
  }
}
EOF
}

resource "aws_s3_bucket" "artifact_bucket" {
  bucket = "${var.deployment_zone_namespace}-cloudwright-artifacts"
  acl    = "private"
  region   = "${var.region}"
  policy = <<EOF
  {
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllS3Actions",
      "Effect": "Allow",
      "Principal": {
        "AWS": [
          "${aws_iam_user.cloudwright_admin.arn}",
          "${aws_iam_role.cloudwright_function.arn}",
          "${aws_iam_role.cloudwright_invoker.arn}"
        ]
      },
      "Action": [
        "s3:*"
      ],
      "Resource": [
        "*"
      ]
    },
    {
      "Sid": "AllObjectActions",
      "Effect": "Allow",
      "Principal": {
        "AWS": [
          "${aws_iam_user.cloudwright_admin.arn}",
          "${aws_iam_role.cloudwright_function.arn}",
          "${aws_iam_role.cloudwright_invoker.arn}"
        ]
      },
      "Action": "s3:*Object",
      "Resource": [
        "*"
      ]
    }
  ]
}
  EOF
}

resource "aws_iam_user_policy_attachment" "admin_lambda_admin" {
  user       = "${aws_iam_user.cloudwright_admin.name}"
  policy_arn = "arn:aws:iam::aws:policy/AWSLambdaFullAccess"
}

resource "aws_iam_user_policy_attachment" "admin_iam_read" {
  user       = "${aws_iam_user.cloudwright_admin.name}"
  policy_arn = "arn:aws:iam::aws:policy/IAMReadOnlyAccess"
}

resource "aws_iam_user_policy_attachment" "admin_api_gateway_admin" {
  user       = "${aws_iam_user.cloudwright_admin.name}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonAPIGatewayAdministrator"
}

resource "aws_iam_user_policy_attachment" "admin_sqs_admin" {
  user       = "${aws_iam_user.cloudwright_admin.name}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonSQSFullAccess"
}

resource "aws_iam_user_policy_attachment" "admin_cloudwatch_admin" {
  user       = "${aws_iam_user.cloudwright_admin.name}"
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchFullAccess"
}

resource "aws_iam_policy" "sqs_send_receive" {
  name        = "CloudWrightSendSQSMessage${var.deployment_zone_namespace}"
  path = locals.iam_path
  description = "My test policy"

  policy = <<EOF
{
"Version": "2012-10-17",
"Statement": [
  {
    "Sid": "SQSMessageUser",
    "Effect": "Allow",
    "Action": [
      "sqs:SendMessage",
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes"
    ],
    "Resource": "*"
  }]}
EOF
}

resource "aws_iam_role_policy_attachment" "function_sqs_use" {
  user       = "${aws_iam_role.cloudwright_function.name}"
  policy_arn = aws_iam_policy.sqs_send_receive.arn
}

resource "aws_iam_role_policy_attachment" "function_lambda_vpc_use" {
  user       = "${aws_iam_role.cloudwright_function.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}


resource "aws_iam_role_policy_attachment" "invoker_lambda_execute" {
  user       = "${aws_iam_role.cloudwright_invoker.name}"
  policy_arn = "arn:aws:iam::aws:policy/AWSLambdaExecute"
}

data "aws_iam_user" "root" {
  user_name = "root"
}

resource "aws_kms_key" "cloudwright_key" {
  description             = "CloudWright key"
  deletion_window_in_days = 10
  policy = <<EOF
  {
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "CloudWrightEncryptDecrypt",
      "Effect": "Allow",
      "Action": [
        "kms:EnableKey",
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:GenerateDataKey"
      ],
      "Principal": {
        "AWS": [
          "${aws_iam_user.cloudwright_admin.arn}",
          "${aws_iam_role.cloudwright_function.arn}",
          "${aws_iam_role.cloudwright_invoker.arn}"
        ]
      },
      "Resource": "*"
    },
    {
      "Sid": "Enable IAM User Permissions",
      "Effect": "Allow",
      "Principal": {"AWS": "${aws_iam_user.root.arn}"},
      "Action": "kms:*",
      "Resource": "*"
    }
  ]
}

  EOF
}

resource "aws_api_gateway_rest_api" "gateway" {
  name = "${var.deployment_zone_namespace}CloudWright"
  description = "The ${var.deployment_zone_name} CloudWright HTTP Endpoint Gateway"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}