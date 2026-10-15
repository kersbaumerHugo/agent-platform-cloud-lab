# Floci local: uses emulator-assigned default Security Group.
# Security-group isolation is not validated by this stack.

resource "aws_instance" "app" {
  ami                         = "ami-alpine"
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.private_a.id
  associate_public_ip_address = false

  user_data_replace_on_change = true

  user_data = <<-SCRIPT
    #!/bin/sh
    set -eu

    mkdir -p /srv/app

    cat > /srv/app/health-handler.sh <<'HANDLER'
    #!/bin/sh
    IFS=' ' read -r method path protocol || exit 0

    if [ "$method" = "GET" ] && [ "$path" = "/health" ]; then
      printf 'HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 3\r\nConnection: close\r\n\r\nok\n'
    else
      printf 'HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n'
    fi
    HANDLER

    chmod 755 /srv/app/health-handler.sh

    busybox nc -lk -p 8080 -e /srv/app/health-handler.sh </dev/null >/tmp/health-listener.log 2>&1 &
  SCRIPT

  tags = {
    Name = "ec2-agent-platform-app"
  }
}

output "app_instance_id" {
  description = "ID of the simulated application instance"
  value       = aws_instance.app.id
}
