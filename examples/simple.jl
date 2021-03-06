@use "github.com/jkroso/HTTP.jl/server" serve
@use ".." static

const server = serve(static(".", index="Readme.ipynb"), 8000)

println("Static server waiting at http://localhost:8000")
wait(server)
