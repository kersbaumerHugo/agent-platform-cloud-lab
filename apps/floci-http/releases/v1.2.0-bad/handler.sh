#!/bin/sh
# Intentionally unhealthy release for rollback exercise.
IFS=' ' read -r method path protocol || exit 0
case "$method:$path" in
  GET:/health)
    printf 'HTTP/1.1 503 Service Unavailable\r\nContent-Type: text/plain\r\nContent-Length: 5\r\nConnection: close\r\n\r\ndown\n'
    ;;
  GET:/version)
    printf 'HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 11\r\nConnection: close\r\n\r\nv1.2.0-bad\n'
    ;;
  *)
    printf 'HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n'
    ;;
esac
