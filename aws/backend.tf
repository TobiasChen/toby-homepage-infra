# DynamoDB 
resource "aws_dynamodb_table" "homepage-dynamodb" {
  attribute {
    name = "id"
    type = "N"
  }

  billing_mode                = "PROVISIONED"
  deletion_protection_enabled = "false"
  hash_key                    = "id"
  name                        = "homepage-dynamodb"

  point_in_time_recovery {
    enabled = "false"
  }

  read_capacity  = "1"
  stream_enabled = "false"
  table_class    = "STANDARD"
  write_capacity = "1"
}

resource "aws_dynamodb_table_item" "homepage-visitorCount-dynamodb-item" {
  table_name = aws_dynamodb_table.homepage-dynamodb.name
  hash_key   = aws_dynamodb_table.homepage-dynamodb.hash_key

  item = <<ITEM
{
  "id": {"N": "0"},
  "visits": {"N": "0"}
}
ITEM
}

# Lambda function

data "aws_iam_policy_document" "visitorCount-lambda-role-document" {
  statement {
    actions = ["dynamodb:DeleteItem","dynamodb:GetItem","dynamodb:PutItem","dynamodb:Scan","dynamodb:UpdateItem"]
    resources = [aws_dynamodb_table.homepage-dynamodb.arn]
    
  }
}

data "aws_iam_policy_document" "visitorCount-lambda-assume-role" {
  statement {
    actions = [
      "sts:AssumeRole"
    ]
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

  }
}

data "archive_file" "visitorCount-payload" {
  type        = "zip"
  source_file = "./lambda/visitorCount.js"
  output_path = "homepage-visitorCount-payload.zip"
}

resource "aws_iam_role" "visitorCount-lambda-role" {
  name               = "visitorCount-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.visitorCount-lambda-assume-role.json
}

resource "aws_iam_policy" "visitorCount-lambda-role-policy" {
    name        = "visitorCount-lambda-role-policy"
    path        = "/"
    policy      = data.aws_iam_policy_document.visitorCount-lambda-role-document.json
}

resource "aws_iam_role_policy_attachment" "visitorCount-lambda_basic_execution_attach_policy" {
  role       = "${aws_iam_role.visitorCount-lambda-role.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "visitorCount-lambda_dynamo_attach_policy" {
  role       = "${aws_iam_role.visitorCount-lambda-role.name}"
  policy_arn = aws_iam_policy.visitorCount-lambda-role-policy.arn
}

resource "aws_lambda_function" "homepage-visitorCount-lambda" {
  architectures = ["x86_64"]

  ephemeral_storage {
    size = "512"
  }

  function_name                  = "homepage-visitorCount-lambda"
  handler                        = "src/visitorCount.handler"
  filename                       = "homepage-visitorCount-payload.zip"
  memory_size                    = "128"
  package_type                   = "Zip"
  reserved_concurrent_executions = "-1"
  role                           =  aws_iam_role.visitorCount-lambda-role.arn
  runtime                        = "nodejs14.x"
  skip_destroy                   = "false"
  source_code_hash               = "W37X+5/HfqaSieallvFP0MbvvrCc/gr6O88GHAO8HhE="
  timeout                        = "3"

  tracing_config {
    mode = "PassThrough"
  }
}


data "aws_iam_policy_document" "github-deployment-backend-lambda-role-document" {
  statement {
    actions = ["lambda:UpdateFunctionCode"]
    resources = [aws_lambda_function.homepage-visitorCount-lambda.arn]
    
  }
}

data "aws_iam_policy_document" "github-deployment-backend-assume-role" {
  statement {
    actions = [
      "sts:AssumeRoleWithWebIdentity"
    ]
    principals {
      type        = "Federated"
      identifiers = ["arn:aws:iam::221675488713:oidc-provider/token.actions.githubusercontent.com"]
    }

    condition {
      test = "StringLike"
      variable =  "token.actions.githubusercontent.com:sub"
      values = [ "repo:TobiasChen/toby-homepage-backend:*"]
    }

    condition {
      test = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values = ["sts.amazonaws.com"]
    }

  }
}

resource "aws_iam_role" "github-deployment-backend-role" {
  name               = "github-deployment-backend-role"
  assume_role_policy = data.aws_iam_policy_document.github-deployment-backend-assume-role.json
}

resource "aws_iam_policy" "github-deployment-backend-role-policy" {
    name        = "github-deployment-backend-role-policy"
    path        = "/"
    policy      = data.aws_iam_policy_document.github-deployment-backend-lambda-role-document.json
}

resource "aws_iam_role_policy_attachment" "github-deployment-backend-attach_policy" {
  role       = "${aws_iam_role.github-deployment-backend-role.name}"
  policy_arn = aws_iam_policy.github-deployment-backend-role-policy.arn
}




# API Gateway for Lambda


resource "aws_apigatewayv2_api" "homepage-visitorCount-api" {
    name          = "homepage-visitorCount-api"
    protocol_type = "HTTP"
    disable_execute_api_endpoint = true
}

resource "aws_apigatewayv2_stage" "homepage-visitorCount-api-stage" {
  api_id = aws_apigatewayv2_api.homepage-visitorCount-api.id

  name        = "default"
  auto_deploy = true
}

resource "aws_apigatewayv2_integration" "homepage-visitorCount-api-integration" {
  api_id                    = aws_apigatewayv2_api.homepage-visitorCount-api.id
  integration_type          = "AWS_PROXY"
  integration_method        = "POST"
  integration_uri           = aws_lambda_function.homepage-visitorCount-lambda.invoke_arn
}

resource "aws_apigatewayv2_route" "homepage-visitorCount-api-route" {
  api_id = aws_apigatewayv2_api.homepage-visitorCount-api.id

  route_key = "ANY /visitorCount"
  target    = "integrations/${aws_apigatewayv2_integration.homepage-visitorCount-api-integration.id}"
}


variable "api_url" {
  type = string
}

resource "aws_apigatewayv2_domain_name" "homepage-visitorCount-api-domain" {
  domain_name = var.api_url

  domain_name_configuration {
    certificate_arn = "${aws_acm_certificate.website-api-domain-cert.arn}"
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }
}

resource "aws_apigatewayv2_api_mapping" "homepage-visitorCount-api-mapping" {
  api_id      = aws_apigatewayv2_api.homepage-visitorCount-api.id
  domain_name = aws_apigatewayv2_domain_name.homepage-visitorCount-api-domain.id
  stage       = aws_apigatewayv2_stage.homepage-visitorCount-api-stage.id
}

resource "aws_lambda_permission" "homepage-visitorCount-api-lambda-permission" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.homepage-visitorCount-lambda.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.homepage-visitorCount-api.execution_arn}/*/*"
}


output "api_url" {
  value = aws_apigatewayv2_api.homepage-visitorCount-api.api_endpoint
}


