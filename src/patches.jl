################# Gtk yield thing ########################
import Gtk.open_dialog

function open_dialog(title::AbstractString, parent = Gtk.GtkNullContainer(), filters::Union{AbstractVector, Tuple} = String[]; kwargs...)
    dlg = Gtk.GtkFileChooserDialog(title, parent, Gtk.GConstants.GtkFileChooserAction.OPEN,
                               (("_Cancel", Gtk.GConstants.GtkResponseType.CANCEL),
                                ("_Open",   Gtk.GConstants.GtkResponseType.ACCEPT)); kwargs...)
    dlgp = Gtk.GtkFileChooser(dlg)
    if !isempty(filters)
        makefilters!(dlgp, filters)
    end
    yield()
    response = run(dlg)
    multiple = getproperty(dlg, :select_multiple, Bool)
    local selection
    if response == Gtk.GConstants.GtkResponseType.ACCEPT
        if multiple
            filename_list = ccall((:gtk_file_chooser_get_filenames, libgtk), Ptr{Gtk._GSList{String}}, (Ptr{GObject},), dlgp)
            selection = String[f for f in Gtk.GList(filename_list, transfer-fulltrue)]
        else
            selection = Gtk.bytestring(Gtk.GAccessor.filename(dlgp))
        end
    else
        if multiple
            selection = String[]
        else
            selection = Gtk.GLib.utf8("")
        end
    end
    destroy(dlg)
    return selection
end




################# GtkReactive time widgets ###############
import GtkReactive: timewidget, InputWidget

immutable TimeWidget2{T <: Dates.TimeType} <: InputWidget{T}
    signal::Signal{T}
    widget::Gtk.GtkFrame
end

"""
    timewidget(time)

Return a time widget that includes the `Time` and a `GtkFrame` with the hour, minute, and
second widgets in it. You can specify the specific `GtkFrame` widget (useful when using the `Gtk.Builder` and `glade`). Time is guaranteed to be positive. 
"""
function timewidget(t1::Dates.Time; widget=nothing, signal=nothing)
    const zerotime = Dates.Time(0,0,0)
    b = Gtk.GtkBuilder(filename=joinpath(@__DIR__, "time.glade"))
    if signal == nothing
        signal = Signal(t1)
    end
    S = map(signal) do x
        (Dates.Second(x), x)
    end
    M = map(S) do x
        x = last(x)
        (Dates.Minute(x), x)
    end
    H = map(M) do x
        x = last(x)
        (Dates.Hour(x), x)
    end
    t2 = map(last, H)
    bind!(signal, t2)
    Sint = Signal(Dates.value(first(value(S))))
    Ssb = spinbutton(-1:60, widget=b["second"], signal=Sint)
    foreach(Sint) do x
        Δ = Dates.Second(x) - first(value(S))
        new_t = value(signal) + Δ
        new_t = new_t < zerotime ? zerotime : new_t
        new_x = Dates.Second(new_t)
        push!(S, (new_x, new_t))
    end
    Sint2 = map(src -> Dates.value(Dates.Second(src)), t2)
    Sint3 = droprepeats(Sint2)
    bind!(Sint, Sint3, false)
    Mint = Signal(Dates.value(first(value(M))))
    Msb = spinbutton(-1:60, widget=b["minute"], signal=Mint)
    foreach(Mint) do x
        Δ = Dates.Minute(x) - first(value(M))
        new_t = value(signal) + Δ
        new_t = new_t < zerotime ? zerotime : new_t
        new_x = Dates.Minute(new_t)
        push!(M, (new_x, new_t))
    end
    Mint2 = map(src -> Dates.value(Dates.Minute(src)), t2)
    Mint3 = droprepeats(Mint2)
    bind!(Mint, Mint3, false)
    Hint = Signal(Dates.value(first(value(H))))
    Hsb = spinbutton(0:23, widget=b["hour"], signal=Hint)
    foreach(Hint) do x
        Δ = Dates.Hour(x) - first(value(H))
        new_t = value(signal) + Δ
        new_t = new_t < zerotime ? zerotime : new_t
        new_x = Dates.Hour(new_t)
        push!(H, (new_x, new_t))
    end
    Hint2 = map(src -> Dates.value(Dates.Hour(src)), t2)
    Hint3 = droprepeats(Hint2)
    bind!(Hint, Hint3, false)

    if widget == nothing
        return TimeWidget2(signal, b["frame"])
    else
        push!(widget, b["frame"])
        return TimeWidget2(signal, widget)
    end
end

"""
    datetimewidget(datetime)

Return a datetime widget that includes the `DateTime` and a `GtkBox` with the
year, month, day, hour, minute, and second widgets in it. You can specify the
specific `SpinButton` widgets for the hour, minute, and second (useful when using
`Gtk.Builder` and `glade`). Date and time are guaranteed to be positive. 
"""
function datetimewidget(t1::DateTime; widget=nothing, signal=nothing)
    const zerotime = DateTime(0,1,1,0,0,0)
    b = Gtk.GtkBuilder(filename=joinpath(@__DIR__, "datetime.glade"))
    # t1 = eps(t0) < Dates.Second(1) ? round(t0, Dates.Second(1)) : t0
    if signal == nothing
        signal = Signal(t1)
    end
    S = map(signal) do x
        (Dates.Second(x), x)
    end
    M = map(S) do x
        x = last(x)
        (Dates.Minute(x), x)
    end
    H = map(M) do x
        x = last(x)
        (Dates.Hour(x), x)
    end
    d = map(H) do x
        x = last(x)
        (Dates.Day(x), x)
    end
    m = map(d) do x
        x = last(x)
        (Dates.Month(x), x)
    end
    y = map(m) do x
        x = last(x)
        (Dates.Year(x), x)
    end
    t2 = map(last, y)
    bind!(signal, t2)
    Sint = Signal(Dates.value(first(value(S))))
    Ssb = spinbutton(-1:60, widget=b["second"], signal=Sint)
    foreach(Sint) do x
        Δ = Dates.Second(x) - first(value(S))
        new_t = value(signal) + Δ
        new_t = new_t < zerotime ? zerotime : new_t
        new_x = Dates.Second(new_t)
        push!(S, (new_x, new_t))
    end
    Sint2 = map(src -> Dates.value(Dates.Second(src)), t2)
    Sint3 = droprepeats(Sint2)
    bind!(Sint, Sint3, false)
    Mint = Signal(Dates.value(first(value(M))))
    Msb = spinbutton(-1:60, widget=b["minute"], signal=Mint)
    foreach(Mint) do x
        Δ = Dates.Minute(x) - first(value(M))
        new_t = value(signal) + Δ
        new_t = new_t < zerotime ? zerotime : new_t
        new_x = Dates.Minute(new_t)
        push!(M, (new_x, new_t))
    end
    Mint2 = map(src -> Dates.value(Dates.Minute(src)), t2)
    Mint3 = droprepeats(Mint2)
    bind!(Mint, Mint3, false)
    Hint = Signal(Dates.value(first(value(H))))
    Hsb = spinbutton(-1:24, widget=b["hour"], signal=Hint)
    foreach(Hint) do x
        Δ = Dates.Hour(x) - first(value(H))
        new_t = value(signal) + Δ
        new_t = new_t < zerotime ? zerotime : new_t
        new_x = Dates.Hour(new_t)
        push!(H, (new_x, new_t))
    end
    Hint2 = map(src -> Dates.value(Dates.Hour(src)), t2)
    Hint3 = droprepeats(Hint2)
    bind!(Hint, Hint3, false)
    dint = Signal(Dates.value(first(value(d))))
    dsb = spinbutton(-1:32, widget=b["day"], signal=dint)
    foreach(dint) do x
        Δ = Dates.Day(x) - first(value(d))
        new_t = value(signal) + Δ
        new_t = new_t < zerotime ? zerotime : new_t
        new_x = Dates.Day(new_t)
        push!(d, (new_x, new_t))
    end
    dint2 = map(src -> Dates.value(Dates.Day(src)), t2)
    dint3 = droprepeats(dint2)
    bind!(dint, dint3, false)
    mint = Signal(Dates.value(first(value(m))))
    msb = spinbutton(-1:13, widget=b["month"], signal=mint)
    foreach(mint) do x
        Δ = Dates.Month(x) - first(value(m))
        new_t = value(signal) + Δ
        new_t = new_t < zerotime ? zerotime : new_t
        new_x = Dates.Month(new_t)
        push!(m, (new_x, new_t))
    end
    mint2 = map(src -> Dates.value(Dates.Month(src)), t2)
    mint3 = droprepeats(mint2)
    bind!(mint, mint3, false)
    yint = Signal(Dates.value(first(value(y))))
    ysb = spinbutton(-1:10000, widget=b["year"], signal=yint)
    foreach(yint) do x
        Δ = Dates.Year(x) - first(value(y))
        new_t = value(signal) + Δ
        new_t = new_t < zerotime ? zerotime : new_t
        new_x = Dates.Year(new_t)
        push!(y, (new_x, new_t))
    end
    yint2 = map(src -> Dates.value(Dates.Year(src)), t2)
    yint3 = droprepeats(yint2)
    bind!(yint, yint3, false)

    if widget == nothing
        return TimeWidget2(signal, b["frame"])
    else
        push!(widget, b["frame"])
        return TimeWidget2(signal, widget)
    end
end


######################## ProgressBar #############################

immutable ProgressBar <: GtkReactive.Widget
    signal::Signal{Int}
    widget::Gtk.GtkProgressBar
    preserved::Vector{Any}

    function (::Type{ProgressBar})(signal::Signal{Int}, widget, preserved)
        obj = new(signal, widget, preserved)
        GtkReactive.gc_preserve(widget, obj)
        obj
    end
end

"""
    progressbar(n; widget=nothing, signal=nothing)

Create a progressbar displaying the progress of a process; push to the widget new
iteration integers to update the progressbar. Optionally specify:
  - the GtkProgressBar `widget` (by default, creates a new one)
  - the (Reactive.jl) `signal` coupled to this progressbar (by default, creates a new signal)
"""
function progressbar(n::Int;
               widget=nothing,
               signal=nothing,
               syncsig=true,
               own=nothing)
    signalin = signal
    signal, value = GtkReactive.init_wsigval(Int, signal, GtkReactive.value(signal))
    if own == nothing
        own = signal != signalin
    end
    if widget == nothing
        widget = Gtk.GtkProgressBar()
    else
        setproperty!(widget, :fraction, value)
    end
    preserved = []
    if syncsig
        push!(preserved, map(signal) do val
            setproperty!(widget, :fraction, val/n)
        end)
    end
    if own
        Gtk.ondestroy(widget, preserved)
    end
    ProgressBar(signal, widget, preserved)
end


