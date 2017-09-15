# __precompile__() 
module BeetleWay

# const folder = Signal(open_dialog("Select Video Folder", action=Gtk.GtkFileChooserAction.SELECT_FOLDER))
const folder = joinpath(src_dir, "..", "test", "videofolder")

using Gtk.ShortNames, GtkReactive, JLD, VideoIO

# directories
# const src_dir = @__DIR__
const src_dir = joinpath(Pkg.dir("BeetleWay"), "src")
const prelog_dir = joinpath(src_dir, "prelog")
const log_dir = joinpath(src_dir, "log")
const postlog_dir = joinpath(src_dir, "postlog")
const track_dir = joinpath(src_dir, "track")

# visibility constants
const head_vis = Signal(true)
const log_vis = Signal(false)
const poi_vis = Signal(false)
const run_vis = Signal(false)
const checktime_vis = Signal(false)


include(joinpath(prelog_dir, "associations.jl"))

association = Association(folder)
const metadata = association.md

# load all the GUI builders and set their visibility
const head_builder = Builder(filename=joinpath(src_dir, "head.glade"))
foreach(x -> visible(head_builder["window"], x), head_vis)

const log_builder = Builder(filename=joinpath(log_dir, "log.glade"))
foreach(x -> visible(log_builder["window"], x), log_vis)

const poi_builder = Builder(filename=joinpath(log_dir, "poi.glade"))
foreach(x -> visible(poi_builder["window"], x), poi_vis)

include(joinpath(prelog_dir, "glade_maker.jl"))
const run_builder = Builder(filename=joinpath(log_dir, "run.glade"))
foreach(x -> visible(run_builder["window.run.wJqRk"], x), run_vis)

const checktime_builder = Builder(filename=joinpath(postlog_dir, "checktime.glade"))
foreach(x -> visible(checktime_builder["window"], x), checktime_vis)

# track_builder = Builder(filename=joinpath(track_dir, "track.glade"))
# track_vis = Signal(false)
# showall(track_builder["window"])
# foreach(x -> visible(track_builder["window"], x), track_vis)

include(joinpath(log_dir, "main.jl"))
include(joinpath(postlog_dir, "main.jl"))

# head window widgets

start_log = button(widget=head_builder["start.log"])
foreach(start_log, init=nothing) do _
    push!(head_vis, false)
    push!(log_vis, true)
    nothing
end

checktime_id = signal_connect(head_builder["check.videos"], :activate) do _
    push!(head_vis, false)
    push!(checktime_vis, true)
end

split_videos_id = signal_connect(head_builder["split.videos"], :activate) do _
end

preliminary_report_id = signal_connect(head_builder["preliminary.report"], :activate) do _
end

quit_id = signal_connect(head_builder["quit"], :activate) do _
    quit()
end


end # module
