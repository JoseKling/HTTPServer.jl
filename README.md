# HTTPServer.jl

This is a simple HTTP server for educational purposes only, to better
understand how a server, or more specifically, a REST API server works.

The package allows users to set routes and start a server to listen for
connections and handle requests. Here is an example.

```julia
using HTTPServer

sum_handler(dict) = sum(dict[:data])
greeting_handler(name) = "Hello there, $(name)!"

router = Router()
add_route!(router, "POST", "/sum", sum_handler)
add_route!(router, "POST", "/sum", sum_handler)
add_route!(router, "GET", "/", () -> "Available routes: $(router.routes))"

start_server(router; port=8000)
```

Notice that the payload is not validated. It will simply send whatever
was in the body (provided the `Content-Type` is either `application/json`
or `text/plain`) to the handlers.
