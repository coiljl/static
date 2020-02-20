@use "github.com/jkroso/HTTP.jl/server" Request Response verb
@use "github.com/coiljl/mime" lookup compressible

"Support currying the first argument"
static(root::AbstractString; kw...) = req -> static(root, req; kw...)

"Handle case where it has downstream middleware"
static(root::AbstractString, next::Function; kw...) =
  function(req::Request)
    res = static(root, req; kw...)
    403 < res.status < 406 ? next(req) : res
  end

"Fallback Request handler"
static(root::AbstractString, r::Request; kw...) =
  Response(verb(r) == "OPTIONS" ? 204 : 405, Dict("Allow"=>"HEAD,GET,OPTIONS"))

"HEAD Request handler"
static(root::AbstractString, r::Request{:HEAD}; kw...) = begin
  res = static(root, Request{:GET}(r.uri, r.meta, r.data); kw...)
  Response(res.status, res.meta, "")
end

"GET Request handler"
static(root::AbstractString, req::Request{:GET}; index="index.html", transform=identity) = begin
  root = abspath(root)
  path = req.uri.path

  '\0' in path && return Response(400, "null bytes not allowed")
  # path is always relative to root
  if startswith(path, '/') path = path[2:end] end
  path = normpath(joinpath(root, path))
  startswith(path, root) || return Response(400, "$(req.uri.path) out of bounds")

  # index file support
  if isdir(path) && isfile(joinpath(path, index))
    path = joinpath(path, index)
  end

  ispath(path) || return Response(404)
  file = meta_data(path, transform)

  # cache is valid
  if get(req.meta, "If-None-Match", nothing) == file[:etag]
    return Response(304)
  end

  meta = Dict("Content-Length" => file[:size],
              "Content-Type" => file[:type],
              "ETag" => file[:etag])

  # can send compressed version
  if haskey(file, :cpath) && accepts(req, "gzip")
    path = file[:cpath]
    meta["Content-Encoding"] = "gzip"
    meta["Content-Length"] = file[:csize]
  else
    path = file[:path]
  end

  stream = open(path)
  finalizer(close, stream)
  Response(200, meta, stream)
end

accepts(req::Request, encoding::String) = encoding in split(get(req.meta, "Accept-Encoding", ""), r", ?")

const cache = Dict{AbstractString,Dict{Symbol,Any}}()

"Generate meta data about a file"
meta_data(path::AbstractString, transform) = begin
  last_modified = mtime(path)
  if haskey(cache, path) && last_modified === cache[path][:time]
    return cache[path]
  end
  tpath = transform(path)
  mime = lookup(tpath)
  if mime === nothing mime = "application/octet-stream" end
  meta = Dict{Symbol,Any}(
    :etag => string(hash(read(path))),
    :size => stat(tpath).size,
    :time => last_modified,
    :type => mime,
    :path => tpath)

  if compressible(mime)
    cpath = tpath * ".gz"
    run(`gzip $tpath -kqnf`)
    size = stat(cpath).size

    # make sure its actually smaller
    if size < stat(path).size
      meta[:cpath] = cpath
      meta[:csize] = string(size)
    else
      rm(cpath)
    end
  end

  cache[path] = meta
end
