__precompile__() 
module BeetleWay

using Gtk.ShortNames, GtkReactive, DataStructures#, HDF5
# const src = @__DIR__
const src = joinpath(Pkg.dir("BeetleWay"), "src")

# patches
# include(joinpath(@__DIR__, "patches.jl"))

include(joinpath(src, "log", "gui.jl"))
include(joinpath(src, "log", "preliminary_report.jl"))
include(joinpath(src, "track", "segment.jl"))
b = Builder(filename=joinpath(src, "head.glade"))
# folder = open_dialog("Select Video Folder", action=Gtk.GtkFileChooserAction.SELECT_FOLDER)
folder = joinpath(src, "..", "test", "videofolder")
# test the folder for any problems with the metadata
assert_metadata(folder)

id1 = signal_connect(_ -> log_gui(folder), b["start.log"], :clicked)
id2 = signal_connect(_ -> report_gui(folder), b["preliminary.report"], :activate)
id3 = signal_connect(_ -> fragment(folder), b["segment.videos"], :activate)
id4 = signal_connect(_ -> coordinates_gui(folder), b["track"], :clicked)


showall(b["head.window"])


end # module

# TODO:
# check the integratiy of the metadata
# maybe clearer error messages
# fix the travis errors!!!
