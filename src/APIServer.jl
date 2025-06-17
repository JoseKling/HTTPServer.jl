"""
    start_server(router::Router; port=2000)

Starts an HTTP server that listens for incoming connections on the specified port (default is 2000).
It accepts incoming requests, parses them, and routes them to the appropriate handler functions defined in the `router`.
The `router` should be an instance of the `Router` struct, which contains a dictionary of routes mapping HTTP methods and paths to handler functions.
"""
function start_server(router::Router; port=2000)
    # Server starts listening to all incoming connections in this port
    server = listen(port)
    @debug "Server is listening on port $port"
    println("Press 'Ctrl + C' to shut down the server")
    try
        while true
            # Accept any connection request
            conn = accept(server)
            # @async enables the program to handle the request while still listening to other requests
            @async handle_connection(conn, router.routes)
        end
    catch e
        # Waiting for the user to press 'Ctrl+C', but something else might have happenned
        !(e isa InterruptException) && rethrow(e)
    finally
        # Close the server after some error occurred or the process was interrupted
        close(server)
        println("Server down.")
    end
    return nothing
end

"""
    handle_connection(conn::Socket, routes::Dict{NTuple{2, String}, Function})

Handles an incoming connection from a client.
It parses the request, checks the headers, and routes the request to the appropriate handler function based on the HTTP method and path.
If the request is valid, it sends a response back to the client. If an error occurs, it sends an appropriate error response.
"""
function handle_connection(conn, routes)
    # Get the port of the client that made the request
    cl_port = Int(getpeername(conn)[2])
    try
        @debug "Connection with port $cl_port accepted."
        # Start by parsing the request
        req = parse_request(conn)
        @debug "Request parsed:\n$req"
        # Check if the request method and path are valid
        !haskey(routes, (req.method, req.path)) && throw(HTTPError(404, "Path/method not found: ($(req.method), $(req.path))"))
        # Parse the headers
        head_dict = parse_headers(conn)
        @debug "Headers parsed:\n$head_dict"
        # Check if the headers are valid
        check_header(head_dict)
        # Parse the body if it exists
        body = parse_body(conn, head_dict)
        # Send the data to the handler function
        result, type = handle_route(req, body, routes)
        # If this part is reached, the request was handled successfully
        response!(conn, cl_port, 200, result, type)
    catch e
        # If an error occurs, send the error response
        @debug "Error: $e"
        if e isa HTTPError
            # HTTP errors. Problems with request or headers
            response!(conn, cl_port, e.code, e.msg)
        else
            # Internal server errors. Problems with the server, handler, or incompatible data types.
            response!(conn, cl_port, 500, "Internal server error: $e")
        end
    finally
        close(conn)
    end
end

"""   
    parse_request(conn::Socket)

Parses the HTTP request from the client connection.
It reads the first line of the request to extract the HTTP method, path, and version.
Returns a `Request` object containing the method, path, and version.
If the request line is invalid, it throws an `HTTPError` with a 400 status code.
"""
function parse_request(conn)
    # Each line should contain the method, path, and version
    # Example: "GET /resource HTTP/1.1"
    # Returns a Request object with the method, path, and version
    line = strip(readline(conn))
    parts = strip.(split(line))
    length(parts) != 3 && throw(HTTPError(400, "Invalid request: $line"))
    !startswith(parts[2], "/") && throw(HTTPError(400, "Invalid path: $(parts[2])"))
    !startswith(parts[3], "HTTP/") && throw(HTTPError(400, "Invalid version: $(parts[3])"))
    !(parts[3][6:end] in ["1.0", "1.1"]) && throw(HTTPError(400, "Invalid version: $(parts[3])"))
    return Request(parts[1], parts[2], parts[3][6:end])
end

"""
    parse_headers(conn::Socket)

Parses the HTTP headers from the client connection.
It reads each line of the headers until an empty line is encountered, indicating the end of the headers.
Returns a dictionary with the header names as keys and their corresponding values.
"""
function parse_headers(conn)
    # Each line should contain a header in the format "Header-Name: Header-Value"
    # Example: "Content-Type: application/json"
    # An empty line indicates the end of the headers
    # Returns a dictionary with the headers
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

"""
    check_header(dict::Dict{String, String})

Checks the validity of the headers in the provided dictionary.
"""
function check_header(dict)
    # Our server checks only the Content-Length and Content-Type headers
    # If Content-Length is present, Content-Type must also be present
    # Only JSON and plain text content are accepted
    if haskey(dict, "Content-Length")
        !haskey(dict, "Content-Type") && throw(HTTPError(400, "Missing 'Content-Type' field"))
        !(dict["Content-Type"] in ["application/json", "text/plain"]) && throw(HTTPError(400, "Only JSON and plain text content are accepted."))
    end
end

"""
    parse_body(conn::Socket, dict::Dict{String, String})

Parses the body of the HTTP request from the client connection.
It reads the body based on the `Content-Length` header and parses it according to the `Content-Type`.
If the `Content-Type` is `application/json`, it parses the body as JSON and returns a parsed object.
If the `Content-Type` is `text/plain`, it returns the body as a string.
If the body is not present or the `Content-Length` header is missing, it returns `nothing`. 
"""
function parse_body(conn, dict)
    # Get the data from the body of the request, if it exists
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

"""
    handle_route(req::Request, body, routes)

Handles the routing of the HTTP request to the appropriate handler function based on the method and path.
It calls the handler function for the given route, passing the request body if it exists.
If the handler function returns a string, it is returned as the response body with a `text/plain` content type.
If the handler function returns a data structure, it is converted to JSON and returned with an `application/json` content type.
"""
function handle_route(req, body, routes)
    # Call the handler function for the given route
    # The handler function should return a String or a data structure that can be converted to JSON
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

"""
    response!(conn::Socket, port::Int, code::Int, msg::String, type="text/plain")

Sends an HTTP response back to the client.
It constructs the response with the specified HTTP status code, message, and content type.
If the content type is not specified, it defaults to `text/plain`.
"""
function response!(conn, port, code, msg, type="text/plain")
    # Send the response to the client
    code_msg = STATUS_TEXT[code]
    msg = msg * '\n'
    response = """HTTP/1.1 $(code) $(code_msg)\r\nContent-Type: $(type)\r\nContent-Length: $(sizeof(msg))\r\n\r\n$(msg)"""
    write(conn, response)
    @debug "Connection with port $(port) closed."
end
