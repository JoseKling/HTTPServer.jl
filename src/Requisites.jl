struct Router
    routes::Dict{NTuple{2, String}, Function}

    Router() = new(Dict{NTuple{2, String}, Function}())
end

function add_route!(router::Router, method::String, path::String, handler::Function)
    router.routes[(method, path)] = handler
end

struct Request
    method::String
    path::String
    version::String
end

struct HTTPError
    code::Int
    msg::String
end

const STATUS_TEXT = Dict(
    200 => "OK",
    400 => "Bad Request",
    404 => "Not Found",
    405 => "Method Not Allowed",
    500 => "Internal Server Error"
)
