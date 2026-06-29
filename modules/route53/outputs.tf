output "certificate_arn" {
  description = "ARN of the validated ACM certificate"
  value       = aws_acm_certificate_validation.main.certificate_arn
}

output "zone_id" {
  value = data.aws_route53_zone.main.zone_id
}

output "app_fqdns" {
  description = "Fully-qualified domain names created"
  value       = [for r in aws_route53_record.app : r.fqdn]
}
