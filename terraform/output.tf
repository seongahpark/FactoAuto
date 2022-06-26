output "rest_api_url" {
    value = aws_api_gateway_deployment.stock_inc_api.invoke_url
    description = "CALLBACK_URL로 들어갈 stock_inc_lambda 엔드포인트"
}

output "stage_name" {
    value = aws_api_gateway_stage.stock_inc_api.stage_name
}