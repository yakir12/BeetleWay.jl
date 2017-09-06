function fragment(folder::String)
    a = loadAssociation(folder)
    # names = shortest_file_names(a)
    i = 0
    allvideofolder = joinpath(folder, "allvideofolder$i")
    while isdir(allvideofolder)
        i += 1
        allvideofolder = replace(allvideofolder, r"(\d*)$", i)
    end
    mkdir(allvideofolder)
    for (i, poi) in enumerate(a.pois)
        name = joinpath(allvideofolder, "$i.mp4")
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
    end
end

function coordinates_gui(folder::String)

    a = loadAssociation(folder)
    builder = Builder(filename=joinpath(@__DIR__, "choose2track.glade"))

    # data
    poi2do = [p for (i, p) in enumerate(a.pois) if isfile(joinpath(folder, "log", "$i.h5"))]
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
    state = foldp(1, step) do i, Δ
        i2 = i + Δ 
        0 < i2 <= n ? i2 : i
    end
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

    foreach(track, init=nothing) do _
        p = value(poi)
        #=h5open(f5name, "w") do o
            @write o xyt
        end=#
    end
    foreach(done,  init = nothing) do _
        destroy(builder["window"])
    end
    showall(builder["window"])

end
