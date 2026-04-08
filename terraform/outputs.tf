output "app_url" {
  description = "Public URL of the SimpleTimeService"
  value       = "http://${module.alb.alb_dns_name}"
}

output "alb_dns_name" {
  description = "DNS name of the ALB"
  value       = module.alb.alb_dns_name
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = module.ecs.ecs_cluster_name
}

output "ecs_service_name" {
  description = "ECS service name"
  value       = module.ecs.ecs_service_name
}

output "sns_alerts_arn" {
  description = "Subscribe an email to this SNS topic to receive CloudWatch alarm notifications"
  value       = module.ecs.sns_alerts_arn
}
