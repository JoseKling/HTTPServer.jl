using Sockets

println("Configuring an echo server")
server = listen(2000)
println("Server is listening on port 2000")
while true
    conn = accept(server)
    @async begin
        cl_port = Int(getpeername(conn)[2])
        println("Connection with port $cl_port accepted.")
        while true
            line = readline(conn)
            write(conn, line)
            if line == "exit"
                println("$cl_port exiting echo server")
                close(conn)
                break
            else
                println("Echoed: $line to port $cl_port.")
            end
        end
    end
end

