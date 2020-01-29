output ips {
    value = [aws_instance.webserver.*.public_ip]
}