using Sockets

println("Configuring an echo server")
server = listen(2000)
println("Server is listening on port 2000")
conn = accept(server)
println("Connection accepted")
while true
    line = readline(conn)
    write(conn, line)
    println("Echoed: $line")
    if line == "exit"
        println("Exiting echo server")
        break
    end
end
close(conn)
close(server)
println("Server closed")
