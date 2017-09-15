function poi2videofile(folder::String, poi::POI, i::Int)
    name = joinpath(folder,"POI_videos", "$i.mp4")
    isfile(name) && return name
    if poi.start.file ≠ poi.stop.file
        file = tempname()
        open(file, "w") do o
            for f in (poi.start.file, poi.stop.file)
                fullname = joinpath(folder, f)
                println(o, "file $fullname")
            end
        end
        Δ = duration(poi, folder)
        run(`ffmpeg -f concat -safe 0 -i $file -c copy -ss $(Dates.value(poi.start.time)) -to $Δ $name`)
    else
        fullname = joinpath(folder, poi.start.file)
        if poi.start.time == poi.stop.time
            run(`ffmpeg -i $fullname -c copy -ss $(Dates.value(poi.start.time)) -to $(Dates.value(poi.stop.time) + 1) $name`)
        else
            run(`ffmpeg -i $fullname -c copy -ss $(Dates.value(poi.start.time)) -to $(Dates.value(poi.stop.time)) $name`)
        end
    end
    return name
end

function fragment(folder::String)
    a = loadAssociation(folder)
    poi_folder = joinpath(folder,"POI_videos")
    isdir(poi_folder) || mkdir(poi_folder)
    for (i,p) in enumerate(a.pois)
        poi2videofile(folder, p, i)
    end
end

function coordinates_gui(folder::String)

    a = loadAssociation(folder)
    poi2do = [p for (i, p) in enumerate(a.pois) if isfile(joinpath(folder, "log", "$i.h5"))]
    isempty(poi2do) && return
    builder = Builder(filename=joinpath(@__DIR__, "choose2track.glade"))

    # data
    n = length(poi2do)
    # widgets
    done = button(widget=builder["done"])
    previous = button(widget=builder["previous"])
    next = button(widget=builder["next"])
    track = button(widget=builder["track"])
    # functions
    down = map(_ -> -1, previous)
    up = map(_ -> +1, next)
    step = merge(down, up)
    _state = foldp(1, step) do x,y
        clamp(x + y, 1, n)
    end
    state = droprepeats(_state)
    pb = progressbar(n, widget=builder["progressbar"], signal=state)
    poi = map(state) do i
        poi2do[i]
    end
    poilabel = map(p -> "<b>POI</b>: $(p.name), $(p.label)", poi)
    label(value(poilabel), widget=builder["poi"], signal=poilabel)
    runlabel = map(poi) do p
        r = String[]
        for (pp, rr) in a.associations
            if p == pp
                push!(r, """ 
                      <b>Run</b>
                      Repetition: <i>$(rr.repetition)</i>""")
                for (k, v) in rr.run.metadata
                    push!(r, "$k: <i>$v</i>")
                end
                push!(r, "Comment: <i>$(rr.run.comment)</i>")
            end
        end
        join(r, "\n")
    end
    label(value(runlabel), widget=builder["run"], signal=runlabel)

    poi_folder = joinpath(folder,"POI_videos")
    isdir(poi_folder) || mkdir(poi_folder)
    foreach(track, init=nothing) do _
        p = value(poi)
        i = first(find(p == x for x in a.pois))
        name = poi2videofile(folder, p, i) 
        #=h5open(f5name, "w") do o
            @write o xyt
        end=#
        nothing
    end
    foreach(done,  init = nothing) do _
        destroy(builder["window"])
    end
    showall(builder["window"])

end

#=
using Images
import ImageView
import VideoIO
video_file = "/home/yakir/datasturgeon/projects/marie/afterLog/lana/POI_videos/5.mp4"
=##=io = VideoIO.open(video_file)
f = VideoIO.openvideo(io)=##=
# As a shortcut for just video, you can upen the file directly
# with openvideo
f = VideoIO.openvideo(video_file)
# One can seek to an arbitrary position in the video
seek(f,2.5)  ## The second parameter is the time in seconds and must be Float64
img = read(f)

canvas, _ = ImageView.view(img)

while !eof(f)
    read!(f, img)
    ImageView.view(canvas, img)
    #sleep(1/30)
end

=##=using GtkReactive, Gtk.ShortNames
c = canvas(UserUnit)
win = Window(c)
img = Signal(testimage("lighthouse"))
imgsig = map(img) do i
    i
end
redraw = draw(c, imgsig) do cnvs, image
    copy!(cnvs, image)
end
showall(win)=##=


import ImageView
import VideoIO
f = VideoIO.testvideo("annie_oakley")  # downloaded if not available
VideoIO.playvideo(f)  # no sound
=#
