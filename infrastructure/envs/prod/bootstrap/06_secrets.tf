resource "aws_secretsmanager_secret" "grafana_admin" {
  name = "online-boutique/grafana-admin"
  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "grafana_admin" {
  secret_id = aws_secretsmanager_secret.grafana_admin.id
  secret_string = jsonencode({
    admin-user     = "admin"
    admin-password = var.grafana_admin_password
  })
}
