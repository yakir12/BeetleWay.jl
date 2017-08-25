using DataStructures, AutoHashEquals, Base.Dates, Unitful, UnitfulAngles

import Base: push!, empty!, delete!, isempty, ==, in, show

export  VideoFile, Point, POI, Run, Repetition, Association, 
        replace!, findVideoFiles, getVideoFiles, save,
        loadLogVideoFiles, loadPOIs, loadRuns, loadAssociation

const exiftool_base = joinpath(Pkg.dir("BeetleWay"), "deps", "src", "exiftool", "exiftool")
const exiftool = exiftool_base*(is_windows() ? ".exe" : "")
const exts = [".webm", ".mkv", ".flv", ".flv", ".vob", ".ogv", ".ogg", ".drc", ".mng", ".avi", ".mov", ".qt", ".wmv", ".yuv", ".rm", ".rmvb", ".asf", ".amv", ".mp4", ".m4p", ".m4v", ".mpg", ".mp2", ".mpeg", ".mpe", ".mpv", ".mpg", ".mpeg", ".m2v", ".m4v", ".svi", ".3gp", ".3g2", ".mxf", ".roq", ".nsv", ".flv", ".f4v", ".f4p", ".f4a", ".f4b", ".MTS", ".DS_Store"]

@auto_hash_equals immutable VideoFile
    file::String
    datetime::DateTime
end

function getDateTime(folder::String, file::String)::DateTime
    fullfile = joinpath(folder, file)
    dateTimeOriginal, createDate, modifyDate = strip.(split(readstring(`$exiftool -T -AllDates -n $fullfile`), '\t'))
    datetime = DateTime(now())
    for i in [dateTimeOriginal, createDate, modifyDate]
        m = match(r"^(\d\d\d\d):(\d\d):(\d\d) (\d\d):(\d\d):(\d\d).?(\d?\d?\d?)", i)
        m == nothing && continue
        ts = zeros(Int, 7)
        for (j, t) in enumerate(m.captures)
            if !isempty(t)
                ts[j] = parse(Int, t)
            else
                break
            end
        end
        isnull(Dates.validargs(DateTime, ts...)) || continue
        datetime = min(datetime, DateTime(ts...))
    end
    return datetime
end

@auto_hash_equals immutable Point
    file::String
    time::Second
end

Point(;file = "", time = Second(0)) = Point(file, time)
Point(f::String, t::Time) = Point(f, Second(t.instant))
Point(f::String, h::Int, m::Int, s::Int) = Point(f, Time(h, m, s))

@auto_hash_equals immutable POI
    name::String
    start::Point
    stop::Point
    label::String
    comment::String

    function POI(name, start, stop, label, comment)
        @assert start.file != stop.file || start.time <= stop.time
        new(name, start, stop, label, comment)
    end
end

POI(;name = "", start = Point(), stop = Point(), label = "", comment = "") = POI(name, start, stop, label, comment)

# time differences
function duration(poi::POI, folder::String)::Int
    Δ = poi.stop.time.value - poi.start.time.value
    poi.start.file == poi.stop.file && return Δ
    fullfile = joinpath(folder, poi.start.file)
    t = round(Int, parse(readstring(`$exiftool -T -Duration -n $fullfile`)))
    return t + Δ
end

# time of day
function timeofday(poi::POI, folder::String)
    filescsv = joinpath(folder, "log", "files.csv")
    a, _ = readcsv(filescsv, String, header = true, quotes = true, comments = false)
    for i = 1:size(a,1)
        strip(a[i, 1]) == poi.start.file && return Time(DateTime(strip(a[i, 2])) + poi.start.time)
    end
end

@auto_hash_equals immutable Run
    metadata::Dict{Symbol, String}
    comment::String
end

Run(;metadata = Dict{Symbol, String}(), comment = "") = Run(metadata, comment)

@auto_hash_equals immutable Repetition
    run::Run
    repetition::Int
end

@auto_hash_equals immutable Association
    pois::OrderedSet{POI}
    runs::OrderedSet{Repetition}
    associations::Set{Tuple{POI, Repetition}}
end

Association() = Association(OrderedSet{POI}(), OrderedSet{Repetition}(), Set{Tuple{POI, Repetition}}())

# in

in(x::POI, a::Association) = x in a.pois
in(x::Repetition, a::Association) = x in a.runs
in(x::Tuple{POI, Repetition}, a::Association) = x in a.associations

# equal keys
==(a::Base.KeyIterator, b::Base.KeyIterator) = length(a)==length(b) && all(k->in(k,b), a)

# pushes

function run2repetition(xs::OrderedSet{Repetition}, r::Run)
    isempty(xs) || @assert keys(last(xs).run.metadata) == keys(r.metadata)
    Repetition(r, reduce((x, y) -> max(x, y.run.metadata == r.metadata ? y.repetition : 0), 0, xs) + 1)
end

push!(xs::OrderedSet{Repetition}, r::Run) = push!(xs, run2repetition(xs, r))

function push!(a::Association, t::POI)
    push!(a.pois, t)
    return a
end

function push!(a::Association, r::Run)
    push!(a.runs, r)
    return a
end

function push!(a::Association, x::Tuple{POI, Repetition})
    @assert first(x) in a.pois
    @assert last(x) in a.runs
    push!(a.associations, x)
    return a
end


# replace

## runs

function replace!(a::Association, o::Repetition, n::Run)
    @assert o in a
    @assert keys(last(a.runs).run.metadata) == keys(o.run.metadata) == keys(n.metadata)

    runs = OrderedSet{Repetition}()
    associations = Set{Tuple{POI, Repetition}}()
    for r1 in a.runs
        if r1 == o
            push!(runs, n)
        else
            push!(runs, r1.run)
        end
        r2 = last(runs)
        for (p, r) in a.associations
            if r1 == r
                push!(associations, (p, r2))
            end
        end
    end

    empty!(a.runs)
    push!(a.runs, runs...)
    isempty(associations) && return a 
    empty!(a.associations)
    push!(a.associations, associations...)
    return a
end

## pois

replace!(xs::OrderedSet{POI}, o::POI, n::POI) = OrderedSet{POI}(x == o ? n : x for x in xs)
replace!(xs::Set{Tuple{POI, Repetition}}, o::POI, n::POI) = Set{Tuple{POI, Repetition}}(first(x) == o ? (n, last(x)) : x for x in xs)
function replace!(a::Association, o::POI, n::POI)
    o == n && return a
    @assert o in a
    pois = replace!(a.pois, o, n)
    empty!(a.pois)
    push!(a.pois, pois...)
    isempty(a.associations) && return a 
    associations = replace!(a.associations, o, n)
    empty!(a.associations)
    push!(a.associations, associations...)
    return a
end

# deletes

function delete!(a::Association, r::Repetition)
    r in a || return a
    delete!(a.runs, r)
    filter!(x -> last(x) != r, a.associations)
    for x in a.runs
        if x.run.metadata == r.run.metadata && x.repetition > r.repetition
            replace!(a, x, x.run)
        end
    end
    return a
end

function delete!(a::Association, p::POI)
    p in a || return a
    delete!(a.pois, p)
    filter!(x -> first(x) != p, a.associations)
    return a
end

function delete!(a::Association, x::Tuple{POI, Repetition})
    x in a || return a
    @assert first(x) in a.pois
    @assert last(x) in a.runs
    delete!(a.associations, x)
    return a
end

# saves

function prep_file(folder::String, what::String)::String
    folder = joinpath(folder, "log")
    isdir(folder) || mkdir(folder)
    return joinpath(folder, "$what.csv")
end

function save(folder::String, x::OrderedSet{VideoFile})
    file = prep_file(folder, "files")
    #isempty(x) && rm(file, force=true)
    n = length(x)
    a = Matrix{String}(n + 1,2)
    a[1,:] .= ["file", "date and time"]
    for (i, v) in enumerate(x)
        a[i + 1, :] .= [v.file, string(v.datetime)]
    end
    writecsv(file, a)
end

function save(folder::String, x::OrderedSet{POI}) 
    file = prep_file(folder, "pois")
    n = length(x)
    a = Matrix{String}(n + 1,7)
    a[1,:] .= ["name", "start file", "start time (seconds)", "stop file", "stop time (seconds)", "label", "comments"]
    for (i, t) in enumerate(x)
        a[i + 1, :] .= [t.name, t.start.file, string(t.start.time.value), t.stop.file, string(t.stop.time.value), t.label, t.comment]
    end
    a .= strip.(a)
    writecsv(file, a)
end

function save(folder::String, x::OrderedSet{Repetition})
    ks = keys(first(x).run.metadata)
    @assert reduce((x, y) -> x && keys(y.run.metadata) == ks, true, x)
    file = prep_file(folder, "runs")
    ks = sort(collect(ks))
    header = string.(ks)
    push!(header, "Comment", "Repetition")
    n = length(x)
    a = Matrix{String}(n + 1, length(header))
    a[1,:] .= header
    for (i, r) in enumerate(x)
        for (j, k) in enumerate(ks)
            a[i + 1, j] = r.run.metadata[k]
        end
        a[i + 1, end - 1] = r.run.comment
        a[i + 1, end] = string(r.repetition)
    end
    a .= strip.(a)
    writecsv(file, a)
end

function save(folder::String, a::Association)
    save(folder, a.pois)
    save(folder, a.runs)
    file = prep_file(folder, "associations")
    open(file, "w") do o
        println(o, "POI number, run number")
        for (t, r) in a.associations
            ti = findfirst(a.pois, t)
            ri = findfirst(a.runs, r)
            println(o, ti, ",", ri)
        end
    end
end

# loads

function loadLogVideoFiles(folder::String)::Dict{String, DateTime}
    filescsv = joinpath(folder, "log", "files.csv")
    vfs = Dict{String, DateTime}()
    if isfile(filescsv)
        a, _ = readcsv(filescsv, String, header = true, quotes = true, comments = false)
        a .= strip.(a)
        @assert allunique(a[:,1])
        nrow, ncol = size(a)
        @assert ncol == 2
        for i = 1:nrow
            vfs[a[i, 1]] = DateTime(a[i, 2])
        end
    end
    return vfs
end

function findVideoFiles!(log::Dict{String, DateTime}, folder::String)
    for (root, dir, files) in walkdir(folder)
        for file in files
            file[1] == '.' && continue
            last(splitext(file)) in exts || continue
            fname = relpath(joinpath(root, file), folder)
            if !haskey(log, fname)
                log[fname] = getDateTime(folder, fname)
            end
        end
    end
end

function getVideoFiles(folder::String)::OrderedSet{VideoFile}
    log = loadLogVideoFiles(folder)
    findVideoFiles!(log, folder)
    o = sort([(k, v) for (k, v) in log], by = last)
    return OrderedSet{VideoFile}(VideoFile(k, v) for (k,v) in o)
end


function loadPOIs(folder::String)::OrderedSet{POI}
    filescsv = joinpath(folder, "log", "pois.csv")
    tgs = OrderedSet{POI}()
    if isfile(filescsv) 
        a, _ = readcsv(filescsv, String, header = true, quotes = true, comments = false)
        a .= strip.(a)
        nrow, ncol = size(a)
        @assert ncol == 7
        for i = 1:nrow
            tg = POI(a[i, 1], Point(a[i, 2], Second(parse(Int, a[i, 3]))), Point(a[i, 4], Second(parse(Int, a[i, 5]))), a[i, 6], a[i, 7])
            @assert !(tg in tgs)
            push!(tgs, tg)
        end
    end
    return tgs
end

function getmetadata(folder)
    metadata = Dict{Symbol, String}()
    file = joinpath(folder, "metadata", "run.csv")
    if isfile(file)
        b = readcsv(file, comments = false)
        for i = 1:size(b,1)
            metadata[Symbol(strip(b[i, 1]))] = length(b[i,:]) < 2 ? "" : strip(b[i, 2])
        end
    end
    return metadata
end

function loadRuns(folder::String)::OrderedSet{Repetition}
    filescsv = joinpath(folder, "log", "runs.csv")
    rs = OrderedSet{Repetition}()
    if isfile(filescsv) 
        a, ks = readcsv(filescsv, String, header = true, quotes = true, comments = false)
        ks = Symbol.(strip.(vec(ks)))
        a .= strip.(a)
        metadata = getmetadata(folder)
        for (k, v) in metadata
            if !(k in ks)
                unshift!(ks, k)
                a = [repmat([v], size(a, 1)) a]
            end
        end
        nks = length(ks)
        nrow, ncol = size(a)
        @assert nks == ncol > 2
        for i = 1:nrow
            metadata = Dict{Symbol, String}()
            for j = 1:ncol - 2
                metadata[ks[j]] = a[i, j]
            end
            comment = a[i, ncol - 1]
            repetition = parse(Int, a[i, ncol])
            r = Repetition(Run(metadata, comment), repetition)
            @assert !(r in rs)
            push!(rs, r)
        end
    end
    return rs
end

function loadAssociation(folder::String)::Association
    ts = loadPOIs(folder)
    rs = loadRuns(folder)
    filescsv = joinpath(folder, "log", "associations.csv")
    as = Set{Tuple{POI, Repetition}}()
    if isfile(filescsv) 
        a, ks = readcsv(filescsv, Int, header = true, comments = false)
        nrow, ncol = size(a)
        @assert ncol == 2
        for i = 1:nrow
            push!(as, (ts[a[i,1]], rs[a[i, 2]]))
        end
    end
    return Association(ts, rs, as)
end

# empty

function empty!(a::Association)
    empty!(a.pois)
    empty!(a.runs)
    empty!(a.associations)
    return a
end

isempty(a::Association) = isempty(a.pois) && isempty(a.runs) && isempty(a.associations)

function delete_empty_metadata!(a::Association)
    for k in keys(a.runs[1].run.metadata)
        if all(isempty(r.run.metadata[k]) for r in a.runs)
            for r in a.runs
                delete!(r.run.metadata, k)
            end
        end
    end
end

