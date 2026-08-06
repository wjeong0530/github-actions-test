data "archive_file" "notifier" {
  type        = "zip"
  source_dir  = "${path.module}/src/notifier"
  output_path = "${path.module}/build/product-change-notifier.zip"
}

resource "aws_sns_topic" "product_changes" {
  name = "${var.region_name}-product-changes"
}

resource "aws_sns_topic_subscription" "admin_email" {
  count     = var.admin_email == "" ? 0 : 1
  topic_arn = aws_sns_topic.product_changes.arn
  protocol  = "email"
  endpoint  = var.admin_email
}

resource "aws_iam_role" "notifier" {
  name = "${var.region_name}-product-change-notifier-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = "sts:AssumeRole", Principal = { Service = "lambda.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy_attachment" "logs" {
  role       = aws_iam_role.notifier.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "notifier" {
  name = "${var.region_name}-product-change-notifier-policy"
  role = aws_iam_role.notifier.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["dynamodb:GetRecords", "dynamodb:GetShardIterator", "dynamodb:DescribeStream"], Resource = var.product_table_stream_arn },
      { Effect = "Allow", Action = ["dynamodb:ListStreams"], Resource = "*" },
      { Effect = "Allow", Action = ["sns:Publish"], Resource = aws_sns_topic.product_changes.arn }
    ]
  })
}

resource "aws_lambda_function" "notifier" {
  function_name    = "${var.region_name}-product-change-notifier"
  role             = aws_iam_role.notifier.arn
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  timeout          = 15
  filename         = data.archive_file.notifier.output_path
  source_code_hash = data.archive_file.notifier.output_base64sha256

  environment { variables = { TOPIC_ARN = aws_sns_topic.product_changes.arn } }
}

resource "aws_lambda_event_source_mapping" "product_changes" {
  event_source_arn  = var.product_table_stream_arn
  function_name     = aws_lambda_function.notifier.arn
  starting_position = "LATEST"
  batch_size        = 10
}
