#!/bin/sh
# Immutable demo release v1.1.0.
IFS=' ' read -r method path protocol || exit 0
case "$method:$path" in
  GET:/health)
    printf 'HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 3\r\nConnection: close\r\n\r\nok\n'
    ;;
  GET:/version)
    printf 'HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 7\r\nConnection: close\r\n\r\nv1.1.0\n'
    ;;
  *)
    printf 'HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n'
    ;;
esac
