# __precompile__() 
module BeetleWay

using Gtk.ShortNames, GtkReactive, JLD

# const src = @__DIR__
const src_dir = joinpath(Pkg.dir("BeetleWay"), "src")
const log_dir = joinpath(src_dir, "log")

include(joinpath(log_dir, "associations.jl"))
# include(joinpath(log_dir, "gui.jl"))

# patches
# include(joinpath(@__DIR__, "patches.jl"))

# include(joinpath(src, "log", "gui.jl"))
# include(joinpath(src, "log", "preliminary_report.jl"))
# include(joinpath(src, "track", "segment.jl"))

# folder = Signal(open_dialog("Select Video Folder", action=Gtk.GtkFileChooserAction.SELECT_FOLDER))
folder = Signal(joinpath(src_dir, "..", "test", "videofolder"))


# signals
head_vis = Signal(true)
log_vis = Signal(false)
bind!(head_vis, !, log_vis, !)

# widgets
head_builder = Builder(filename=joinpath(src_dir, "head.glade"))
start_log = button(widget=head_builder["start.log"])
showall(head_builder["head.window"])

# association = map(x -> log_gui(x, start_log), folder)

# id1 = signal_connect(_ -> log_gui(a), head_builder["start.log"], :clicked)
# id2 = signal_connect(_ -> report_gui(a), head_builder["preliminary.report"], :activate)
# id3 = signal_connect(_ -> fragment(a), head_builder["segment.videos"], :activate)
# id4 = signal_connect(_ -> coordinates_gui(a), head_builder["track"], :clicked)

# functions
foreach(start_log) do _
    push!(log_vis, true)
end

foreach(x -> visible(head_builder["head.window"], x), head_vis)



end # module

# TODO:
# check the integratiy of the metadata
# maybe clearer error messages
# fix the travis errors!!!
