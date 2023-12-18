provider "aws" {
  region = "ap-south-1"  # Replace with your AWS region
}

resource "aws_iam_role_policy" "ecs_execution_role_policy" {
  name   = "ecs_execution_role_policy"
  role   = aws_iam_role.ecs_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "ec2:CreateTags",
          "ec2:RunInstances",
          "ec2:StopInstances",
          "ec2:StartInstances",
          "ec2:TerminateInstances",
          # Add other EC2 related actions as necessary
        ],
        Resource = "*",
      },
    ],
  })
}

resource "aws_iam_role" "ecs_task_role" {
  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Action    = "sts:AssumeRole",
        Effect    = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "ecs_task_role_policy" {
  name   = "ecs_task_role_policy"
  role   = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "iam:PassRole",
          "iam:CreateRole",
          "iam:AttachRolePolicy",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:DeleteRole",
          # Add other IAM related actions as necessary
          "ec2:DescribeSecurityGroups",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupIngress",
          # Add other security group related actions as necessary
        ],
        Resource = "*",
      },
    ],
  })
}

resource "aws_ecs_cluster" "python_cluster" {
  name = "python-ecs-cluster"
}

resource "aws_launch_configuration" "ecs_launch_configuration" {
  name                 = "ecs-launch-config"
  image_id             = "ami-0aee0743bf2e81172"  # Replace with your AMI ID
  instance_type        = "t2.small"  # Choose instance type as per your requirements

  # No need to specify associate_public_ip_address here since we're not using subnets
  # Other configurations for the launch configuration as needed
  # For instance, key_name, user_data, etc.
}

resource "aws_autoscaling_group" "ecs_autoscaling_group" {
  desired_capacity     = 1  # Number of instances to launch initially
  max_size             = 3  # Maximum number of instances in the group
  min_size             = 1  # Minimum number of instances in the group

  launch_configuration = aws_launch_configuration.ecs_launch_configuration.id
  # Since we're using the default VPC, no need to specify vpc_zone_identifier
}

resource "aws_ecs_task_definition" "python_task_definition" {
  family                   = "python-task-family"
  network_mode             = "bridge"  # Using bridge network mode for EC2 launch type

  cpu    = "512"   # 0.5 vCPU
  memory = "1024"  # 1GB

  execution_role_arn = aws_iam_role.ecs_execution_role.arn
  task_role_arn      = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name  = "python-container"
      image = "amazonlinux:latest"
      cpu   = 512
      memory = 1024
      essential = true
      command = [
        "/bin/bash",
        "-c",
        "yum update -y && yum install -y python3.6"  # Replace with your Python script
      ]
    }
  ])
}

resource "aws_ecs_service" "python_ecs_service" {
  name            = "python-ecs-service"
  cluster         = aws_ecs_cluster.python_cluster.id
  task_definition = aws_ecs_task_definition.python_task_definition.arn
  launch_type     = "EC2"

  # No need to specify network_configuration when using bridge mode with default VPC
  # deployment_controller block remains the same
  deployment_controller {
    type = "ECS"
  }
  lifecycle {
    create_before_destroy = true
  }

  depends_on = [aws_ecs_task_definition.python_task_definition]
}
