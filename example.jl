@require "server" start
@require "static" serve

start(serve(".", index="index.jl"), 8000)
