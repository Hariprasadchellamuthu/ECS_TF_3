provider "aws" {
  region = "ap-south-1"
}

resource "aws_security_group" "ecs_security_group" {
  name        = "ecs-security-group"
  description = "Security group for ECS tasks"
  vpc_id      = "vpc-0405817222cfcf446" # Replace with your VPC ID

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


module "ecs_cluster" {
  source  = "terraform-aws-modules/ecs/aws"
  version = "3.0.0"

  name = "jenkins-ecs-cluster"

  vpc_id                  = "vpc-0405817222cfcf446"  # Replace with your VPC ID
  subnet_ids              = ["subnet-09153db740467e15a", "subnet-01221c2705b0046bd", "subnet-01a2a1e8a4bea1176"]  # Replace with your subnet IDs
  security_group_ids      = aws_security_group.ecs_security_group.id  # Replace with your security group ID
  container_instance_type = "t2.micro"  # Replace with your desired instance type

  enable_container_insights = true
}

module "ecs_service" {
  source  = "terraform-aws-modules/ecs/aws//modules/service"
  version = "3.0.0"

  name        = "jenkins-ecs-service"
  cluster     = module.ecs_cluster.cluster_name
  launch_type = "EC2"

  task_definition_family = "jenkins-task-family"
  task_definition_name   = module.ecs_task_definition.task_definition_name

  desired_count = 1
}

module "ecs_task_definition" {
  source  = "terraform-aws-modules/ecs/aws//modules/task-definition"
  version = "3.0.0"

  name        = "jenkins-task-family"
  family      = "jenkins-task-family"
  network_mode = "bridge"

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
