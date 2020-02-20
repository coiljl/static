@use "github.com/jkroso/DOM.jl" @dom @css_str css need Container HTML
@use "github.com/jkroso/Rutherford.jl/draw.jl" doodle
import Markdown

function eval_file(file)
  dom = Kip.eval_module(joinpath(pwd(), file))
  dom isa Container{:html} && return dom
  @dom[:html
    [:head
      [:title titlecase(replace(basename(splitext(file)[1]), "-" => " "))]
      [:style String(read(transform("$(@dirname)/bin/styles.less", Val(:less))))]
      need(css[])]
    [:body dom]]
end

transform_file(fn, path, ext=".html") = begin
  t = joinpath(tempdir(), string(hash(path))) * ext
  open(fn, t, "w")
  t
end

extension(path) = Symbol(isdir(path) ? "/" : splitext(path)[end][2:end])

transform(path, mime=Val(extension(path))) = path

"Render file directory"
transform(dir, ::Val{:/}) =
  transform_file(dir) do io
    names = readdir(dir)
    show(io, "text/html", @dom[HTML
      [:div css"""
            display: flex
            flex-direction: column
            margin: 5em auto
            width: max-content
            border: 1px solid lightgrey
            border-radius: 3px
            > a {padding: 3px 10px; font-size: 1.2em; border-bottom: 1px solid lightgrey}
            > a:last-child {border-bottom: none}
            """
        (@dom[:a href=string("./", name) name] for name in names)...]])
  end

transform(path, ::Val{:jade}) =
  transform_file(path) do io
    run(pipeline(path, `pug`, io))
  end

transform(path, ::Val{:jl}) =
  transform_file(path) do io
    show(io, "text/html", eval_file(path))
  end

transform(path, ::Val{:md}) =
  transform_file(path) do io
    show(io, "text/html", @dom[:html
      [:head
        [:title titlecase(replace(basename(splitext(path)[1]), "-"=>" "))]
        [:style String(read(transform("$(@dirname)/bin/styles.less", Val(:less))))]
        need(css[])]
      [:body
        [:div css"max-width: 50em; margin: 1em auto;" doodle(Markdown.parse_file(path, flavor=Markdown.github))]]])
  end

transform(path, ::Val{:less}) =
  transform_file(path, ".css") do io
    run(pipeline(`lessc $path`, io))
  end
