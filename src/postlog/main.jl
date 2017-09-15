foreach(log_vis) do x
    if !x
        a = value(associationᵗ)
        for p in a.pois, file in [p.start.file, p.stop.file]
            if all(file ≠ t.file for t in a.temporals) 
                creation, duration = VideoIO.get_time_duration(joinpath(a.md.folder, a.md.files[file]))
                push!(a.temporals, Temporal(file, creation, duration))
            end
        end
    end
end

function checkvideos(a::Association)
    # data
    n = length(a.temporals)
    # widgets
    done = button(widget=checktime_builder["done"])
    previous = button(widget=checktime_builder["previous"])
    next = button(widget=checktime_builder["next"])
    play = button(widget=checktime_builder["play"])
    # functions
    down = map(_ -> -1, previous)
    up = map(_ -> +1, next)
    step = merge(down, up)
    _state = foldp(1, step) do x,y
        clamp(x + y, 1, n)
    end
    state = droprepeats(_state)
    pb = progressbar(n, widget=checktime_builder["progressbar"], signal=state)
    file = map(state) do i
        metadata.files[a.temporals[i].file]
    end
    foreach(play, init=nothing) do _
        @spawn openit(joinpath(metadata.folder, value(file)))
        nothing
    end
    #=tsk, rslt = async_map(nothing, signal(play)) do _
        openit(joinpath(metadata.folder, value(file)))
        return nothing
    end=#
    datetime = map(state) do i
        a.temporals[i].creation
    end
    dt = datetimewidget(a.temporals[1].creation, widget=checktime_builder["datetime"], signal=datetime)
    label(ft[1].name, widget=checktime_builder["file.name"], signal=file)

    foreach(dt) do x
        i = value(state)
        ft[i] = Temporal(a.md, ft[i].name, x, ft[i].duration)
    end
    foreach(done,  init = nothing) do _
        # save(folder, OrderedSet{Temporal}(ft))
        push!(head_vis, false)
        push!(video_vis, true)
    end
end

