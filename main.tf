provider "aws" {
  region = "ap-south-1"
}

# Create a VPC
resource "aws_vpc" "ecs_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
}

# Create an ECS cluster
resource "aws_ecs_cluster" "ecs_cluster" {
  name = "ECS_JEN_CLUS"
}

# Create an IAM role for ECS instance profile
resource "aws_iam_role" "ecs_instance_role" {
  name = "ecs_instance_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com",
        },
      },
    ],
  })
}

resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name = "ecs_instance_profile"
  role = aws_iam_role.ecs_instance_role.name
}

# Create an ECS launch configuration
resource "aws_launch_configuration" "ecs_launch_config" {
  name = "ecs-launch-config"
  image_id = "ami-0aee0743bf2e81172"  # Use a Linux AMI ID
  instance_type = "t2.micro"
  iam_instance_profile = aws_iam_instance_profile.ecs_instance_profile.name
  user_data = <<-EOF
              #!/bin/bash
              echo ECS_CLUSTER=${aws_ecs_cluster.ecs_cluster.name} >> /etc/ecs/ecs.config
              EOF
}

# Create an ECS autoscaling group
resource "aws_autoscaling_group" "ecs_autoscaling_group" {
  desired_capacity     = 1
  max_size             = 1
  min_size             = 1
  vpc_zone_identifier = [aws_subnet.ecs_subnet.id]
  launch_configuration = aws_launch_configuration.ecs_launch_config.id
}

# Create a subnet for ECS instances
resource "aws_subnet" "ecs_subnet" {
  vpc_id                  = aws_vpc.ecs_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-south-1a"
}

# Create a security group for ECS instances
resource "aws_security_group" "ecs_security_group" {
  vpc_id = aws_vpc.ecs_vpc.id
  
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create an ECS task definition for Jenkins
resource "aws_ecs_task_definition" "jenkins_task" {
  family                   = "jenkins-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]

  container_definitions = jsonencode([
    {
      name  = "jenkins-container"
      image = "jenkins/jenkins:latest"  # Replace with your Jenkins image
      portMappings = [
        {
          containerPort = 8080,
          hostPort      = 8080,
        },
      ],
      memory = 512
    },
    
  ])
}

# Create an ECS service for Jenkins
resource "aws_ecs_service" "jenkins_service" {
  name            = "jenkins-service"
  cluster         = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.jenkins_task.arn
  launch_type     = "EC2"
  desired_count   = 1

  network_configuration {
    subnets = [aws_subnet.ecs_subnet.id]
    security_groups = [aws_security_group.ecs_security_group.id]
  }
}
