resource "aws_lb" "app_alb" {
  name               = "app-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [module.public_instance_sg.this_security_group_id]
  subnets            = module.devops-ninja-vpc.public_subnets
}

resource "aws_lb_target_group" "front_end" {
  name     = "front-end"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 4
    interval            = 10
  }
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.front_end.arn
  }
}

resource "aws_lb_target_group_attachment" "front_end" {
  for_each         = toset(module.app.*.id)
  target_group_arn = aws_lb_target_group.front_end.arn
  target_id        = each.value
  port             = 80
}