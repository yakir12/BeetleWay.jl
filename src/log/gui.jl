include(joinpath(@__DIR__, "associations.jl"))
include(joinpath(@__DIR__, "glade_maker.jl"))
include(joinpath(@__DIR__, "util.jl"))

function log_gui(folder)
    vfs = getVideoFiles(folder)
    files = OrderedSet([vf.file for vf in vfs])
    points = strip.(vec(readcsv(joinpath(folder, "metadata", "poi.csv"), String)))

    ##################################### LOG ######################################
    log_builder = Builder(filename=joinpath("/home/yakir/.julia/v0.6/BeetleWay/src/log/log.glade"))

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
    poi_builder = Builder(filename=joinpath("/home/yakir/.julia/v0.6/BeetleWay/src/log/poi.glade"))

    # widgets
    name = dropdown(points; widget=poi_builder["names"])
    f1 = dropdown(files; widget=poi_builder["start.file"])
    f2 = dropdown(files; widget=poi_builder["stop.file"])
    start_time = timewidget(Dates.Time(); widget=poi_builder["start.time"])
    stop_time = timewidget(Dates.Time(); widget=poi_builder["stop.time"])
    start = map(t -> Dates.Second(t - Dates.Time(0,0,0)), start_time)
    stop = map(t -> Dates.Second(t - Dates.Time(0,0,0)), stop_time)
    poi_label = textarea(;widget=poi_builder["label"])
    poi_comment = textarea(;widget=poi_builder["comment"])
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
    poi = droprepeats(poi_new)
    foreach(cancel_poi) do _
        p = value(poi)
        push!(name, p.name)
        push!(f1, p.start.file)
        push!(f2, p.stop.file)
        push!(start_time, Dates.Time(0,0,0) + p.start.time)
        push!(stop_time, Dates.Time(0,0,0) + p.stop.time)
        push!(poi_label, p.label)
        push!(poi_comment, p.comment)
        push!(done_poi, true)
    end

    showall(poi_builder["window"])
    foreach(x -> visible(poi_builder["window"], !x), done_poi)

    bind!(signal(done_poi), !, signal(add_poi), !)

    ##################################### RUN ######################################
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
    run_builder = Builder(filename=joinpath("/home/yakir/.julia/v0.6/BeetleWay/src/log/run.glade"))

    widgets = Dict{Symbol, Union{GtkReactive.Textarea, GtkReactive.Dropdown}}()
    for (id, (widget, _)) in glade_widgets
        if widget == :textbox
            widgets[id] = textarea(widget=run_builder[String(id)])
        else
            widgets[id] = dropdown(drops[id], widget=run_builder[String(id)])
        end
    end

    run_comment = textarea(widget=run_builder["comment.run.wJqRk"])
    done_run = togglebutton(true, widget=run_builder["done.run.wJqRk"])
    cancel_run = button(widget=run_builder["cancel.run.wJqRk"])

    # function
    run_update = merge(map(signal, values(widgets))..., signal(run_comment))
    run_temp = map(_ -> Run(Dict(k => value(v) for (k,v) in widgets), value(run_comment)), run_update)

    new_run = map(_ -> value(run_temp), done_run, init = value(run_temp))

    counter = foldp(+, 1, signal(done_run))
    odd = map(isodd, counter)

    run = filterwhen(odd, value(new_run), new_run)

    foreach(cancel_run, init=nothing) do _
        r = value(run)
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

    bind!(signal(done_run), !, signal(add_run), !)

    ################################## ASSOCIATIONS ################################

    added = merge(poi, run)
    association = foldp(push!, loadAssociation(folder), added)
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
                poi_ = poi_gui(p, points, files, folder)
                poi_new = droprepeats(poi_)
                foreach(poi_new, init = nothing) do n
                    replace!(a, p, n)
                    push!(association, a)
                    nothing
                end
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
                run_ = run_gui(r.run, metadata)
                run_new = droprepeats(run_)
                foreach(run_new, init = nothing) do n
                    replace!(a, r, n)
                    push!(association, a)
                    nothing
                end
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
    builder = Builder(filename=joinpath("/home/yakir/.julia/v0.6/BeetleWay/src/log/video.glade"))
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




#=
goodtimes = fill(Signal(true), length(ft))
for (i, (name, vf)) in enumerate(ft)
    play = button(vf.file)
    y = spinbutton(1:10000, value = Dates.Year(vf.datetime).value)
    m = spinbutton(1:12, value = Dates.Month(vf.datetime).value)
    d = spinbutton(1:31, value = Dates.Day(vf.datetime).value)
    H = spinbutton(0:23, value = Dates.Hour(vf.datetime).value)
    M = spinbutton(0:59, value = Dates.Minute(vf.datetime).value)
    S = spinbutton(0:59, value = Dates.Second(vf.datetime).value)
    #MS = spinbutton(0:999, value = Dates.Millisecond(vf.datetime).value)
    setproperty!(y.widget, :width_request, 5)
    setproperty!(m.widget, :width_request, 5)
    setproperty!(d.widget, :width_request, 5)
    setproperty!(H.widget, :width_request, 5)
    setproperty!(M.widget, :width_request, 5)
    setproperty!(S.widget, :width_request, 5)
    #setproperty!(MS.widget, :width_request, 5)
    g[0,i] = play.widget
    g[1,i] = y.widget
    g[2,i] = m.widget
    g[3,i] = d.widget
    g[4,i] = H.widget
    g[5,i] = M.widget
    g[6,i] = S.widget
    #g[7,i] = MS.widget
    dt = map(tuple, y, m, d, H, M, S)
    #dt = map(tuple, y, m, d, H, M, S, MS)
    time_is_good = map(x -> isnull(validargs(DateTime, x...)), dt) 
    goodtimes[i] = time_is_good
    goodtime = filterwhen(time_is_good, value(dt), dt)
    vf2 = map(goodtime) do x
        ft[name] = VideoFile(vf.file, DateTime(x...))
    end
    tasksplay, resultsplay = async_map(nothing, signal(play)) do _
        openit(joinpath(folder, vf.file))
    end
end

goodtime = map(&, goodtimes...)
clicked = filterwhen(goodtime, Void(), signal(done))
foreach(clicked,  init = nothing) do _
    save(folder, OrderedSet{VideoFile}(values(ft)))
    destroy(win)
end

g[0:6, length(ft) + 1] = widget(done)
#g[0:7, length(ft) + 1] = widget(done)
win = Window(g, "LogBeetle: Check videos", 1, 1)
showall(win)

=##==##=c = Condition()
signal_connect(win, :destroy) do _
    notify(c)
end
wait(c)=##==##=
end
=#


#=using HDF5

include(joinpath(Pkg.dir("BeetleWay"), "src", "log", "util.jl"))


=##=using Gtk.ShortNames, GtkReactive
builder = Builder(filename="tmp.glade")
x = dropdown(["q", "a"^100, "b"]; widget=builder["combobox"])
win = builder["window"]
showall(win)=##=





function poi_gui(o, points, files, folder)


end
#data
poi_builder = Builder(filename=joinpath(@__DIR__, "poi.glade"))

function build_poi_gui(points, files, folder)
    # widgets
    name = dropdown(points; widget=poi_builder["pois"])
    f1 = dropdown(files; widget=poi_builder["start.file"])
    f2 = dropdown(files; widget=poi_builder["stop.file"])
    # start = timewidget(Time(0,0,0) + o.start.time)
    # stop = timewidget(Time(0,0,0) + o.stop.time)
    label = textbox(;widget=poi_builder["label"])
    comment = textarea(;widget=poi_builder["comment"])

    playstart = button(;widget=poi_builder["start.play"])
    playstop = button(;widget=poi_builder["stop.play"])
    done = button(;widget=poi_builder["done"])
    # function 
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
        wrong_time = map(start_point, stop_point) do p1, p2 # true when the times are fucked
            p1.file == p2.file && p1.time > p2.time
        end
        correct_stop_time = filterwhen(wrong_time, value(start.signal), start.signal)
        bind!(stop.signal, correct_stop_time, false, initial=false)

        time_correct = map(!, wrong_time)
        p1 = filterwhen(time_correct, o.start, start_point)
        p2 = filterwhen(time_correct, o.stop, stop_point)
        poi_temp = map(POI, name, p1, p2, label, comment)

        poi_new = map(_ -> value(poi_temp), done, init = value(poi_temp))
        poi = filterwhen(time_correct, o, poi_new)

        visible(poi_builder["window"], false)
        showall(poi_builder["window"])
        return (name, f1, f2, label, comment, poi)
    end

    function push_poi(name, f1, f2, label, comment, poi)
        push!(name, poi.name)
        push!(f1, poi.f1)
        push!(f2, poi.f2)
        push!(label, poi.label)
        push!(comment, poi.comment)
        showall(poi_builder["window"])
        visible(log_builder["window"], false)
        visible(poi_builder["window"], true)

        c = Condition()
        foreach(poi, init = nothing) do _
            visible(poi_builder["window"], false)
            visible(run_builder["window"], true)
            notify(c)
        end
        wait(c)
    end

    return poi
end

function run_gui(o, metadata)

end

function log_gui(folder)
    # build the poi




    # build the main window
    log_builder = Builder(filename=joinpath(@__DIR__, "log.glade"))


    # run_builder = Builder(filename=joinpath(@__DIR__, "run.glade"))

    vfs = getVideoFiles(folder)

    # poi data
    files = shorten(OrderedSet([vf.file for vf in vfs]) ,30)
        points = strip.(vec(readcsv(joinpath(folder, "metadata", "poi.csv"), String)))

        # run data
        tmp = readcsv(joinpath(folder, "metadata", "run.csv"))
        metadata = Dict{String, Vector{String}}()
        for i = 1:size(tmp,1)
            b = strip.(tmp[i,:])
        metadata[b[1]] = filter(x -> !isempty(x), b[2:end])
    end

    g = builder["poi.run.grid"]
    addpoi = button(; widget=builder["add.poi"])
    addrun = button(; widget=builder["add.run"])
    poi_old_ = Signal(POI(points[1], Point(first(values(files)), Second(0)), Point(first(values(files)), Second(0)), "", ""))
    poi_old = map(poi_old_) do p
        p.start.file == p.stop.file ? POI(p.name, p.stop, Point(p.stop.file, 2p.stop.time - p.start.time), p.label, p.comment) : p 
    end

    poi_ = map(addpoi, init = poi_old) do _
        poi_gui(value(poi_old), points, files, folder)
    end
    poi__ = flatten(poi_)

    counterp = foldp((x, _) -> x + 1, 1, poi__)
    oddp = map(isodd, counterp)
    poi = filterwhen(oddp, value(poi__), poi__)

    bind!(poi_old_, poi, initial=false)

    run_old = Signal(Run(Dict(Symbol(k) => isempty(v) ? "" : v[1] for (k, v) in metadata), ""))
        run_ = map(addrun, init = run_old) do _
            run_gui(value(run_old), metadata)
        end
        run__ = flatten(run_)

        counter = foldp((x, _) -> x + 1, 1, run__)
        odd = map(isodd, counter)
        run = filterwhen(odd, value(run__), run__)

        bind!(run_old, run, initial=false)


        w = builder["head.window"]
        showall(w)
        added = merge(poi, run)
        association = foldp(push!, loadAssociation(folder), added)
        assdone = map(association) do a
            empty!(g)
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
                =##=hide_ = MenuItem("Hide")
                hideh = signal_connect(hide_, :activate) do _
                    p.visible = false
                    push!(association, a)
                end
                push!(filemenu, hide_)=##=
                edit_ = MenuItem("Edit")
                edith = signal_connect(edit_, :activate) do _
                    poi_ = poi_gui(p, points, files, folder)
                    poi_new = droprepeats(poi_)
                    foreach(poi_new, init = nothing) do n
                        replace!(a, p, n)
                        push!(association, a)
                        nothing
                    end
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
            g[length(a.pois) + 1,0] = widget(addpoi)
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
                =##=hide_ = MenuItem("Hide")
                hideh = signal_connect(hide_, :activate) do _
                    r.visible = false
                    push!(association, a)
                end
                push!(filemenu, hide_)=##=
                edit_ = MenuItem("Edit")
                edith = signal_connect(edit_, :activate) do _
                    run_ = run_gui(r.run, metadata)
                    run_new = droprepeats(run_)
                    foreach(run_new, init = nothing) do n
                        replace!(a, r, n)
                        push!(association, a)
                        nothing
                    end
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
            g[0, length(a.runs) + 1] = widget(addrun)
            for (x, p) in enumerate(a.pois), (y, r) in enumerate(a.runs)
                key = (p, r)
                cb = checkbox(key in a)
                foreach(cb) do tf
                    tf ? push!(a, key) : delete!(a, key)
                end
                g[x,y] = cb
            end
            saves = Button("Save")
            saveh = signal_connect(saves, :clicked) do _
                if isempty(a)
                    exit()
                end
                save(folder, a)
                destroy(w)
                checkvideos(a, folder, vfs)
            end
            clears = Button("Clear")
            clearh = signal_connect(clears, :clicked) do _
                empty!(a)
                push!(association, a)
            end
            quits = Button("Quit")
            quith = signal_connect(quits, :clicked) do _
                destroy(w)
                exit()
            end
            savequit = Box(:v)
            push!(savequit, saves, clears, quits)
            g[0,0] = savequit
            showall(w)
        end
        return true
    end


    function coordinates_gui(folder::String)
        w = Window("LogBeetle", 500,500)
        info_label = Label("")
        c = Condition()
        ok = button("OK")
        foreach(ok) do _
            notify(c)
        end
        b = Box(:v)
        push!(b, info_label, ok)
        s = ScrolledWindow(b)
        push!(w, s)
        a = loadAssociation(folder)
        for (i, p) in enumerate(a.pois)
            f5name = joinpath(folder, "log", "$i.h5")
            isfile(f5name) && continue
            r = String[]
            push!(r, """<b>POI</b> 
            Name: <i>$(p.name)</i>
            Label: <i>$(p.label)</i>
            Comment: <i>$(p.comment)</i>""")
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
            info = join(r, "\n")
            G_.markup(info_label, info)
            showall(w)
            wait(c)
            xyt = rand(10,3)
            h5open(f5name, "w") do o
                @write o xyt
            end
        end
        destroy(w)
    end
    =#
