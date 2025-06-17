function start_server(router::Router; port=2000)
    shutdown = Ref(false)
    server = listen(port)
    @debug "Server is listening on port $port"
    println("Press 'Ctrl + C' to shut down the server")
    atexit(() -> begin; shutdown[] = true; Sockets.connect("127.0.0.1", port); close(server); println("Server down"); end)
    while !shutdown[]
        conn = accept(server)
        @async handle_connection(conn, router.routes)
    end
end

function handle_connection(conn, routes)
    cl_port = Int(getpeername(conn)[2])
    try
        @debug "Connection with port $cl_port accepted."
        req = parse_request(conn)
        @debug "Request parsed:\n$req"
        !haskey(routes, (req.method, req.path)) && throw(HTTPError(404, "Path/method not found: ($(req.method), $(req.path))"))
        head_dict = parse_headers(conn)
        @debug "Headers parsed:\n$head_dict"
        check_header(head_dict)
        body = parse_body(conn, head_dict)
        result, type = handle_route(req, body, routes)
        response!(conn, cl_port, 200, result, type)
    catch e
        @debug "Error: $e"
        if e isa HTTPError
            response!(conn, cl_port, e.code, e.msg)
        else
            response!(conn, cl_port, 500, "Internal server error: $e")
        end
    finally
        close(conn)
    end
end

function parse_request(conn)
    line = strip(readline(conn))
    parts = strip.(split(line))
    length(parts) != 3 && throw(HTTPError(400, "Invalid request: $line"))
    !startswith(parts[2], "/") && throw(HTTPError(400, "Invalid path: $(parts[2])"))
    !startswith(parts[3], "HTTP/") && throw(HTTPError(400, "Invalid version: $(parts[3])"))
    !(parts[3][6:end] in ["1.0", "1.1"]) && throw(HTTPError(400, "Invalid version: $(parts[3])"))
    return Request(parts[1], parts[2], parts[3][6:end])
end

function parse_headers(conn)
    head_dict = Dict{String,String}()
    while true
        line = strip(readline(conn))
        if isempty(line)
            break
        end
        parts = strip.(split(line, ":", limit=2))
        length(parts) != 2 && throw(HTTPError(400, "Invalid header: $line"))
        head_dict[parts[1]] = parts[2]
    end
    return head_dict
end

function check_header(dict)
    if haskey(dict, "Content-Length")
        !haskey(dict, "Content-Type") && throw(HTTPError(400, "Missing 'Content-Type' field"))
        !(dict["Content-Type"] in ["application/json", "text/plain"]) && throw(HTTPError(400, "Only JSON and plain text content are accepted."))
    end
end

function parse_body(conn, dict)
    try
        if haskey(dict, "Content-Length")
            body = read(conn, parse(Int, dict["Content-Length"]))
            if dict["Content-Type"] == "application/json"
                return JSON3.read(body)
            elseif dict["Content-Type"] == "text/plain"
                return String(body)
            end
        end
    catch e
        throw(HTTPError(500, "Error when parsing body: $e"))
    end
    return nothing
end

function handle_route(req, body, routes)
    try
        result = routes[(req.method, req.path)](body)
        if result isa String
            return result, "text/plain"
        else
            return JSON3.write(result), "application/json"
        end
        @debug "Handled route ($(req.method), $(req.path))"
    catch e
        @debug "Error: $e"
        throw(HTTPError(500, "Internal error when processing data: $e"))
    end
end

function response!(conn, port, code, msg, type="text/plain")
    code_msg = STATUS_TEXT[code]
    msg = msg * '\n'
    response = """HTTP/1.1 $(code) $(code_msg)\r\nContent-Type: $(type)\r\nContent-Length: $(sizeof(msg))\r\n\r\n$(msg)"""
    write(conn, response)
    @debug "Connection with port $(port) closed."
end
