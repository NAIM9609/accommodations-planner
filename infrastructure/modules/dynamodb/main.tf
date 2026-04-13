resource "aws_dynamodb_table" "reservations" {
  name         = var.table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = {
    Name = var.table_name
  }

  lifecycle {
    prevent_destroy = !var.allow_table_destroy
  }
}
