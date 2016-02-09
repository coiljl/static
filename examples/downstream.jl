@require "github.com/coiljl/server" serve Response
@require ".." static

downstream(req) = Response("Handled downstream")

const server = serve(static(".", downstream, index="Readme.ipynb"), 8000)

println("Static server waiting at http://localhost:8000")
wait(server)
