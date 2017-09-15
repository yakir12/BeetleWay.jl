#=using DataStructures, AutoHashEquals, Base.Dates, Unitful, UnitfulAngles


export  VideoFile, Point, POI, Run, Repetition, Association, 
        replace!, findVideoFiles, getVideoFiles, save,
        loadLogVideoFiles, loadPOIs, loadRuns, loadAssociation

const exiftool_base = joinpath(Pkg.dir("BeetleWay"), "deps", "src", "exiftool", "exiftool")
const exiftool = exiftool_base*(is_windows() ? ".exe" : "")
=#

using Base.Dates, JLD, AutoHashEquals

import Base: ∈, push!, empty!, delete!#, isempty, ==, in, show
import JLD.save

const exts = [".webm", ".mkv", ".flv", ".flv", ".vob", ".ogv", ".ogg", ".drc", ".mng", ".avi", ".mov", ".qt", ".wmv", ".yuv", ".rm", ".rmvb", ".asf", ".amv", ".mp4", ".m4p", ".m4v", ".mpg", ".mp2", ".mpeg", ".mpe", ".mpv", ".mpg", ".mpeg", ".m2v", ".m4v", ".svi", ".3gp", ".3g2", ".mxf", ".roq", ".nsv", ".flv", ".f4v", ".f4p", ".f4a", ".f4b", ".MTS", ".DS_Store"]

struct SetLevels
    data::Vector{String}
end

struct FreeLevels
    data::Vector{String}
end

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
                end
                push!(levels[li], w)
            else
                w = strip(w)
                @assert !isempty(w) "empty line in metadata"
                @assert w ∉ factors "factors are not unique in run metadata"
                push!(factors, w)
            end
        end
    end
    return (factors, [length(l) == 1 && isempty(l[1]) ? FreeLevels(String[""]) : SetLevels(l) for l in levels])
end

read_poi_metadata(folder::String) = open(joinpath(folder, "metadata", "poi.csv"), "r") do o
    poi_names = String[]
    for w in split(readline(o), ',')
        w = strip(w)
        @assert !isempty(w) "empty POI in metadata"
        @assert w ∉ poi_names "POIs are not unique in poi metadata"
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
    folder::String
    poi_names::Vector{String} # must be unique
    factors::Vector{String} # must be unique
    levels::Vector{Union{FreeLevels, SetLevels}} # must be unique
    files::Vector{String} # must be unique
end

function Metadata(folder::String)
    poi_names = read_poi_metadata(folder)
    factors, levels = read_run_metadata(folder)
    files = find_all_files(folder)
    return Metadata(folder, poi_names, factors, levels, files)
end

struct Temporal
    file::Int # must be unique
    creation::DateTime
    duration::Millisecond
end

function Temporal(md::Metadata, name::String, creation::DateTime, duration::Second) 
    @assert name ∈ md.files "file not found in metadata"
    @assert duration ≥ Second(0) "negative durations not allowed"
    new(findfirst(md.files, name), creation, duration)
end

Temporal(name::Int) = Temporal(name, DateTime(0), Second(0))

@auto_hash_equals struct Point
    file::Int
    time::Second

    function Point(md::Metadata, file::String, time::Second) 
        @assert file ∈ md.files "file not found in metadata"
        @assert time ≥ Second(0) "negative times not allowed"
        new(findfirst(md.files, file), time)
    end
end

Point(md::Metadata) = Point(md, md.files[1], Second(0))

@auto_hash_equals struct POI
    name::Int
    label::String
    start::Point
    stop::Point
    comment::String

    function POI(md::Metadata, name::String, label::String, start::Point, stop::Point, comment::String)
        @assert name ∈ md.poi_names "POI not found in metadata"
        @assert start.file ≠ stop.file || start.time ≤ stop.time "starting point comes after stoping point"
        new(findfirst(md.poi_names, name), label, start, stop, comment)
    end
end

POI(md::Metadata) = POI(md, md.poi_names[1], "", Point(md), Point(md), "")
POI(md::Metadata, name::String, label::String, start_file::String, start_time::Time, stop_file::String, stop_time::Time, comment::String) = POI(md, name, label, Point(md, start_file, Second(start_time - Time(0))), Point(md, stop_file, Second(stop_time - Time(0))), comment)

@auto_hash_equals struct Run
    setup::Vector{Int}
    comment::String

    function Run(md::Metadata, setup_string::Vector{String}, comment::String)
        setup = Int[]
        for (x,y) in zip(setup_string, md.levels)
            if y isa SetLevels
                j = findfirst(y.data, x)
                @assert j ≠ 0 "run levels not found in metadata"
                push!(setup, j)
            else
                j = findfirst(y.data, x)
                if j ≠ 0
                    push!(setup, j)
                else
                    push!(y.data, x)
                    push!(setup, length(y.data))
                end
            end
        end
        new(setup, comment)
    end
end

Run(md::Metadata) = Run(md, [first(x.data) for x in md.levels], "") 

@auto_hash_equals struct Repetition
    run::Run
    repetition::Base.RefValue{Int}

    Repetition(run::Run, repetition::Int) = new(run, Ref(repetition))
end

function combine(org::Metadata, new::Metadata)
    @assert org.folder == new.folder "data-sets from different folders is not supported yet"
    poi_names = org.poi_names ∪ new.poi_names
    factors = org.factors
    levels = org.levels
    for (i,f) in enumerate(org.factors)
        j = findfirst(new.factors, f)
        if j ≠ 0
            if new.levels[j] isa FreeLevels
                levels[i] = FreeLevels(levels[i].data)
            else
                levels[i] = SetLevels(levels[i].data ∪ new.levels[j].data)
            end
        end
    end
    for (i,f) in enumerate(new.factors)
        j = findfirst(org.factors, f)
        if j == 0
            push!(factors, f)
            push!(levels, new.levels[j])
        end
    end
    files = org.files ∪ new.files
    return Metadata(org.folder, poi_names, factors, levels, files)
end

struct Association
    md::Metadata

    # data
    temporals::Vector{Temporal}
    pois::Vector{POI} # must be unique
    repetitions::Vector{Repetition} 
    associations::Vector{Pair{Int, Int}} # must be unique

    function Association(md::Metadata)
        file = joinpath(md.folder, "log", "log.jld")
        if isfile(file)
            org = load(file, "a")
            md = combine(org.md, md)
            temporals = org.temporals
            pois = org.pois
            repetitions = org.repetitions
            associations = org.associations
        else
            temporals = Temporal[]
            pois = POI[]
            repetitions = Repetition[]
            associations = Pair{Int, Int}[]
        end
        new(md, temporals, pois, repetitions, associations)
    end
end

Association(folder::String) = Association(Metadata(folder))


# in

∈(x::POI, a::Association) = x ∈ a.pois
∈(x::Repetition, a::Association) = x ∈ a.repetitions
∈(x::Pair{Int, Int}, a::Association) = x ∈ a.associations
∈(x::Pair{POI, Repetition}, a::Association) = (findfirst(a.pois, first(x))=>findfirst(a.repetitions, last(x))) ∈ a.associations

# pushes

function push!(a::Association, x::POI)
    x ∉ a && push!(a.pois, x)
    return a
end

function push!(a::Association, x::Run)
    repetition = reduce((y, r) -> max(y, r.run.setup == x.setup ? r.repetition.x : 0), 0, a.repetitions) + 1
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

# check all

function check!(a::Association, x::POI)
    i = findfirst(a.pois, x)
    @assert i ≠ 0
    for j = 1:length(a.repetitions)
        p = i=>j
        p ∉ a.associations && push!(a.associations, p)
    end
    return a
end

function check!(a::Association, x::Repetition)
    i = findfirst(a.repetitions, x)
    @assert i ≠ 0
    for j = 1:length(a.pois)
        p = j=>i
        p ∉ a.associations && push!(a.associations, p)
    end
    return a
end

function uncheck!(a::Association, x::POI)
    i = findfirst(a.pois, x)
    @assert i ≠ 0
    filter!(y -> first(y) ≠ i, a.associations)
    return a
end

function uncheck!(a::Association, x::Repetition)
    i = findfirst(a.repetitions, x)
    @assert i ≠ 0
    filter!(y -> last(y) ≠ i, a.associations)
    return a
end

# deletes

function delete!(a::Association, x::POI)
    i = findfirst(a.pois, x)
    i == 0 && return a
    deleteat!(a.pois, i)
    filter!(x -> first(x) ≠ i, a.associations)
    for j in linearindices(a.associations)
        p,r = a.associations[j]
        if p > i
            a.associations[j] = p-1=>r
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
            else
                if r.repetition.x > x.repetition.x
                    r.repetition.x -= 1
                end
            end
        end
    end
    deleteat!(a.repetitions, ind)
    filter!(x -> last(x) ≠ ind, a.associations)
    for j in linearindices(a.associations)
        p,r = a.associations[j]
        if r > ind
            a.associations[j] = p=>r-1
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

function delete!(a::Association, x::Pair{POI, Repetition})
    i = findfirst(a.pois, first(x))
    @assert i ≠ 0
    j = findfirst(a.repetitions, last(x))
    @assert j ≠ 0
    delete!(a, i=>j)
end

# replace

function replace!(a::Association, o::POI, n::POI)
    o == n && return a
    if n ∈ a
        delete!(a, o)
        return a
    end
    for i in 1:length(a.pois)
        if a.pois[i] == o
            a.pois[i] = n
            return a
        end
    end
    throw(AssertionError("old POI not found"))
end

function replace!(a::Association, o::Repetition, n::Run)
    i = findfirst(a.repetitions, o)
    @assert i ≠ 0 "old run not found"
    delete!(a, o)
    push!(a, n)
    r = pop!(a.repetitions)
    insert!(a.repetitions, i, r)
end

# empty

function empty!(a::Association)
    empty!(a.pois)
    empty!(a.repetitions)
    empty!(a.associations)
    return a
end

# save

save(a::Association) = save(joinpath(a.md.folder, "log", "log.jld"), "a", a) 

# pop

pop(md::Metadata, x::Point) = (md.files[x.file], x.time)

pop(md::Metadata, x::POI) = (md.poi_names[x.name], x.label, pop(md, x.start), pop(md, x.stop), x.comment)

pop(md::Metadata, x::Repetition) = ([l.data[i] for (l, i) in zip(md.levels, x.run.setup)], x.run.comment, x.repetition.x)

function make_label(md::Metadata, x::POI) 
    name, label = pop(md, x)
    if isempty(label)
        return name
    else
        return name*":"*label
    end
end

function make_label(md::Metadata, x::Repetition) 
    setup, _, repetition = pop(md, x)
    l = join(filter(!isempty, join.(Iterators.take.(setup, 3))), ':')
    return "$l-$repetition"
end
