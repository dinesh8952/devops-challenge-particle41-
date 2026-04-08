output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.app.name
}

output "sns_alerts_arn" {
  description = "SNS topic ARN for CloudWatch alarms — subscribe an email here to get paged"
  value       = aws_sns_topic.alerts.arn
}
