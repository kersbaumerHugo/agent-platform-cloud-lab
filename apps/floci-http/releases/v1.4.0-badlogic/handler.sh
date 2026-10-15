#!/bin/sh
# Versioned demo: GET /sum?a=A&b=B returns decimal integer A+B.
# Intentional business-logic defect in badlogic release only.
IFS=' ' read -r method path protocol || exit 0

respond() {
  status="$1"
  payload="$2"
  printf 'HTTP/1.1 %s\r\nContent-Type: text/plain\r\nContent-Length: %s\r\nConnection: close\r\n\r\n%s\n' \
    "$status" "$((${#payload} + 1))" "$payload"
}

case "$method:$path" in
  GET:/health)
    respond '200 OK' ok
    ;;
  GET:/version)
    respond '200 OK' v1.4.0-badlogic
    ;;
  GET:/sum\?a=*\&b=*)
    query=${path#'/sum?a='}
    a=${query%%'&b='*}
    b=${query#*'&b='}
    case "$a" in ''|*[!0-9]*) respond '400 Bad Request' 'invalid a'; exit 0 ;; esac
    case "$b" in ''|*[!0-9]*) respond '400 Bad Request' 'invalid b'; exit 0 ;; esac
    # Limit digits and disallow leading zeroes: safe integer arithmetic in POSIX sh.
    if [ "${#a}" -gt 6 ] || [ "${#b}" -gt 6 ]; then
      respond '400 Bad Request' 'out of range'
      exit 0
    fi
    case "$a" in 0|[1-9]*) ;; *) respond '400 Bad Request' 'invalid a'; exit 0 ;; esac
    case "$b" in 0|[1-9]*) ;; *) respond '400 Bad Request' 'invalid b'; exit 0 ;; esac
    respond '200 OK' "$((a + b + 1))"
    ;;
  *)
    respond '404 Not Found' 'not found'
    ;;
esac
