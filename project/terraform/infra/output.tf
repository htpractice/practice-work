output "key_name" {
  value = aws_key_pair.generated_key.key_name
  description = "value of the key_name"
}