provider "aws" {
  region = "us-east-1"
}

# Create VPC and Subnets
resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "VPC_Pro2"
  }
}

resource "aws_subnet" "subnet_a" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1-a"
}

resource "aws_subnet" "subnet_b" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-east-1-b"
}

# ECS Cluster
resource "aws_ecs_cluster" "jenkins_cluster" {
  name = "jenkins-ecs-cluster"
}

# IAM Roles
resource "aws_iam_role" "ecs_execution_role" {
  name = "ecs-execution-role"

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

resource "aws_iam_role_policy" "ecs_execution_role_policy" {
  name   = "ecs_execution_role_policy"
  role   = aws_iam_role.ecs_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface",
        ],
        Resource = "*",
      },
    ],
  })
}

# ECS Task Definition
resource "aws_ecs_task_definition" "jenkins_task_definition" {
  family                   = "jenkins-task-family"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE", "EC2"]

  cpu    = "512"
  memory = "1024"

  execution_role_arn = aws_iam_role.ecs_execution_role.arn

  container_definitions = jsonencode([
    {
      name  = "jenkins-container"
      image = "jenkins/jenkins:lts"
      cpu   = 512
      memory = 1024
      essential = true
      portMappings = [
        {
          containerPort = 8080,
          hostPort      = 8080
        },
      ]
    }
  ])
}

# ECS Service
resource "aws_ecs_service" "jenkins_ecs_service" {
  name            = "jenkins-ecs-service"
  cluster         = aws_ecs_cluster.jenkins_cluster.id
  task_definition = aws_ecs_task_definition.jenkins_task_definition.arn
  launch_type     = "FARGATE"

  network_configuration {
    subnets = [aws_subnet.subnet_a.id, aws_subnet.subnet_b.id]
  }

  deployment_controller {
    type = "ECS"
  }

  lifecycle {
    create_before_destroy = true
  }
}
