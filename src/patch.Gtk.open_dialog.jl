file = joinpath(Pkg.dir("Gtk"), "src", "selectors.jl")
open(file, "r") do o
    map(_ -> readline(o), 1:81)
    l = readline(o)
    r"yield"(l) || run(`sed -i '82i yield()' $file`)
end
