@require "server" start Response
@require "static" serve

function downstream(req)
  Response(200, "Handled downstream")
end

start(serve(".", downstream, index="index.jl"), 8000)
