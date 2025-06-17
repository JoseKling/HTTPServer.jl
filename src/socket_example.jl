using Sockets

host_name = "google.com"
println("Connecting to " * host_name)

try
    global hostIP = getaddrinfo(host_name)
catch
    @error  "Failed to resolve host name: $host_name"
end

println("This is the IP address of " * host_name)
println(hostIP)


socket = connect(hostIP, 80)
println("Connected to " * host_name * " on port 80")
write(socket, "GET / HTTP/1.0\r\nHost: $host_name\r\n\r\n")
response = readavailable(socket)
println("Response from server:")
println(String(response))
close(socket)
println("Socket closed")
