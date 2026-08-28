resource "aws_security_group" "ec2_sg" {
  name        = "${var.project_name}_ec2_sg"
  description = "Security group for EC2: allow HTTP from ALB"
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.project_name}_ec2_sg" }
}

resource "aws_vpc_security_group_ingress_rule" "ec2_from_alb" {
  security_group_id            = aws_security_group.ec2_sg.id
  referenced_security_group_id = aws_security_group.alb_sg.id
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
  description                  = "Allow HTTP from the ALB only"
}

resource "aws_vpc_security_group_egress_rule" "ec2_to_s3" {
  security_group_id = aws_security_group.ec2_sg.id
  prefix_list_id    = var.s3_prefix_list_id
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  description       = "Allow HTTPS to the s3"
}

resource "aws_vpc_security_group_egress_rule" "ec2_to_rds" {
  security_group_id = aws_security_group.ec2_sg.id
  cidr_ipv4         = var.vpc_cidr_block
  from_port         = 3306
  to_port           = 3306
  ip_protocol       = "tcp"
  description       = "Allow MySQL to the rds"
}

resource "aws_vpc_security_group_egress_rule" "ec2_to_ssm" {
  security_group_id = aws_security_group.ec2_sg.id
  cidr_ipv4         = var.vpc_cidr_block
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  description       = "Allow SSM to endpoint interface"
}

resource "aws_security_group" "alb_sg" {
  name        = "${var.project_name}_alb_sg"
  description = "Security group for ALB: allow HTTP from internet"
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.project_name}_alb_sg" }
}

resource "aws_vpc_security_group_ingress_rule" "alb_from_internet" {
  security_group_id = aws_security_group.alb_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  description       = "Allow HTTP from internet"
}

resource "aws_vpc_security_group_ingress_rule" "alb_from_redirect" {
  security_group_id = aws_security_group.alb_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  description       = "Allow HTTPS from redirect"
}


resource "aws_vpc_security_group_egress_rule" "alb_to_ec2" {
  security_group_id            = aws_security_group.alb_sg.id
  referenced_security_group_id = aws_security_group.ec2_sg.id
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
  description                  = "Allow HTTP to the EC2"
}

resource "aws_lb" "alb" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = var.public_subnet_ids
  security_groups    = [aws_security_group.alb_sg.id]

  enable_deletion_protection = false

  tags = { Name = "${var.project_name}_alb" }
}

resource "aws_lb_target_group" "alb_tg" {
  name        = "${var.project_name}-alb-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"
  health_check {
    interval            = 30
    unhealthy_threshold = 2
    port                = "80"
    protocol            = "HTTP"
    path                = "/"
    matcher             = "200"
  }
}

resource "aws_lb_listener" "alb_80listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "80"
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

resource "aws_lb_listener" "alb_443listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate.cert.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_tg.arn
  }
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

resource "aws_launch_template" "launch_temp" {
  name                   = "${var.project_name}_launch_temp"
  image_id               = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  iam_instance_profile { name = aws_iam_instance_profile.ssm_profile.name }

  user_data = base64encode(<<-EOF
            #!/bin/bash
            dnf install -y amazon-cloudwatch-agent
            cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<'AGENT'
            {
              "logs": {
                "logs_collected": {
                  "files": {
                    "collect_list": [
                    {
                      "file_path": "/var/log/httpd/access_alb_log",
                      "log_group_name": "${var.ec2_accesslog_name}",
                      "log_stream_name": "{instance_id}"
                    },{
                      "file_path": "/var/log/httpd/error_log",
                      "log_group_name": "${var.ec2_errorlog_name}",
                      "log_stream_name": "{instance_id}"
                    },{
                      "file_path": "/var/log/cloud-init-output.log",
                      "log_group_name": "${var.ec2_errorlog_name}",
                      "log_stream_name": "{instance_id}"
                    }
                    ]
                  }
                }
              }
            }
            AGENT
            /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
            dnf install -y httpd
            cat > /etc/httpd/conf.d/alb.conf << 'CONF'
            RemoteIPHeader X-Forwarded-For
            RemoteIPTrustedProxy 10.0.0.0/16
            LogFormat "%h %l %u %t \"%r\" %>s %b \"%%{Referer}i\" \"%%{User-Agent}i\" %%{c}a" alb_combined
            CustomLog "logs/access_alb_log" alb_combined
            CONF
            systemctl enable --now httpd
            echo "<h1>Hello from $(hostname)</h1>" > /var/www/html/index.html
  EOF
  )

  tag_specifications {
    resource_type = "instance"

    tags = { Name = "${var.project_name}_ec2" }
  }
}

resource "aws_autoscaling_policy" "asg_policy" {
  name                   = "${var.project_name}_asg_policy"
  autoscaling_group_name = aws_autoscaling_group.asg.name
  policy_type            = "TargetTrackingScaling"
  target_tracking_configuration {
    target_value = 50
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
  }
}

resource "aws_autoscaling_group" "asg" {
  name             = "${var.project_name}_asg"
  desired_capacity = 2
  min_size         = 2
  max_size         = 4
  lifecycle {
    ignore_changes = [desired_capacity]
  }
  vpc_zone_identifier = var.private_subnet_ids
  target_group_arns   = [aws_lb_target_group.alb_tg.arn]
  health_check_type   = "ELB"

  launch_template {
    id      = aws_launch_template.launch_temp.id
    version = "$Latest"
  }
}

resource "aws_iam_role" "ssm_role" {
  name = "${var.project_name}_ec2-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "cloudwatch_logs" {
  name = "${var.project_name}_cloudwatch_logs"
  role = aws_iam_role.ssm_role.id
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ],
        "Resource" : [
          "${var.ec2_accesslog_arn}:log-stream:*",
          "${var.ec2_errorlog_arn}:log-stream:*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_profile" {
  name = "${var.project_name}_ec2_ssm_profile"
  role = aws_iam_role.ssm_role.name
}

resource "tls_private_key" "cert_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "cert" {
  private_key_pem = tls_private_key.cert_key.private_key_pem

  subject {
    common_name  = "portfolio-web.example.com"
    organization = "portfolio-web"
  }
  dns_names             = ["portfolio-web.example.com"]
  validity_period_hours = 8760

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

# 自己署名証明書の NotBefore が未来扱いされ ACM インポートが拒否されるのを避ける待ち
resource "time_sleep" "wait_for_cert" {
  depends_on      = [tls_self_signed_cert.cert]
  create_duration = "150s"
}

resource "aws_acm_certificate" "cert" {
  private_key      = tls_private_key.cert_key.private_key_pem
  certificate_body = tls_self_signed_cert.cert.cert_pem
  depends_on       = [time_sleep.wait_for_cert]
}
