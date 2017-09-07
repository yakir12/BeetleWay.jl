__precompile__() 
module BeetleWay

using Gtk.ShortNames, GtkReactive, DataStructures#, HDF5

# patches
# include(joinpath(@__DIR__, "patches.jl"))

include(joinpath(@__DIR__, "log", "gui.jl"))
include(joinpath(@__DIR__, "log", "preliminary_report.jl"))
include(joinpath(@__DIR__, "track", "segment.jl"))

b = Builder(filename=joinpath(@__DIR__, "head.glade"))

# folder = open_dialog("Select Video Folder", action=Gtk.GtkFileChooserAction.SELECT_FOLDER)
folder = joinpath(first(splitdir(@__DIR__)), "test", "videofolder")

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
