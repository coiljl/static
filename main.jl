@require "github.com/coiljl/server" Request Response verb
@require "github.com/coiljl/mime" lookup compressible

##
# Support currying the first argument
#
static(root::AbstractString; kw...) = req -> static(root, req; kw...)

##
# Handle case where it has downstream middleware
#
static(root::AbstractString, next::Function; kw...) =
  function(req::Request)
    res = static(root, req; kw...)
    403 < res.status < 406 ? next(req) : res
  end

##
# Fallback Request handler
#
static(root::AbstractString, r::Request; kw...) =
  Response(verb(r) == "OPTIONS" ? 204 : 405, Dict("Allow"=>"HEAD,GET,OPTIONS"))

##
# HEAD Request handler
#
static(root::AbstractString, r::Request{:HEAD}; kw...) = begin
  res = static(root, Request{:GET}(r.uri, r.meta, r.data); kw...)
  Response(res.status, res.meta, nothing)
end

##
# GET Request handler
#
static(root::AbstractString, req::Request{:GET}; index="index.html") = begin
  root = abspath(root)
  path = req.uri.path

  # index file support
  if isempty(path) || path[end] == '/' path *= index end

  '\0' in path && return Response(400, "null bytes not allowed")
  # path is always relative to root
  if startswith(path, '/') path = path[2:end] end
  path = normpath(joinpath(root, path))
  startswith(path, root) || return Response(400, "$(req.uri.path) out of bounds")

  isfile(path) || return Response(404)
  file = meta_data(path)

  # cache is valid
  if get(req.meta, "If-None-Match", nothing) == file[:etag]
    return Response(304)
  end

  meta = Dict(
    "Content-Length" => file[:size],
    "Content-Type" => file[:type],
    "ETag" => file[:etag]
  )

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

accepts(req::Request, encoding::AbstractString) = get(req.meta, "Accept-Encoding", "") == encoding

const cache = Dict{AbstractString,Dict{Symbol,Any}}()

##
# Generate meta data about a file
#
meta_data(path::AbstractString) = begin
  stats = stat(path)
  if haskey(cache, path) && stats.mtime === cache[path][:time]
    return cache[path]
  end
  mime = lookup(path)
  if mime === nothing mime = "application/octet-stream" end
  meta = Dict{Symbol,Any}(
    :etag => string(hash(open(readbytes, path))),
    :size => string(stats.size),
    :time => stats.mtime,
    :type => mime)

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
