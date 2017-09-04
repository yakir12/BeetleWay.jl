file = joinpath(Pkg.dir("Gtk"), "src", "selectors.jl")
run(`sed -i '82i yield()' $file`)
