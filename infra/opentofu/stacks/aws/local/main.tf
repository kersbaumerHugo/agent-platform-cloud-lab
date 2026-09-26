resource "aws_vpc" "agent_platform" {
  cidr_block = "10.0.0.0/16"

  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "vpc-agent-platform-local"
    Environment = "local"
    ManagedBy   = "opentofu"
  }
}

resource "aws_subnet" "public_a" {
  vpc_id            = aws_vpc.agent_platform.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "subnet-agent-platform-public-a"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id            = aws_vpc.agent_platform.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "subnet-agent-platform-public-b"
  }
}

resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.agent_platform.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "subnet-agent-platform-private-a"
  }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.agent_platform.id
  cidr_block        = "10.0.12.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "subnet-agent-platform-private-b"
  }
}
resource "aws_internet_gateway" "agent_platform" {
  vpc_id = aws_vpc.agent_platform.id

  tags = {
    Name = "igw-agent-platform-local"
  }
}
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.agent_platform.id

  tags = {
    Name = "rt-agent-platform-public"
  }
}
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.agent_platform.id

  tags = {
    Name = "rt-agent-platform-private"
  }
}
resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private.id
}
resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.agent_platform.id
}