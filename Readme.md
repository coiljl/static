# static

Serve a directory of static files

Features:

- Protects against malicious requests
- Flexible default files
- Correctly sets Content-Type
- Handles gzip compression
- Handles ETag based caching
- Handles HEAD requests

```julia
@require "github.com/coiljl/static" static Request
```

## API

#### static(root::AbstractString, req::Request{:GET}; index="index.html")

Handles a request for a static file by looking for one matching req.uri.path in root. If successfull the Response will look like this:

```julia
static(".", Request(IOBuffer("GET /examples/simple.jl\r\n\r\n"))) # Response(200,Dict("Content-Length"=>"198","ETag"=>"2259599918482302498","Content-Type"=>"application/octet-stream"),IOStream(<file /Users/jkroso/Projects/JuliaLang/coil/static/examples/simple.jl>))
```

If no matching file is found the Response will look like this:


```julia
static(".", Request(IOBuffer("GET /not-a-file\r\n\r\n"))) # Response(404,Dict{ASCIIString,ASCIIString}(),"")
```

If the file has an etag matching the one in the Request it will be a 304 Not Changed Response

```julia
static(".", Request(IOBuffer("""GET /examples/simple.jl\r\nIf-None-Match: $(Out[2].meta["ETag"])\r\n\r\n"""))) # Response(304,Dict{ASCIIString,ASCIIString}(),"")
```

Additionally if the Request explicitly says it can accept gzip encoded data then the file will be compressed accordingly; so long as it actually ends up being smaller. Also by default if req.uri.path refers to a directory it will be expanded to req.uri.path * index

```julia
static(".", Request(IOBuffer("GET /\r\n\r\n")); index="main.jl") # Response(200,Dict("Content-Length"=>"2816","ETag"=>"13017586935762529160","Content-Type"=>"application/octet-stream"),IOStream(<file /Users/jkroso/Projects/JuliaLang/coil/static/main.jl>))
```

However this behaviour can be disabled by setting index to and empty String

```julia
static(".", Request(IOBuffer("GET /\r\n\r\n")); index="") # Response(404,Dict{ASCIIString,ASCIIString}(),"")
```

#### static(root::String, req::Request{:HEAD}; index="index.html")

```julia
static(".", Request(IOBuffer("HEAD /\r\n\r\n")); index="Readme.ipynb") # Response(200,Dict("Content-Length"=>"4419","ETag"=>"3206020198765577793","Content-Type"=>"application/octet-stream"),"")
static(root::String, req::Request{:OPTIONS})
```

```julia
static(".", Request(IOBuffer("OPTIONS /example.jl\r\n\r\n"))) # Response(204,Dict("Allow"=>"HEAD,GET,OPTIONS"),"")
```

#### static(root::String, req::Request)

All other HTTP request methods will be met with a 405 error

```julia
static(".", Request(IOBuffer("DELETE /example.jl\r\n\r\n"))) # Response(405,Dict("Allow"=>"HEAD,GET,OPTIONS"),"")
```
