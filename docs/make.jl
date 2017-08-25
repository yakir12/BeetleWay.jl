using Documenter, BeetleWay

makedocs(;
    modules=[BeetleWay],
    format=:html,
    pages=[
        "Home" => "index.md",
    ],
    repo="https://github.com/yakir12/BeetleWay.jl/blob/{commit}{path}#L{line}",
    sitename="BeetleWay.jl",
    authors="yakir12",
    assets=[],
)

deploydocs(;
    repo="github.com/yakir12/BeetleWay.jl",
    target="build",
    julia="0.6",
    deps=nothing,
    make=nothing,
)
