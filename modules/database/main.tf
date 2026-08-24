resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "${var.project_name}-rds-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = { Name = "${var.project_name}_rds-subnet-group" }
}

resource "aws_security_group" "rds_sg" {
  name        = "${var.project_name}_rds_sg"
  description = "Security group for RDS: allow TCP from EC2"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [var.ec2_sg_id]
    description     = "Allow tcp for MySQL from the EC2 only"
  }

  egress = []

  tags = { Name = "${var.project_name}_rds_sg" }
}

resource "aws_db_instance" "rds" {
  allocated_storage           = 10
  db_name                     = "${replace(var.project_name, "-", "_")}_db"
  identifier                  = "${var.project_name}-db"
  engine                      = "mysql"
  engine_version              = "8.4"
  instance_class              = "db.t3.micro"
  manage_master_user_password = true
  db_subnet_group_name        = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids      = [aws_security_group.rds_sg.id]
  username                    = "admin"
  skip_final_snapshot         = true
  storage_encrypted           = true
  publicly_accessible         = false
  backup_retention_period     = 1
  maintenance_window          = "Mon:16:00-Mon:16:30"
  backup_window               = "17:00-17:30"
  multi_az                    = false
}