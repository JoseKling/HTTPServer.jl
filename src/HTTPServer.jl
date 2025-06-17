module HTTPServer

using Sockets
using JSON3

export start_server
export Router, add_route!, shutdown_route!

include("Requisites.jl")
include("APIServer.jl")

end