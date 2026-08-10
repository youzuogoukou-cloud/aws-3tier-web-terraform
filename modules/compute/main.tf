resource "aws_security_group" "ec2_sg" {
  name        = "${var.project_name}_ec2_sg"
  description = "Security group for EC2: allow HTTP from ALB"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}_ec2_sg" }
}

resource "aws_security_group" "alb_sg" {
  name        = "${var.project_name}_alb_sg"
  description = "Security group for ALB: allow HTTP from internet"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}_alb_sg" }
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

resource "aws_lb_listener" "alb_listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "80"
  protocol          = "HTTP"

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

  iam_instance_profile { name = aws_iam_instance_profile.ssm_profile.name }

  user_data = base64encode(<<-EOF
            #!/bin/bash
            dnf install -y httpd
            systemctl enable --now httpd
            echo "<h1>Hello from $(hostname)</h1>" > /var/www/html/index.html
  EOF
  )

  tag_specifications {
    resource_type = "instance"

    tags = { Name = "${var.project_name}_ec2" }
  }
}

resource "aws_autoscaling_group" "asg" {
  name                = "${var.project_name}_asg"
  desired_capacity    = 2
  min_size            = 2
  max_size            = 2
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

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_profile" {
  name = "${var.project_name}_ec2_ssm_profile"
  role = aws_iam_role.ssm_role.name
}
