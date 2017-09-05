module BeetleWay

using Gtk.ShortNames, GtkReactive, DataStructures

# patches
include(joinpath(@__DIR__, "patches.jl"))

include(joinpath(@__DIR__, "log", "gui.jl"))
include(joinpath(@__DIR__, "log", "preliminary_report.jl"))
include(joinpath(@__DIR__, "track", "segment.jl"))


folder = open_dialog("Select Video Folder", action=Gtk.GtkFileChooserAction.SELECT_FOLDER)
# folder = "/home/yakir/datasturgeon/projects/marie/afterLog/therese"

b = Builder(filename=joinpath(@__DIR__, "head.glade"))
id1 = signal_connect(_ -> log_gui(folder), b["start.log"], :clicked)
id2 = signal_connect(_ -> report_gui(folder), b["preliminary.report"], :activate)
id3 = signal_connect(_ -> fragment(folder), b["segment.videos"], :activate)


showall(b["head.window"])


end # module


#=using GtkReactive, Gtk.ShortNames
w = Window("a")
a = button("a")
b = Box(:h)
push!(b, a)
foreach(a) do _
    cb = checkbox(rand(Bool))
    foreach(println, cb)
    push!(b, cb)
    showall(w)
end
push!(w, b)
showall(w)=#

