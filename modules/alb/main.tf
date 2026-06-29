# =============================================================================
# ALB MODULE — Application Load Balancer
# =============================================================================
# Traffic flow:
#   Internet → ALB (HTTPS:443) → Target Group → EKS Ingress Controller → Pods
# The Ingress Controller (AWS Load Balancer Controller) manages actual routing.
# This module creates the ALB shell and HTTPS listener; routing rules live in
# Kubernetes Ingress objects.
# =============================================================================

# ---------------------------------------------------------------------------
# ALB
# ---------------------------------------------------------------------------
resource "aws_lb" "main" {
  name               = "${var.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.security_group_id]
  subnets            = var.public_subnet_ids

  # Access logs written to S3 for compliance
  access_logs {
    bucket  = var.access_log_bucket
    prefix  = "alb/${var.name_prefix}"
    enabled = true
  }

  # Prevents accidental deletion
  enable_deletion_protection = var.enable_deletion_protection

  # HTTP/2 speeds up multiplexed connections
  enable_http2 = true

  idle_timeout = 60

  tags = merge(var.tags, { Name = "${var.name_prefix}-alb" })
}

# ---------------------------------------------------------------------------
# HTTP Listener — redirects all HTTP to HTTPS
# ---------------------------------------------------------------------------
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# ---------------------------------------------------------------------------
# HTTPS Listener — terminates TLS, forwards to default target group
# ---------------------------------------------------------------------------
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.default.arn
  }
}

# ---------------------------------------------------------------------------
# Default Target Group (catches unmatched requests — returns 404)
# ---------------------------------------------------------------------------
resource "aws_lb_target_group" "default" {
  name        = "${var.name_prefix}-default-tg"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  health_check {
    enabled             = true
    path                = "/health"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200-399"
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-default-tg" })
}

# ---------------------------------------------------------------------------
# WAF Association (optional)
# ---------------------------------------------------------------------------
resource "aws_wafv2_web_acl_association" "alb" {
  count        = var.waf_web_acl_arn != "" ? 1 : 0
  resource_arn = aws_lb.main.arn
  web_acl_arn  = var.waf_web_acl_arn
}
