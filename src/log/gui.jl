include(joinpath(@__DIR__, "associations.jl"))
include(joinpath(@__DIR__, "glade_maker.jl"))
include(joinpath(@__DIR__, "util.jl"))


function wire_poi_gui(vfs, folder, add_poi)
    files = OrderedSet([vf.file for vf in vfs])
    points = strip.(vec(readcsv(joinpath(folder, "metadata", "poi.csv"), String)))

    poi_in = Signal(POI(points[1], Point(files[1], Second(0)), Point(files[1], Second(0)), "", ""))
    name_in = map(x -> x.name, poi_in)
    f1_in = map(x -> x.start.file, poi_in)
    f2_in = map(x -> x.stop.file, poi_in)
    start_time_in = map(x -> Time(0) + x.start.time, poi_in)
    stop_time_in = map(x -> Time(0) + x.stop.time, poi_in)
    poi_label_in = map(x -> x.label, poi_in)
    poi_comment_in = map(x -> x.comment, poi_in)

    poi_builder = Builder(filename=joinpath(@__DIR__, "poi.glade"))

    # widgets
    name = dropdown(points; widget=poi_builder["names"], signal=name_in)
    f1 = dropdown(files; widget=poi_builder["start.file"], signal=f1_in)
    f2 = dropdown(files; widget=poi_builder["stop.file"], signal=f2_in)
    start_time = timewidget(Time(0); widget=poi_builder["start.time"], signal=start_time_in)
    stop_time = timewidget(Time(0); widget=poi_builder["stop.time"], signal=stop_time_in)
    start = map(t -> Dates.Second(t - Dates.Time(0,0,0)), start_time)
    stop = map(t -> Dates.Second(t - Dates.Time(0,0,0)), stop_time)
    poi_label = textarea(;widget=poi_builder["label"], signal=poi_label_in)
    poi_comment = textarea(;widget=poi_builder["comment"], signal=poi_comment_in)
    playstart = button(;widget=poi_builder["start.play"])
    playstop = button(;widget=poi_builder["stop.play"])
    done_poi = togglebutton(true, widget=poi_builder["done"])
    cancel_poi = button(widget=poi_builder["cancel"])
    # functions 
    tsksstrt, rsltsstrt = async_map(nothing, signal(playstart)) do _
        openit(joinpath(folder, value(f1)))
        return nothing
    end
    tsksstp, rsltsstp = async_map(nothing, signal(playstop)) do _
        openit(joinpath(folder, value(f2)))
        return nothing
    end
    start_point = map(Point, f1, start)
    stop_point = map(Point, f2, stop)
    foreach(start_point) do p
        if p.file == value(f2) && p.time > value(stop)
            push!(stop_time, Dates.Time(0,0,0) + p.time)
        end
    end
    foreach(stop_point) do p
        if p.file == value(f1) && p.time < value(start)
            push!(start_time, Dates.Time(0,0,0) + p.time)
        end
    end
    poi_temp = map(POI, name, start_point, stop_point, poi_label, poi_comment)

    poi_new = map(_ -> value(poi_temp), done_poi, init = value(poi_temp))
    poi_out = droprepeats(poi_new)

    foreach(cancel_poi) do _
        push!(poi_in, value(poi_out))
        push!(done_poi, true)
    end

    showall(poi_builder["window"])
    foreach(x -> visible(poi_builder["window"], !x), done_poi)

    bindmap!(signal(done_poi), !, signal(add_poi), !)

    return (poi_in, poi_out)
end

function wire_run_gui(folder, add_run)

    # prepare glade
    glade_widgets = OrderedDict{Symbol, Tuple{Symbol, String}}()
    drops = Dict{Symbol, Vector{String}}()
    tmp = readcsv(joinpath(folder, "metadata", "run.csv"))
    for i = 1:size(tmp,1)
        x = filter(!isempty, strip.(tmp[i,:]))
        l = x[1]
        id = Symbol(l)
        widget = length(x) == 1 ? :textbox : :dropdown
        glade_widgets[id] = (widget, l)
        if widget == :dropdown
            drops[id] = x[2:end]
        end
    end
    parse2glade(glade_widgets)
    run_builder = Builder(filename=joinpath(@__DIR__, "run.glade"))
    run_in = Signal(Run(Dict(k => haskey(drops, k) ? first(drops[k]) : "" for k in keys(glade_widgets)), ""))

    widgets = Dict{Symbol, Union{GtkReactive.Textarea, GtkReactive.Dropdown}}()
    for (id, (widget, _)) in glade_widgets
        if widget == :textbox
            widgets[id] = textarea(widget=run_builder[String(id)], signal = map(x -> x.metadata[id], run_in))
        else
            widgets[id] = dropdown(drops[id], widget=run_builder[String(id)], signal = map(x -> x.metadata[id], run_in))
        end
    end

    run_comment = textarea(widget=run_builder["comment.run.wJqRk"], signal = map(x -> x.comment, run_in))
    done_run = togglebutton(true, widget=run_builder["done.run.wJqRk"])
    cancel_run = button(widget=run_builder["cancel.run.wJqRk"])

    # function
    run_update = merge(map(signal, values(widgets))..., signal(run_comment))
    run_temp = map(_ -> Run(Dict(k => value(v) for (k,v) in widgets), value(run_comment)), run_update)

    new_run = map(_ -> value(run_temp), done_run, init = value(run_temp))

    counter = foldp(+, 1, signal(done_run))
    odd = map(isodd, counter)

    run_out = filterwhen(odd, value(new_run), new_run)

    foreach(cancel_run, init=nothing) do _
        r = value(run_out)
        for (k, v) in widgets
            push!(v, r.metadata[k])
        end
        push!(run_comment, r.comment)
        push!(done_run, true)
        a = value(association)
        delete!(a, last(a.runs))
        push!(association, a)
    end

    showall(run_builder["window.run.wJqRk"])
    foreach(x -> visible(run_builder["window.run.wJqRk"], !x), done_run)

    bindmap!(signal(done_run), !, signal(add_run), !)

    return (run_in, run_out)
end

function log_gui(folder)
    vfs = getVideoFiles(folder)
    # files = OrderedSet([vf.file for vf in vfs])
    # points = strip.(vec(readcsv(joinpath(folder, "metadata", "poi.csv"), String)))

    ##################################### LOG ######################################
    log_builder = Builder(filename=joinpath(@__DIR__, "log.glade"))

    # widgets
    add_poi = togglebutton(false, widget=log_builder["add.poi"])
    add_run = togglebutton(false, widget=log_builder["add.run"])
    clear = button(widget=log_builder["clear"])
    cancel = button(widget=log_builder["cancel"])
    done = button(widget=log_builder["done"])
    g = log_builder["poi.run.grid"]

    # functions
    foreach(x -> visible(log_builder["window"], !x), add_poi)
    foreach(x -> visible(log_builder["window"], !x), add_run)
    foreach(_ -> destroy(log_builder["window"]), cancel, init=nothing)

    showall(log_builder["window"])


    ##################################### POI ######################################

    poi_in, poi = wire_poi_gui(vfs, folder, add_poi)

    ##################################### RUN ######################################

    run_in, run = wire_run_gui(folder, add_run)

    ################################## ASSOCIATIONS ################################

    added = merge(poi, run)
    association = foldp(push!, loadAssociation(folder), added)

    merged_in = merge(poi_in, run_in)
    new_in = map(_ -> true, merged_in, init=false)
    replaceit = filterwhen(new_in, value(added), added)
    foreach(replaceit, init=nothing) do x
        a = value(association)
        replace!(a, value(merged_in), x)
        push!(new_in, false)
        push!(association, a)
    end

    assdone = map(association) do a
        empty!(g)
        g[0,0] = log_builder["poi.diagonal.run"]
        for (x, p) in enumerate(a.pois)
            file = MenuItem("_$(p.name) $(p.label)")
            filemenu = Menu(file)
            check_ = MenuItem("Check")
            checkh = signal_connect(check_, :activate) do _
                for r in a.runs
                    push!(a, (p, r))
                end
                push!(association, a)
            end
            push!(filemenu, check_)
            uncheck_ = MenuItem("Uncheck")
            uncheckh = signal_connect(uncheck_, :activate) do _
                for r in a.runs
                    delete!(a, (p, r))
                end
                push!(association, a)
            end
            push!(filemenu, uncheck_)
            #=hide_ = MenuItem("Hide")
            hideh = signal_connect(hide_, :activate) do _
                p.visible = false
                push!(association, a)
            end
            push!(filemenu, hide_)=#
            edit_ = MenuItem("Edit")
            edith = signal_connect(edit_, :activate) do _
                push!(add_poi, true)
                push!(poi_in, p)
                # foreach(add_poi, init=nothing) do _
                #=poi_ = poi_gui(p, points, files, folder)
                poi_new = droprepeats(poi_)
                foreach(poi_new, init = nothing) do n=#
                    # replace!(a, p, n)
                    # push!(association, a)
                    # nothing
                # end
            end
            push!(filemenu, edit_)
            push!(filemenu, SeparatorMenuItem())
            delete = MenuItem("Delete")
            deleteh = signal_connect(delete, :activate) do _
                delete!(a, p)
                push!(association, a)
            end
            push!(filemenu, delete)
            mb = MenuBar()
            push!(mb, file)
            g[x,0] = mb
        end
        g[length(a.pois) + 1,0] = togglebutton(false, widget=log_builder["add.poi"])
        for (y, r) in enumerate(a.runs)
            file = MenuItem(string("_", shorten(string(join(values(r.run.metadata), ":")..., ":", r.repetition), 30)))
            filemenu = Menu(file)
            check_ = MenuItem("Check")
            checkh = signal_connect(check_, :activate) do _
                for p in a.pois
                    push!(a, (p, r))
                end
                push!(association, a)
            end
            push!(filemenu, check_)
            uncheck_ = MenuItem("Uncheck")
            uncheckh = signal_connect(uncheck_, :activate) do _
                for p in a.pois
                    delete!(a, (p, r))
                end
                push!(association, a)
            end
            push!(filemenu, uncheck_)
            #=hide_ = MenuItem("Hide")
            hideh = signal_connect(hide_, :activate) do _
                r.visible = false
                push!(association, a)
            end
            push!(filemenu, hide_)=#
            edit_ = MenuItem("Edit")
            edith = signal_connect(edit_, :activate) do _
                push!(add_run, true)
                push!(run_in, r.run)
                #=run_ = run_gui(r.run, metadata)
                run_new = droprepeats(run_)
                foreach(run_new, init = nothing) do n
                    replace!(a, r, n)
                    push!(association, a)
                    nothing
                end=#
            end
            push!(filemenu, edit_)
            push!(filemenu, SeparatorMenuItem())
            delete = MenuItem("Delete")
            deleteh = signal_connect(delete, :activate) do _
                delete!(a, r)
                push!(association, a)
            end
            push!(filemenu, delete)
            mb = MenuBar()
            push!(mb, file)
            g[0,y] = mb
        end
        g[0, length(a.runs) + 1] = togglebutton(false, widget=log_builder["add.run"])
        for (x, p) in enumerate(a.pois), (y, r) in enumerate(a.runs)
            key = (p, r)
            cb = checkbox(key in a)
            foreach(cb) do tf
                tf ? push!(a, key) : delete!(a, key)
            end
            g[x,y] = cb
        end
        showall(log_builder["window"])
    end


    # clear the log window grid
    foreach(clear, init=nothing) do _
        a = value(association)
        empty!(a)
        push!(association, a)
        nothing
    end

    # done and move on to assesing the videos
    foreach(done, init=nothing) do _
        a = value(association)
        destroy(log_builder["window"])
        if !isempty(a) 
            save(folder, a)
            checkvideos(a, folder, vfs)
        end
        nothing
    end
end


function return_selected_videos(a::Association, vfs::OrderedSet{VideoFile})
    uvfs = Set{String}(vf for poi in a.pois for vf in [poi.start.file, poi.stop.file])
    ft = Dict{String, VideoFile}()
    for vf in vfs
        if vf.file in uvfs
            ft[vf.file] = vf
        end
    end
    return collect(values(ft))
end

function checkvideos(a::Association, folder::String, vfs::OrderedSet{VideoFile})
    builder = Builder(filename=joinpath(@__DIR__, "video.glade"))
    # data
    ft = return_selected_videos(a, vfs)
    n = length(ft)
    # widgets
    done = button(widget=builder["done"])
    previous = button(widget=builder["previous"])
    next = button(widget=builder["next"])
    play = button(widget=builder["play"])
    # functions
    state = Signal(1)
    small = map(x -> x < n, state)
    safenext = filterwhen(small, nothing, signal(next))
    foreach(safenext, init=nothing) do _
        push!(state, value(state) + 1)
        nothing
    end
    large = map(x -> x > 1, state)
    safeprevious = filterwhen(large, nothing, signal(previous))
    foreach(safeprevious, init=nothing) do _
        push!(state, value(state) - 1)
        nothing
    end
    file = map(state) do i
        ft[i].file
    end
    tsk, rslt = async_map(nothing, signal(play)) do _
        openit(joinpath(folder, value(file)))
        return nothing
    end
    datetime = map(state) do i
        ft[i].datetime
    end
    dt = datetimewidget(ft[1].datetime, widget=builder["datetime"], signal=datetime)
    label(ft[1].file, widget=builder["file.name"], signal=file)

    foreach(dt) do x
        i = value(state)
        ft[i] = VideoFile(ft[i].file, x)
    end
    foreach(done,  init = nothing) do _
        save(folder, OrderedSet{VideoFile}(ft))
        destroy(builder["window"])
    end
    showall(builder["window"])
end

