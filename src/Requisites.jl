"""
    Router
        routes::Dict{NTuple{2, String}, Function}

A simple router for handling HTTP requests in a server.
It maps HTTP methods and paths to handler functions.
It allows adding routes with the `add_route!` function.
"""
struct Router
    routes::Dict{NTuple{2, String}, Function}

    Router() = new(Dict{NTuple{2, String}, Function}())
end

"""
    add_route!(router::Router, method::String, path::String, handler::Function)

Adds a route to the router with the specified HTTP method, path, and handler function.
The `method` should be a string representing the HTTP method (e.g., "GET", "POST").
The `path` should be a string representing the URL path (e.g., "/api/resource").
The `handler` should be a function that takes a `Request` object and an optional body, and returns a response.
"""
function add_route!(router::Router, method::String, path::String, handler::Function)
    router.routes[(method, path)] = handler
end

"""
    Request
        method::String
        path::String
        version::String

A structure representing an HTTP request.
It contains the HTTP method, path, and version.
"""
struct Request
    method::String
    path::String
    version::String
end

"""
    HTTPError
        code::Int
        msg::String

A structure representing an HTTP error.
It contains an HTTP status code and a message.
"""
struct HTTPError
    code::Int
    msg::String
end

"""
    STATUS_TEXT
        Dict{Int, String}

A dictionary mapping HTTP status codes to their corresponding status messages.
"""
const STATUS_TEXT = Dict(
    200 => "OK",
    400 => "Bad Request",
    404 => "Not Found",
    405 => "Method Not Allowed",
    500 => "Internal Server Error"
)
