good_time(p1::Tuple{String, Time}, p2::Tuple{String, Time}) = first(p1) ≠ first(p2) || last(p1) ≤ last(p2)
############################ Run ###############################################
#=function poi_menu(g::GridLeaf, x::Tuple{String, String, Time, String, Time, String, String}, column::Int, nrows::Int)
    file = MenuItem(make_poi_label(x[1], x[6]))
    filemenu = Menu(file)
    check_ = MenuItem("Check")
    checkh = signal_connect(check_, :activate) do _
        for i = 1:nrows
            # push!(g[column,i], true)
            setproperty!(g[column,i], :active, true)
        end
    end
    push!(filemenu, check_)
    mb = MenuBar()
    push!(mb, file)
    return mb
end
function push!(g::GridLeaf, a::Association, x::Tuple{String, String, Time, String, Time, String, String})
    p = POI(a.md, x...)
    if p ∉ a
        push!(a, p)
        column = length(a.pois)
        for (i, r) in enumerate(a.repetitions)
            cb = checkbox(false)
            foreach(x -> x ? push!(a, p=>r) : delete!(a, p=>r), cb)
            g[column, i] = widget(cb)
        end
        g[column,0] = poi_menu(g, x, column, length(a.repetitions))
        showall(g)
    end
end=#
function wire_poi_gui(md)
    # signals
    poi_in = Signal(POI(md))
    nameⁱ = map(x -> md.poi_names[x.name], poi_in)
    labelⁱ = map(x -> x.label, poi_in)
    f1ⁱ = map(x -> md.files[x.start.file], poi_in)
    start_timeⁱ = map(x -> Time(0) + x.start.time, poi_in)
    f2ⁱ = map(x -> md.files[x.stop.file], poi_in)
    stop_timeⁱ = map(x -> Time(0) + x.stop.time, poi_in)
    commentⁱ = map(x -> x.comment, poi_in)
    # widgets
    name = dropdown(md.poi_names; widget=poi_builder["names"], signal=nameⁱ)
    poi_label = textarea("";widget=poi_builder["label"], signal=labelⁱ)
    f1 = dropdown(md.files; widget=poi_builder["start.file"], signal=f1ⁱ)
    start_time = timewidget(Time(); widget=poi_builder["start.time"], signal=start_timeⁱ)
    f2 = dropdown(md.files; widget=poi_builder["stop.file"], signal=f2ⁱ)
    stop_time = timewidget(Time(); widget=poi_builder["stop.time"], signal=stop_timeⁱ)
    poi_comment = textarea("";widget=poi_builder["comment"], signal=commentⁱ)

    playstart = button(;widget=poi_builder["start.play"])
    playstop = button(;widget=poi_builder["stop.play"])
    add_poi = button(widget=poi_builder["add"])
    cancel_poi = button(widget=poi_builder["cancel"])

    # functions 
    foreach(playstart, init=nothing) do _
        @spawn openit(joinpath(md.folder, value(f1)))
        return nothing
    end
    foreach(playstop, init=nothing) do _
        @spawn openit(joinpath(md.folder, value(f2)))
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
    poi_temp = map(tuple, name, poi_label, f1, start_time, f2, stop_time, poi_comment)
    _poi_out = map(_ -> value(poi_temp), add_poi, init = value(poi_temp))
    poi_out = map(x -> POI(md, x...), _poi_out)
    foreach(poi_out, init=nothing) do _
        push!(poi_vis, false)
        push!(log_vis, true)
        nothing
    end
    foreach(cancel_poi, init=nothing) do _
        push!(poi_in, value(poi_out))
        push!(poi_vis, false)
        push!(log_vis, true)
        nothing
    end
    return (poi_in, poi_out)
end
############################ Run ###############################################
#=function run_menu(g::GridLeaf, x::Tuple{Vector{String}, String}, row::Int, ncols::Int)
    file = MenuItem(join(x[1],':'))
    filemenu = Menu(file)
    check_ = MenuItem("Check")
    checkh = signal_connect(check_, :activate) do _
        for i = 1:ncols
            # push!(g[i, row], true)
            setproperty!(g[i,row], :active, true)
        end
    end
    push!(filemenu, check_)
    mb = MenuBar()
    push!(mb, file)
    return mb
end
function push!(g::GridLeaf, a::Association, x::Tuple{Vector{String}, String})
    run = Run(a.md, x...)
    push!(a, run)
r = a.repetitions[end]
row = length(a.repetitions)
for (i, p) in enumerate(a.pois)
    cb = checkbox(false)
    foreach(x -> x ? push!(a, p=>r) : delete!(a, p=>r), cb)
    g[i,row] = widget(cb)
end
g[0,row] = run_menu(g, x, row, length(a.pois))
showall(g)
end=#
function wire_run_gui(md::Metadata)

    # prepare glade
    run_in = Signal(Repetition(Run(md),1))

    widgets = Union{GtkReactive.Textarea, GtkReactive.Dropdown}[]
    for (i, (f, l)) in enumerate(zip(last.(glade_widgets), md.levels))
        if l isa SetLevels
            s = map(x -> l.data[x.run.setup[i]], run_in)
            push!(widgets, dropdown(l.data, widget=run_builder[f], signal = s))
        else
            s = map(x -> l.data[x.run.setup[i]], run_in)
            push!(widgets, textarea(value(s), widget=run_builder[f], signal = s))
        end
    end
    run_setup = map(widgets...) do x...
        [x...]
    end
    run_comment = textarea(widget=run_builder["comment.run.wJqRk"], signal = map(x -> x.run.comment, run_in))
    done_run = button(widget=run_builder["done.run.wJqRk"])
    cancel_run = button(widget=run_builder["cancel.run.wJqRk"])
    # showall(run_builder["window.run.wJqRk"])
    # visible(run_builder["window.run.wJqRk"], false)

    # function
    run_temp = map(tuple, run_setup, run_comment)

    _run_out = map(_ -> value(run_temp), done_run, init = value(run_temp))
    run_out = map(x -> Run(md, x...), _run_out)

    #=counter = foldp(+, 1, signal(done_run))
    odd = map(isodd, counter)

    run_out = filterwhen(odd, value(new_run), new_run)=#

    foreach(run_out, init=nothing) do _
        push!(run_vis, false)
        push!(log_vis, true)
        nothing
    end
    foreach(cancel_run, init=nothing) do _
        push!(run_in, Repetition(value(run_out),1))
        push!(run_vis, false)
        push!(log_vis, true)
        nothing
    end
    return (run_in, run_out)
end

##################################### LOG ######################################

# widgets
add_poi_id = button(widget=log_builder["add.poi"])
foreach(add_poi_id, init=nothing) do _
    push!(log_vis, false)
    push!(poi_vis, true)
    nothing
end
add_run_id = button(widget=log_builder["add.run"])
foreach(add_run_id, init=nothing) do _
    push!(log_vis, false)
    push!(run_vis, true)
    nothing
end
log_grid = log_builder["poi.run.grid"]

#=for (column, p) in enumerate(association.pois)
    log_grid[column+2,1] = label(metadata.poi_names[p.name])
end
showall(log_grid)=#

# functions

##################### POI ########################
poi_in, poi_out = wire_poi_gui(metadata)
# foreach(poi_out, init=nothing) do x
#     push!(log_grid, association, x)
#     nothing
# end

run_in, run_out = wire_run_gui(metadata)
# foreach(run_out, init=nothing) do x
#     push!(log_grid, value(association), x)
#     nothing
# end


edit_it_poi = Signal(false)
not_edit_poi = map(!, edit_it_poi)
poi_out2 = filterwhen(not_edit_poi, value(poi_out), poi_out)
edit_it_run = Signal(false)
not_edit_run = map(!, edit_it_run)
run_out2 = filterwhen(not_edit_run, value(run_out), run_out)

pr = merge(poi_out2, run_out2)
associationᵗ = foldp(push!, association, pr)

edited_poi = filterwhen(edit_it_poi, value(poi_out), poi_out)
foreach(edited_poi, init=nothing) do new_poi
    push!(edit_it_poi, false)
    a = value(associationᵗ)
    replace!(a, value(poi_in), new_poi)
    push!(associationᵗ, a)
    nothing
end

edited_run = filterwhen(edit_it_run, value(run_out), run_out)
foreach(edited_run, init=nothing) do new_run
    push!(edit_it_run, false)
    a = value(associationᵗ)
    replace!(a, value(run_in), new_run)
    push!(associationᵗ, a)
    nothing
end

foreach(associationᵗ) do a
    empty!(log_grid)
    for (x, p) in enumerate(a.pois)
        file = MenuItem(make_label(metadata, p))
        filemenu = Menu(file)
        check_ = MenuItem("Check")
        checkh = signal_connect(check_, :activate) do _
            check!(a, p)
            push!(associationᵗ, a)
        end
        push!(filemenu, check_)
        uncheck_ = MenuItem("Uncheck")
        uncheckh = signal_connect(uncheck_, :activate) do _
            uncheck!(a, p)
            push!(associationᵗ, a)
        end
        push!(filemenu, uncheck_)
        edit_ = MenuItem("Edit")
        edith = signal_connect(edit_, :activate) do _
            push!(poi_in, p)
            push!(log_vis, false)
            push!(poi_vis, true)
            push!(edit_it_poi, true)
        end
        push!(filemenu, edit_)
        push!(filemenu, SeparatorMenuItem())
        delete = MenuItem("Delete")
        deleteh = signal_connect(delete, :activate) do _
            delete!(a, p)
            push!(associationᵗ, a)
        end
        push!(filemenu, delete)
        mb = MenuBar()
        push!(mb, file)
        log_grid[x,0] = mb
    end
    # log_grid[length(a.pois) + 1,0] = togglebutton(false, widget=log_builder["add.poi"])
    for (y, r) in enumerate(a.repetitions)
        file = MenuItem(make_label(metadata, r))
        filemenu = Menu(file)
        check_ = MenuItem("Check")
        checkh = signal_connect(check_, :activate) do _
            check!(a, r)
            push!(associationᵗ, a)
        end
        push!(filemenu, check_)
        uncheck_ = MenuItem("Uncheck")
        uncheckh = signal_connect(uncheck_, :activate) do _
            uncheck!(a, r)
            push!(associationᵗ, a)
        end
        push!(filemenu, uncheck_)
        edit_ = MenuItem("Edit")
        edith = signal_connect(edit_, :activate) do _
            push!(run_in, r)
            push!(log_vis, false)
            push!(run_vis, true)
            push!(edit_it_run, true)
        end
        push!(filemenu, edit_)
        push!(filemenu, SeparatorMenuItem())
        delete = MenuItem("Delete")
        deleteh = signal_connect(delete, :activate) do _
            delete!(a, r)
            push!(associationᵗ, a)
        end
        push!(filemenu, delete)
        mb = MenuBar()
        push!(mb, file)
        log_grid[0,y] = mb
    end
    # log_grid[0, length(a.repetitions) + 1] = togglebutton(false, widget=log_builder["add.run"])
    for (x, p) in enumerate(a.pois), (y, r) in enumerate(a.repetitions)
        key = p=>r
        cb = checkbox(key ∈ a)
        foreach(cb) do tf
            tf ? push!(a, key) : delete!(a, key)
        end
        log_grid[x,y] = cb
    end
    showall(log_builder["window"])
end

push!(log_vis, false)

save_id = signal_connect(log_builder["save"], :activate) do _
    save(value(associationᵗ))
end
save_close_id = signal_connect(log_builder["save.close"], :activate) do _
    save(value(associationᵗ))
    push!(log_vis, false)
    push!(head_vis, true)
end
close_id = signal_connect(log_builder["close"], :activate) do _
    push!(log_vis, false)
    push!(head_vis, true)
end
clear_id = signal_connect(log_builder["clear.poi"], :activate) do _
    a = value(associationᵗ)
    while length(a.pois) ≠ 0
        p = a.pois[end]
        delete!(a, p)
    end
    push!(associationᵗ, a)
end
clear_id = signal_connect(log_builder["clear.run"], :activate) do _
    a = value(associationᵗ)
    while length(a.repetitions) ≠ 0
        r = a.repetitions[end]
        delete!(a, r)
    end
    push!(associationᵗ, a)
end
clear_id = signal_connect(log_builder["clear"], :activate) do _
    a = value(associationᵗ)
    empty!(a)
    push!(associationᵗ, a)
end
