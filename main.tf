data "aws_caller_identity" "current" {}


locals {
  iam_path      = "/cloudwright/${var.deployment_zone_namespace}/"
  root_user_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
}



resource "aws_iam_user" "cloudwright_admin" {
  name = "${var.deployment_zone_namespace}-cw-admin"
  path = "${local.iam_path}"

 
}

resource "aws_iam_role" "cloudwright_function" {
  name = "${var.deployment_zone_namespace}-cw-fn"
  path = "${local.iam_path}"
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
  name = "${var.deployment_zone_namespace}-cw-invk"
  path = "${local.iam_path}"
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
  region = "${var.region}"
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
        "arn:aws:s3:::${var.deployment_zone_namespace}-cloudwright-artifacts"
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
        "arn:aws:s3:::${var.deployment_zone_namespace}-cloudwright-artifacts/*"
      ]
    }
  ]
}
  EOF
}

// resource "aws_iam_user_policy_attachment" "admin_lambda_admin" {
//   user       = "${aws_iam_user.cloudwright_admin.name}"
//   policy_arn = "arn:aws:iam::aws:policy/AWSLambdaFullAccess"
// }

resource "aws_iam_user_policy_attachment" "admin_iam_read" {
  user       = "${aws_iam_user.cloudwright_admin.name}"
  policy_arn = "arn:aws:iam::aws:policy/IAMReadOnlyAccess"
}

// resource "aws_iam_user_policy_attachment" "admin_api_gateway_admin" {
//   user       = "${aws_iam_user.cloudwright_admin.name}"
//   policy_arn = "arn:aws:iam::aws:policy/AmazonAPIGatewayAdministrator"
// }

// resource "aws_iam_user_policy_attachment" "admin_sqs_admin" {
//   user       = "${aws_iam_user.cloudwright_admin.name}"
//   policy_arn = "arn:aws:iam::aws:policy/AmazonSQSFullAccess"
// }

// resource "aws_iam_user_policy_attachment" "admin_cloudwatch_admin" {
//   user       = "${aws_iam_user.cloudwright_admin.name}"
//   policy_arn = "arn:aws:iam::aws:policy/CloudWatchFullAccess"
// }

resource "aws_iam_policy" "sqs_send_receive" {
  name        = "CloudWrightSendSQSMessage${var.deployment_zone_namespace}"
  path        = "${local.iam_path}"

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
    "Resource": "arn:aws:sqs:*:*:cldwrt*"
  }]}
EOF
}

resource "aws_iam_role_policy_attachment" "function_sqs_use" {
  role       = "${aws_iam_role.cloudwright_function.name}"
  policy_arn = aws_iam_policy.sqs_send_receive.arn
}

resource "aws_iam_role_policy_attachment" "function_lambda_vpc_use" {
  role       = "${aws_iam_role.cloudwright_function.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}


resource "aws_iam_policy" "invoker_lambda_invoke" {
  name        = "CloudWrightFunctionExecute${var.deployment_zone_namespace}"
  path        = "${local.iam_path}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "lambda:InvokeFunction"
      ],
      "Effect": "Allow",
      "Resource": "arn:aws:lambda:*:*:*:cldwrt*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "invoker_lambda_execute" {
  role       = "${aws_iam_role.cloudwright_invoker.name}"
  policy_arn = aws_iam_policy.invoker_lambda_invoke.arn
}

resource "aws_kms_key" "cloudwright_key" {
  description             = "CloudWright key"
  deletion_window_in_days = 10
  policy                  = <<EOF
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
      "Principal": {"AWS": "${local.root_user_arn}"},
      "Action": "kms:*",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_api_gateway_rest_api" "gateway" {
  name        = "${var.deployment_zone_namespace}CloudWright"
  description = "The ${var.deployment_zone_name} CloudWright HTTP Endpoint Gateway"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_iam_policy" "gateway_admin" {
  name        = "CloudWrightGatewayAdmin${var.deployment_zone_namespace}"
  path        = "${local.iam_path}"
  description = "My test policy"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "apigateway:*"
      ],
      "Effect": "Allow",
      "Resource": "${aws_api_gateway_rest_api.gateway.arn}*"
    }
  ]
}
EOF
}

resource "aws_iam_user_policy_attachment" "admin_gateway_admin" {
  user       = "${aws_iam_user.cloudwright_admin.name}"
  policy_arn =  aws_iam_policy.gateway_admin.arn
}

resource "aws_iam_policy" "admin_cldwrt_admin_policy" {
  name        = "CloudWrightManageCloudWrightResources${var.deployment_zone_namespace}"
  path        = "${local.iam_path}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "lambda:*"
      ],
      "Effect": "Allow",
      "Resource": "arn:aws:lambda:*:*:*:cldwrt*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "sqs:*"
      ],
      "Resource": "arn:aws:sqs:*:*:cldwrt*"
    },
     {
      "Effect": "Allow",
      "Action": [
        "logs:List*",
        "logs:Get*",
        "logs:Describe*"
      ],
      "Resource": [
        "arn:aws:logs:*:*:log-group:/aws/lambda/cldwrt*"
      ]
    },
     {
      "Effect": "Allow",
      "Action": [
        "cloudwatch:*",
        "events:*",
      ],
      "Resource": [
        "arn:aws:events:*:*:rule/cldwrt*",
        "arn:aws:logs:*:*:log-group:/aws/lambda/cldwrt*"
      ]
    },
     {
      "Effect": "Allow",
      "Action": [
        "iam:ListRolePolicies",
        "iam:ListAttachedRolePolicies",
        "iam:GetRole",
        "iam:PassRole"
      ],
      "Resource": [
        "${aws_iam_role.cloudwright_function.arn}",
        "${aws_iam_role.cloudwright_invoker.arn}"

      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "lambda:ListEventSourceMappings"
      ],
      "Resource":"*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "lambda:DeleteEventSourceMapping",
        "lambda:UpdateEventSourceMapping",
        "lambda:CreateEventSourceMapping",
        "lambda:GetEventSourceMapping"
      ],
      "Resource":"*",
      "Condition": {
        "StringLike": {
            "lambda:FunctionArn": "arn:aws:lambda:*:*:function:cldwrt*"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeVpcs"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_user_policy_attachment" "admin_manage" {
  user       = "${aws_iam_user.cloudwright_admin.name}"
  policy_arn =  aws_iam_policy.admin_cldwrt_admin_policy.arn
}

