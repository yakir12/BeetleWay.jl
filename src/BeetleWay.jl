# __precompile__() 
module BeetleWay

using Gtk.ShortNames, GtkReactive, JLD

# const src_dir = @__DIR__
const src_dir = joinpath(Pkg.dir("BeetleWay"), "src")
const log_dir = joinpath(src_dir, "log")
const track_dir = joinpath(src_dir, "track")

include(joinpath(log_dir, "associations.jl"))
include(joinpath(log_dir, "glade_maker.jl"))

# folder = Signal(open_dialog("Select Video Folder", action=Gtk.GtkFileChooserAction.SELECT_FOLDER))
folder = joinpath(src_dir, "..", "test", "videofolder")

association = Association(folder)
metadata = association.md

# all the windows:
head_builder = Builder(filename=joinpath(src_dir, "head.glade"))
head_vis = Signal(true)
# showall(head_builder["window"])
foreach(x -> visible(head_builder["window"], x), head_vis)

log_builder = Builder(filename=joinpath(log_dir, "log.glade"))
log_vis = Signal(false)
# showall(log_builder["window"])
foreach(x -> visible(log_builder["window"], x), log_vis)


poi_builder = Builder(filename=joinpath(log_dir, "poi.glade"))
poi_vis = Signal(false)
# showall(poi_builder["window"])
foreach(x -> visible(poi_builder["window"], x), poi_vis)

glade_widgets = [typeof(l) => replace(f, ' ', '_') for (l,f) in zip(metadata.levels, metadata.factors)]
parse2glade(glade_widgets)

run_builder = Builder(filename=joinpath(log_dir, "run.glade"))
run_vis = Signal(false)
# showall(run_builder["window.run.wJqRk"])
foreach(x -> visible(run_builder["window.run.wJqRk"], x), run_vis)

video_builder = Builder(filename=joinpath(log_dir, "video.glade"))
video_vis = Signal(false)
# showall(video_builder["window"])
foreach(x -> visible(video_builder["window"], x), video_vis)

# track_builder = Builder(filename=joinpath(track_dir, "track.glade"))
# track_vis = Signal(false)
# showall(track_builder["window"])
# foreach(x -> visible(track_builder["window"], x), track_vis)


include(joinpath(log_dir, "gui.jl"))

# signals

# widgets
start_log = button(widget=head_builder["start.log"])

# id1 = signal_connect(_ -> log_gui(a), head_builder["start.log"], :clicked)
# id2 = signal_connect(_ -> report_gui(a), head_builder["preliminary.report"], :activate)
# id3 = signal_connect(_ -> fragment(a), head_builder["segment.videos"], :activate)
# id4 = signal_connect(_ -> coordinates_gui(a), head_builder["track"], :clicked)

# functions
foreach(start_log, init=nothing) do _
    push!(head_vis, false)
    push!(log_vis, true)
    nothing
end




end # module

# TODO:
# check the integratiy of the metadata
# maybe clearer error messages
# fix the travis errors!!!
