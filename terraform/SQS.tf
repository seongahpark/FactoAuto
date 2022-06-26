resource "aws_sqs_queue" "tf_stock_queue" {
  name = "tf_stock_queue"
  delay_seconds = 0
  max_message_size = 2048
  message_retention_seconds = 86400
  receive_wait_time_seconds = 0

  redrive_policy = jsonencode({
      deadLetterTargetArn = aws_sqs_queue.tf_dead_letter_queue.arn
      maxReceiveCount = 4
  })

  redrive_allow_policy = jsonencode({
      redrivePermission = "byQueue",
      sourceQueueArns = [aws_sqs_queue.tf_dead_letter_queue.arn]
  })

  tags = {
      environment = "production"
  }
}

resource "aws_sqs_queue" "tf_dead_letter_queue" {
  name = "tf_dead_letter_queue"
  delay_seconds = 0
  max_message_size = 2048
  message_retention_seconds = 86400
  receive_wait_time_seconds = 0

    tags = {
      environment = "production"
  }
}