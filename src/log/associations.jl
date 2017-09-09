#=using DataStructures, AutoHashEquals, Base.Dates, Unitful, UnitfulAngles


export  VideoFile, Point, POI, Run, Repetition, Association, 
        replace!, findVideoFiles, getVideoFiles, save,
        loadLogVideoFiles, loadPOIs, loadRuns, loadAssociation

const exiftool_base = joinpath(Pkg.dir("BeetleWay"), "deps", "src", "exiftool", "exiftool")
const exiftool = exiftool_base*(is_windows() ? ".exe" : "")
=#

using Base.Dates#, DataStructures

import Base: ∈, push!, empty!, delete!#, isempty, ==, in, show

const exts = [".webm", ".mkv", ".flv", ".flv", ".vob", ".ogv", ".ogg", ".drc", ".mng", ".avi", ".mov", ".qt", ".wmv", ".yuv", ".rm", ".rmvb", ".asf", ".amv", ".mp4", ".m4p", ".m4v", ".mpg", ".mp2", ".mpeg", ".mpe", ".mpv", ".mpg", ".mpeg", ".m2v", ".m4v", ".svi", ".3gp", ".3g2", ".mxf", ".roq", ".nsv", ".flv", ".f4v", ".f4p", ".f4a", ".f4b", ".MTS", ".DS_Store"]

read_run_metadata(folder::String) = open(joinpath(folder, "metadata", "run.csv"), "r") do o
    factors = String[]
    levels = Vector{Vector{String}}()
    for (li, l) in enumerate(readlines(o))
        push!(levels, String[])
        for (wi, w) in enumerate(split(l, ','))
            if wi > 1
                w = strip(w)
                if isempty(w)
                    @assert wi == 2 "empty ran level"
                else
                    @assert w ∉ levels[li] "run levels are not unique"
                    # @assert length(levels) < 255 "too many run levels"
                end
                push!(levels[li], w)
            else
                w = strip(w)
                @assert !isempty(w) "empty line in metadata"
                @assert w ∉ factors "factors are not unique in run metadata"
                # @assert length(factors) < 255 "too many factors in run metadata"
                push!(factors, w)
            end
        end
    end
    return (factors, levels)
end

read_poi_metadata(folder::String) = open(joinpath(folder, "metadata", "poi.csv"), "r") do o
    poi_names = String[]
    for w in split(readline(o), ',')
        w = strip(w)
        @assert !isempty(w) "empty POI in metadata"
        @assert w ∉ poi_names "POIs are not unique in poi metadata"
        # @assert length(poi_names) < 255 "too many POIs in poi metadata"
        push!(poi_names, w)
    end
    return poi_names
end

function find_all_files(folder::String)
    all_files = String[]
    for (root, dir, files) in walkdir(folder)
        for file in files
            file[1] == '.' && continue
            last(splitext(file)) in exts || continue
            push!(all_files, file)
        end
    end
    return all_files
end

struct Metadata
    poi_names::Vector{String} # must be unique
    factors::Vector{String} # must be unique
    levels::Vector{Vector{String}} # must be unique
    files::Vector{String} # must be unique

    function Metadata(folder::String)
        poi_names = read_poi_metadata(folder)
        factors, levels = read_run_metadata(folder)
        files = find_all_files(folder)
        new(poi_names, factors, levels, files)#, setups)
    end
end

struct File
    name::Int # must be unique
    creation::DateTime
    duration::Second 

    function File(md::Metadata, name::String, creation::DateTime, duration::Second) 
        @assert name ∈ md.files "file not found in metadata"
        @assert duration ≥ Second(0) "negative durations not allowed"
        new(findfirst(md.files, name), creation, duration)
    end
end

struct Point
    file::Int
    time::Second

    function Point(md::Metadata, file::String, time::Second) 
        @assert file ∈ md.files "file not found in metadata"
        @assert time ≥ Second(0) "negative times not allowed"
        new(findfirst(md.files, file), time)
    end
end

struct POI
    name::Int
    start::Point
    stop::Point
    label::String
    comment::String

    function POI(md::Metadata, name::String, start::Point, stop::Point, label::String, comment::String)
        @assert name ∈ md.poi_names "POI not found in metadata"
        @assert start.file ≠ stop.file || start.time ≤ stop.time "starting point comes after stoping point"
        new(findfirst(md.poi_names, name), start, stop, label, comment)
    end
end

struct Run
    setup::Vector{Union{Int, String}}
    comment::String

    function Run(md::Metadata, setup_string::Vector{String}, comment::String)
        setup = Vector{Union{Int, String}}()
        for (i, s) in enumerate(setup_string)
            if length(md.levels[i]) == 1 && isempty(md.levels[i][1])
                push!(setup, s)
            else
                j = findfirst(md.levels[i], s)
                @assert j ≠ 0 "run levels not found in metadata"
                push!(setup, j)
            end
        end
        new(setup, comment)
    end
end

struct Repetition
    run::Run
    repetition::Int
end

struct Association
    md::Metadata

    # data
    pois::Vector{POI} # must be unique
    repetitions::Vector{Repetition} 
    associations::Vector{Pair{Int, Int}} # must be unique

    function Association(folder::String)
        md = Metadata(folder)

        if isdir(joinpath(folder, "log"))
        else
            pois = POI[]
            repetitions = Repetition[]
            associations = Pair{POI, Repetition}[]
        end
        new(md, pois, repetitions, associations)
    end
end

# in

∈(x::POI, a::Association) = x ∈ a.pois
∈(x::Repetition, a::Association) = x ∈ a.repetitions
∈(x::Pair{Int, Int}, a::Association) = x ∈ a.associations

# pushes

function push!(a::Association, x::POI)
    x ∉ a && push!(a.pois, x)
    return a
end

function push!(a::Association, x::Run)
    repetition = reduce((x, r) -> max(x, r.run.setup == x.setup ? x.repetition : 0), 0, a.repetitions) + 1
    push!(a.repetitions, Repetition(x, repetition))
    return a
end

function push!(a::Association, x::Pair{POI, Repetition})
    i = findfirst(a.pois, first(x))
    @assert i ≠ 0 "association pair includes a non existent POI"
    j = findfirst(a.repetitions, last(x))
    @assert j ≠ 0 "association pair includes a non existent run"
    x = i => j
    x ∉ a.associations && push!(a.associations, x)
    return a
end
#=function push!(a::Association, x::Pair{Int, Int})
    @assert first(x) ≤ length(a.pois) "association pair includes a non existent POI"
    @assert last(x) ≤ length(a.repetitions) "association pair includes a non existent run"
    x ∉ a.associations && push!(a.associations, x)
    return a
end=#

# deletes

function delete!(a::Association, x::POI)
    i = findfirst(a.pois, x)
    i == 0 && return a
    deleteat!(a.pois, i)
    filter!(y -> first(y) ≠ i, a.associations)
    for (j,(p, r)) in enumerate(a.associations)
        if p > i
            splice!(a.associations, j, (p - 1) => r)
        end
    end
    return a
end

function delete!(a::Association, x::Repetition)
    x ∉ a && return a
    ind = 0
    for (i,r) in enumerate(a.repetitions)
        if r.run.setup == x.run.setup
            if r == x
                ind = copy(i)
                deleteat!(a.repetitions, i)
            else
                if r.repetition > x.repetition
                    r.repetition -= 1
                end
            end
        end
    end
    for (j,(p, r)) in enumerate(a.associations)
        if r > ind
            splice!(a.associations, j, p => (r - 1))
        end
    end
    return a
end

function delete!(a::Association, x::Pair{Int, Int})
    i = findfirst(a.associations, x)
    i == 0 && return a
    deleteat!(a.associations, i)
    return a
end

# replace

function replace!(a::Association, o::POI, n::POI)
    o == n && return a
    @assert n ∉ a "new POI already exists"
    i = findfirst(a.pois, o)
    @assert i ≠ 0 "old POI not found"
    splice!(a.pois, i, n)
    return a
end

function replace!(a::Association, o::Repetition, n::Repetition)
    o == n && return a
    @assert n ∉ a "new run already exists"
    i = findfirst(a.repetitions, o)
    @assert i ≠ 0 "old run not found"
    return a
end

# empty

function empty!(a::Association)
    empty!(a.pois)
    empty!(a.runs)
    empty!(a.associations)
    return a
end







folder = "/home/yakir/.julia/v0.6/BeetleWay/test/videofolder"
a = Association(folder)

p1 = Point(a.md, "a.mp4", Second(0))
p2 = Point(a.md, "b.mp4", Second(2))
p = POI(a.md, "Walking", p1, p2, "label", "comment")
push!(a, p)
r = Run(a.md, ["What not", "London", "Dark", "Upper", "Earth", "kakaka"], "comment")
push!(a, r)
rr = a.repetitions[end]
push!(a, p => rr)

using JLD


#=
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
        # @assert start.file != stop.file || start.time <= stop.time
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

# equal keys
==(a::Base.KeyIterator, b::Base.KeyIterator) = length(a)==length(b) && all(k->in(k,b), a)


# replace

## runs

function replace!(a::Association, o::Run, n::Run)
    # @assert o in a
    @assert keys(last(a.runs).run.metadata) == keys(o.metadata) == keys(n.metadata)

    runs = OrderedSet{Repetition}()
    associations = Set{Tuple{POI, Repetition}}()
    for r1 in a.runs
        if r1.run == o
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
end=#

