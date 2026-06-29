output "alb_arn" {
  value = aws_lb.main.arn
}

output "alb_dns_name" {
  description = "DNS name of the ALB — use this as CNAME target in Route 53"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "Hosted zone ID of the ALB — required for Route 53 alias records"
  value       = aws_lb.main.zone_id
}

output "https_listener_arn" {
  value = aws_lb_listener.https.arn
}

output "default_target_group_arn" {
  value = aws_lb_target_group.default.arn
}
