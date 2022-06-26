resource "aws_iam_role" "iam_for_lambda" {
  name = "serverless_lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
    {
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Sid    = ""
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "iam_for_lambda" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.iam_for_lambda.arn
}

resource "aws_iam_policy" "iam_for_lambda" {
    policy = data.aws_iam_policy_document.iam_for_lambda.json
}

data "aws_iam_policy_document" "iam_for_lambda" {
  statement {
    sid       = "AllowSQSPermissions"
    effect    = "Allow"
    resources = ["arn:aws:sqs:*"]

    actions = [
      "sqs:ChangeMessageVisibility",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:ReceiveMessage",
    ]
  }

  statement {
    sid       = "AllowSNSPermissions"
    effect    = "Allow"
    resources = ["arn:aws:sns:*"]

    actions = [
        "SNS:GetTopicAttributes",
        "SNS:SetTopicAttributes",
        "SNS:AddPermission",
        "SNS:RemovePermission",
        "SNS:DeleteTopic",
        "SNS:Subscribe",
        "SNS:ListSubscriptionsByTopic",
        "SNS:Publish"
    ]
  }

  statement {
    sid       = "AllowInvokingLambdas"
    effect    = "Allow"
    resources = ["arn:aws:lambda:ap-northeast-2:*:function:*"]
    actions   = ["lambda:InvokeFunction"]
  }

  statement {
    sid       = "AllowCreatingLogGroups"
    effect    = "Allow"
    resources = ["arn:aws:logs:ap-northeast-2:*:*"]
    actions   = ["logs:CreateLogGroup"]
  }
  statement {
    sid       = "AllowWritingLogs"
    effect    = "Allow"
    resources = ["arn:aws:logs:ap-northeast-2:*:log-group:/aws/lambda/*:*"]

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
  }
}

#####################################################

data "archive_file" "sale_lambda" {
    type = "zip"

    source_dir = "${path.module}/sale-lambda"
    output_path = "${path.module}/files/sale-lambda.zip"
    output_file_mode = "0666"
}

data "archive_file" "stock_empty_lambda" {
    type = "zip"

    source_dir = "${path.module}/stock-empty-lambda"
    output_path = "${path.module}/files/stock-empty-lambda.zip"
    output_file_mode = "0666"
}

data "archive_file" "stock_inc_lambda" {
    type = "zip"

    source_dir = "${path.module}/stock-inc-lambda"
    output_path = "${path.module}/files/stock-inc-lambda.zip"
    output_file_mode = "0666"
}

resource "aws_lambda_function" "sale_lambda" {
    filename = "${path.module}/files/sale-lambda.zip"
    function_name = "sale-lambda"
    role = aws_iam_role.iam_for_lambda.arn
    handler = "index.handler"

    source_code_hash = data.archive_file.sale_lambda.output_base64sha256

    runtime = "nodejs14.x"

    environment {
      variables = {
          DB_HOST = var.db_host,
          DB_NAME = var.db_name,
          DB_PASSWORD = var.db_pw,
          DB_USER = var.db_user,
          TOPIC_ARN = aws_sns_topic.tf_stock_empty.arn
      }
    }
}

resource "aws_cloudwatch_log_group" "sale_lambda_cloudwatch" {
    name = "/aws/lambda/${aws_lambda_function.sale_lambda.function_name}"

    retention_in_days = 30
}

resource "aws_api_gateway_rest_api" "sale_api" {
    name = "sale_api"
}

resource "aws_api_gateway_resource" "sale_api" {
  path_part = "send"
  parent_id = aws_api_gateway_rest_api.sale_api.root_resource_id
  rest_api_id = aws_api_gateway_rest_api.sale_api.id
}

resource "aws_api_gateway_method" "sale_api" {
  rest_api_id = aws_api_gateway_rest_api.sale_api.id
  resource_id = aws_api_gateway_resource.sale_api.id
  http_method = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "sale_api" {
  rest_api_id = aws_api_gateway_rest_api.sale_api.id
  resource_id = aws_api_gateway_resource.sale_api.id
  http_method = aws_api_gateway_method.sale_api.http_method
  integration_http_method = "POST"
  type = "AWS_PROXY"
  uri = aws_lambda_function.sale_lambda.invoke_arn
}

resource "aws_lambda_permission" "sale_api" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.sale_lambda.function_name
  principal     = "apigateway.amazonaws.com"

  # More: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html
  source_arn = "arn:aws:execute-api:${var.region}:${var.aws_account}:${aws_api_gateway_rest_api.sale_api.id}/*/${aws_api_gateway_method.sale_api.http_method}${aws_api_gateway_resource.sale_api.path}"
}
resource "aws_api_gateway_deployment" "sale_api" {
  rest_api_id = aws_api_gateway_rest_api.sale_api.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.sale_api.id,
      aws_api_gateway_method.sale_api.id,
      aws_api_gateway_integration.sale_api.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}
resource "aws_api_gateway_stage" "sale_api" {
  deployment_id = aws_api_gateway_deployment.sale_api.id
  rest_api_id = aws_api_gateway_rest_api.sale_api.id
  stage_name = "sale_api"
}

resource "aws_lambda_function_event_invoke_config" "sale_lambda" {
  function_name = aws_lambda_function.sale_lambda.function_name

  destination_config {
    on_success {
      destination = aws_sns_topic.tf_stock_empty.arn
    }
  }
}

##########################################################################

resource "aws_lambda_function" "stock_empty_lambda" {
    filename = "${path.module}/files/stock-empty-lambda.zip"
    function_name = "stock-empty-lambda"
    role = aws_iam_role.iam_for_lambda.arn
    handler = "index.handler"

    source_code_hash = data.archive_file.stock_empty_lambda.output_base64sha256

    runtime = "nodejs14.x"

    environment {
        variables = {
            CALLBACKURL = aws_api_gateway_deployment.stock_inc_api.invoke_url
            CALLBACKURLSTAGE = aws_api_gateway_stage.stock_inc_api.stage_name
        }
    }   
}

resource "aws_cloudwatch_log_group" "stock_empty_lambda_cloudwatch" {
    name = "/aws/lambda/${aws_lambda_function.stock_empty_lambda.function_name}"

    retention_in_days = 30
}

resource "aws_lambda_permission" "with_sqs" {
    statement_id = "AllowExecutionFromSQS"
    action = "lambda:InvokeFunction"
    function_name = aws_lambda_function.stock_empty_lambda.function_name
    principal = "sqs.amazonaws.com"
    source_arn = aws_sqs_queue.tf_stock_queue.arn
}

resource "aws_lambda_event_source_mapping" "sqs_stock_empty_lambda" {
  event_source_arn = aws_sqs_queue.tf_stock_queue.arn
  function_name = aws_lambda_function.stock_empty_lambda.arn
  enabled = true
  batch_size = 10
}

#######################################################################

resource "aws_lambda_function" "stock_inc_lambda" {
    filename = "${path.module}/files/stock-inc-lambda.zip"
    function_name = "stock-inc-lambda"
    role = aws_iam_role.iam_for_lambda.arn
    handler = "index.handler"

    source_code_hash = data.archive_file.stock_inc_lambda.output_base64sha256

    runtime = "nodejs14.x"
}

resource "aws_cloudwatch_log_group" "stock_inc_lambda_cloudwatch" {
    name = "/aws/lambda/${aws_lambda_function.stock_inc_lambda.function_name}"

    retention_in_days = 30
}

resource "aws_api_gateway_rest_api" "stock_inc_api" {
    name = "stock_inc_api"
}

resource "aws_api_gateway_resource" "stock_inc_api" {
  path_part = "send"
  parent_id = aws_api_gateway_rest_api.stock_inc_api.root_resource_id
  rest_api_id = aws_api_gateway_rest_api.stock_inc_api.id
}

resource "aws_api_gateway_method" "stock_inc_api" {
  rest_api_id = aws_api_gateway_rest_api.stock_inc_api.id
  resource_id = aws_api_gateway_resource.stock_inc_api.id
  http_method = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "stock_inc_api" {
  rest_api_id = aws_api_gateway_rest_api.stock_inc_api.id
  resource_id = aws_api_gateway_resource.stock_inc_api.id
  http_method = aws_api_gateway_method.stock_inc_api.http_method
  integration_http_method = "POST"
  type = "AWS_PROXY"
  uri = aws_lambda_function.stock_inc_lambda.invoke_arn
}

resource "aws_lambda_permission" "stock_inc_api" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.stock_inc_lambda.function_name
  principal     = "apigateway.amazonaws.com"

  # More: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html
  source_arn = "arn:aws:execute-api:${var.region}:${var.aws_account}:${aws_api_gateway_rest_api.stock_inc_api.id}/*/${aws_api_gateway_method.stock_inc_api.http_method}${aws_api_gateway_resource.sale_api.path}"
}
resource "aws_api_gateway_deployment" "stock_inc_api" {
  rest_api_id = aws_api_gateway_rest_api.stock_inc_api.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.stock_inc_api.id,
      aws_api_gateway_method.stock_inc_api.id,
      aws_api_gateway_integration.stock_inc_api.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}
resource "aws_api_gateway_stage" "stock_inc_api" {
  deployment_id = aws_api_gateway_deployment.stock_inc_api.id
  rest_api_id = aws_api_gateway_rest_api.stock_inc_api.id
  stage_name = "stock_inc_api"
}