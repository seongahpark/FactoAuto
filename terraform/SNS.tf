resource "aws_sns_topic" "tf_stock_empty" {
  name = "tf_stock_empty"
  //lambda_success_feedback_role_arn = aws_lambda_function.stock_empty_lambda.arn
}

resource "aws_sns_topic_subscription" "tf_stock_empty_sqs_target" {
  topic_arn = aws_sns_topic.tf_stock_empty.arn
  protocol = "sqs"
  endpoint = aws_sqs_queue.tf_stock_queue.arn
}

resource "aws_sns_topic_policy" "default" {
  arn = aws_sns_topic.tf_stock_empty.arn

  policy = data.aws_iam_policy_document.sns_topic_policy.json
}

data "aws_iam_policy_document" "sns_topic_policy" {
  policy_id = "__default_policy_ID"

  statement {
    actions = [
      "SNS:Subscribe",
      "SNS:SetTopicAttributes",
      "SNS:RemovePermission",
      "SNS:Receive",
      "SNS:Publish",
      "SNS:ListSubscriptionsByTopic",
      "SNS:GetTopicAttributes",
      "SNS:DeleteTopic",
      "SNS:AddPermission",
    ]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceOwner"

      values = [
        "948190516250",
      ]
    }

    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    resources = [
      aws_sns_topic.tf_stock_empty.arn,
    ]

    sid = "__default_statement_ID"
  }
}
