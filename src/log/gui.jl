include(joinpath(log_dir, "glade_maker.jl"))

good_time(p1::Tuple{String, Time}, p2::Tuple{String, Time}) = first(p1) ≠ first(p2) || last(p1) ≤ last(p2)

function wire_poi_gui(md::Metadata, add_poi)
    #=poi_in = Signal(POI(md))
    name_in = map(x -> md.poi_names[x.name], poi_in)
    f1_in = map(x -> md.files[x.start.file], poi_in)
    f2_in = map(x -> md.files[x.stop.file], poi_in)
    start_time_in = map(x -> Time(0) + x.start.time, poi_in)
    stop_time_in = map(x -> Time(0) + x.stop.time, poi_in)
    poi_label_in = map(x -> x.label, poi_in)
    poi_comment_in = map(x -> x.comment, poi_in)=#


    return (poi_in, poi_out)
end

function wire_run_gui(md::Metadata, add_run)

    # prepare glade
    run_in = Signal(Run(md))
    run_builder = Builder(filename=joinpath(log_dir, "run.glade"))
    glade_widgets = [typeof(l) => replace(f, ' ', '_') for (l,f) in zip(md.levels, md.factors)]
    parse2glade(glade_widgets)

    widgets = Union{GtkReactive.Textarea, GtkReactive.Dropdown}[]
    for (i, (f, l)) in enumerate(zip(last.(glade_widgets), md.levels))
        if l isa SetLevels
            s = map(x -> l.data[x.setup[i]], run_in)
            push!(widgets, dropdown(l.data, widget=run_builder[f], signal = s))
        else
            s = map(x -> l.data[x.setup[i]], run_in)
            push!(widgets, textarea(value(s), widget=run_builder[f], signal = s))
        end
    end
    run_setup = map(widgets...) do x...
        [x...]
    end
    run_comment = textarea(widget=run_builder["comment.run.wJqRk"], signal = map(x -> x.comment, run_in))
    done_run = togglebutton(true, widget=run_builder["done.run.wJqRk"])
    cancel_run = button(widget=run_builder["cancel.run.wJqRk"])

    # function
    run_temp = map(run_setup, run_comment) do s, c
        Run(md, s, c)
    end

    new_run = map(_ -> value(run_temp), done_run, init = value(run_temp))

    counter = foldp(+, 1, signal(done_run))
    odd = map(isodd, counter)

    run_out = filterwhen(odd, value(new_run), new_run)

    foreach(cancel_run, init=nothing) do _
        r = value(run_out)
        for (i,w) in enumerate(widgets)
            push!(w, r.setup[i])
        end
        push!(run_comment, r.comment)
        push!(done_run, true)
        nothing
        #=a = value(association)
        delete!(a, last(a.runs))
        push!(association, a)=#
    end

    showall(run_builder["window.run.wJqRk"])
    foreach(x -> visible(run_builder["window.run.wJqRk"], !x), done_run)

    bindmap!(signal(done_run), !, signal(add_run), !)

    return (run_in, run_out)
end


function log_gui(folder, start_log)

    a = Association(folder)
    md = a.md

    ##################################### LOG ######################################
    log_builder = Builder(filename=joinpath(log_dir, "log.glade"))

    # widgets
    add_poi = button(widget=log_builder["add.poi"])
    add_run = togglebutton(false, widget=log_builder["add.run"])
    clear = button(widget=log_builder["clear"])
    cancel = button(widget=log_builder["cancel"])
    done = togglebutton(true,widget=log_builder["done"])
    g = log_builder["poi.run.grid"]

    # functions
    foreach(x -> visible(log_builder["window"], !x), add_poi)
    foreach(x -> visible(log_builder["window"], !x), add_run)
    foreach(_ -> destroy(log_builder["window"]), cancel, init=nothing)

    showall(log_builder["window"])

    foreach(x -> visible(log_builder["window"], !x), done)
    bindmap!(signal(done), !, signal(start_log), !)

    g[0,0] = log_builder["poi.diagonal.run"]


    ##################################### POI ######################################

    poi_in = Signal((md.poi_names[1], md.files[1], Time(), md.files[1], Time(), "", ""))
    nameⁱ = map(x -> x[1], poi_in)
    f1ⁱ = map(x -> x[2], poi_in)
    start_timeⁱ = map(x -> x[3], poi_in)
    f2ⁱ = map(x -> x[4], poi_in)
    stop_timeⁱ = map(x -> x[5], poi_in)
    labelⁱ = map(x -> x[6], poi_in)
    commentⁱ = map(x -> x[7], poi_in)
    poi_builder = Builder(filename=joinpath(log_dir, "poi.glade"))
    # widgets
    name = dropdown(md.poi_names; widget=poi_builder["names"], signal=nameⁱ)
    f1 = dropdown(md.files; widget=poi_builder["start.file"], signal=f1ⁱ)
    start_time = timewidget(Time(); widget=poi_builder["start.time"], signal=start_timeⁱ)
    f2 = dropdown(md.files; widget=poi_builder["stop.file"], signal=f2ⁱ)
    stop_time = timewidget(Time(); widget=poi_builder["stop.time"], signal=stop_timeⁱ)
    poi_label = textarea("";widget=poi_builder["label"], signal=labelⁱ)
    poi_comment = textarea("";widget=poi_builder["comment"], signal=commentⁱ)


    playstart = button(;widget=poi_builder["start.play"])
    playstop = button(;widget=poi_builder["stop.play"])
    done_poi = togglebutton(true, widget=poi_builder["done"])
    cancel_poi = button(widget=poi_builder["cancel"])

    # functions 
    foreach(playstart, init=nothing) do _
        @spawn openit(joinpath(folder, value(f1)))
        return nothing
    end
    foreach(playstop, init=nothing) do _
        @spawn openit(joinpath(folder, value(f2)))
        return nothing
    end
    #=tsksstrt, rsltsstrt = async_map(nothing, signal(playstart)) do _
        openit(joinpath(folder, value(f1)))
        return nothing
    end
    tsksstp, rsltsstp = async_map(nothing, signal(playstop)) do _
        openit(joinpath(folder, value(f2)))
        return nothing
    end=#

    start_point = map(tuple, f1, start_time)
    stop_point = map(tuple, f2, stop_time)
    foreach(start_point) do p
        if !good_time(p, value(stop_point))
            push!(stop_time, last(p))
        end
    end
    foreach(stop_point) do p
        if !good_time(value(start_point), p)
            push!(start_time, last(p))
        end
    end
    poi_temp = map(tuple, name, f1, start_time, f2, stop_time, poi_label, poi_comment)

    foreach(done_poi, init=nothing) do _
        name, f1, start_time, f2, stop_time, poi_label, poi_comment = value(poi_temp)
        p1 = Point(a.md, f1, Second(start_time - Time(0)))
        p2 = Point(a.md, f2, Second(stop_time - Time(0)))
        poi = POI(a.md, name, p1, p2, poi_label, poi_comment)
        push!(a, poi)
        push!(poi_visibility, false)

            file = MenuItem("_$name $poi_label")
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
            edit_ = MenuItem("Edit")
            edith = signal_connect(edit_, :activate) do _
                push!(add_poi, true)
                push!(poi_in, p)
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

        nothing
    end

    # poi_out = map(_ -> value(poi_temp), done_poi, init = value(poi_temp))

    showall(poi_builder["window"])

    poi_vis = Signal(false)

    foreach(x -> visible(poi_builder["window"], x), poi_vis)

    bindmap!(signal(poi_vis), !, signal(log_vis), !)

    pressed_cancel = map(cancel_poi, init=nothing) do _
        push!(poi_in, value(poi_out))
        push!(poi_visibility, false)
        nothing
    end

    #=poi_in, poi_out = wire_poi_gui(a.md, add_poi)
    poi = map(poi_out) do x
        name, f1, start_time, f2, stop_time, poi_label, poi_comment = x
        p1 = Point(a.md, f1, Second(start_time - Time(0)))
        p2 = Point(a.md, f2, Second(stop_time - Time(0)))
        POI(a.md, name, p1, p2, poi_label, poi_comment)
    end=#


    ##################################### RUN ######################################

    run_in, run = wire_run_gui(a.md, add_run)

    ################################## ASSOCIATIONS ################################

    added = merge(poi, run)

    

    # association = foldp(push!, a, added)

    #=merged_in = merge(poi_in, run_in)
    new_in = map(_ -> true, merged_in, init=false)
    replaceit = filterwhen(new_in, value(added), added)
    foreach(replaceit, init=nothing) do x
        a = value(association)
        replace!(a, value(merged_in), x)
        push!(new_in, false)
        push!(association, a)
    end=#

    #=assdone = map(association) do a
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
            edit_ = MenuItem("Edit")
            edith = signal_connect(edit_, :activate) do _
                push!(add_poi, true)
                push!(poi_in, p)
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
                edit_ = MenuItem("Edit")
                edith = signal_connect(edit_, :activate) do _
                    push!(add_run, true)
                    push!(run_in, r.run)
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
    end=#


    #=function return_selected_videos(a::Association, vfs::OrderedSet{VideoFile})
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
                builder = Builder(filename=joinpath(log_dir, "video.glade"))
                # data
                ft = return_selected_videos(a, vfs)
                n = length(ft)
                # widgets
                done = button(widget=builder["done"])
                previous = button(widget=builder["previous"])
                next = button(widget=builder["next"])
                play = button(widget=builder["play"])
                # functions
                down = map(_ -> -1, previous)
                up = map(_ -> +1, next)
                step = merge(down, up)
                _state = foldp(1, step) do x,y
                    clamp(x + y, 1, n)
                end
                state = droprepeats(_state)
                pb = progressbar(n, widget=builder["progressbar"], signal=state)
                file = map(state) do i
                    ft[i].file
                end
                foreach(play, init=nothing) do _
                    @spawn openit(joinpath(folder, value(file)))
                    nothing
                end
                =##==##=tsk, rslt = async_map(nothing, signal(play)) do _
                    openit(joinpath(folder, value(file)))
                    return nothing
                end=##==##=
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
            end=#
