@require "mime" lookup compressible
@require "Request" Request verb
@require "Response" Response

##
# Support currying the first argument
#
serve(root::String; kw...) = req -> serve(root, req; kw...)

##
# Handle case where it has downstream middleware
#
function serve(root::String, next::Function; kw...)
  function(req::Request)
    res = serve(root, req; kw...)
    403 < res.status < 406 ? next(req) : res
  end
end

##
# Fallback Request handler
#
function serve(root::String, r::Request; kw...)
  Response(verb(r) == "OPTIONS" ? 204 : 405, ["Allow"=>"HEAD,GET,OPTIONS"])
end

##
# HEAD Request handler
#
function serve(root::String, r::Request{:HEAD}; kw...)
  res = serve(root, Request{:GET}(r.uri, r.meta, nothing); kw...)
  Response(res.status, res.meta, nothing)
end

##
# GET Request handler
#
function serve(root::String, req::Request{:GET}; index="index.html")
  path = req.uri.path

  # index file support
  if isempty(path) || path[end] == '/' path *= index end

  path = resolve(abspath(root), path)
  isfile(path) || return Response(404)
  file = meta_data(path)

  # cache is valid
  if get(req.meta, "If-None-Match", nothing) == file[:etag]
    return Response(304)
  end

  meta = [
    "Content-Length" => file[:size],
    "Content-Type" => file[:type],
    "ETag" => file[:etag]
  ]

  # can send compressed version
  if haskey(file, :cpath) && accepts(req, "gzip")
    path = file[:cpath]
    meta["Content-Encoding"] = "gzip"
    meta["Content-Length"] = file[:csize]
  end

  stream = open(path)
  finalizer(stream, close)
  Response(200, meta, stream)
end

function accepts(req::Request, encoding::String)
  get(req.meta, "Accept-Encoding", nothing) == encoding
end

const cache = Dict{String,Dict{Symbol,Any}}()

##
# Generate meta data about a file
#
function meta_data(path::String)
  stats = stat(path)
  if haskey(cache, path) && stats.mtime === cache[path][:time]
    return cache[path]
  end
  mime = lookup(path)
  if mime === nothing mime = "application/octet-stream" end
  meta = Dict{Symbol,Any}({
    :etag => string(hash(open(readbytes, path))),
    :size => string(stats.size),
    :time => stats.mtime,
    :type => mime
  })

  if compressible(mime)
    cpath = path * ".gz"
    exists = ispath(cpath)
    exists || run(`gzip $path -kq`)
    size = stat(cpath).size

    # make sure its actually smaller
    if size < stats.size
      meta[:cpath] = cpath
      meta[:csize] = string(size)
    else
      exists || rm(cpath)
    end
  end

  return cache[path] = meta
end

##
# Join `root` and `path` and do securty checks
#
function resolve(root::String, path::String)
  @assert !in('\0', path) "null bytes not allowed"
  # path is always relative to root
  if beginswith(path, '/') path = path[2:end] end
  path = normpath(joinpath(root, path))
  @assert beginswith(path, root) "$path out of bounds"
  return path
end
