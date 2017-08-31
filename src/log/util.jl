cleanit(x::T) where T <: AbstractArray{String} = filter(!isempty, strip.(vec(x)))
function assert_metadata(folder::String)
    @assert isdir(folder) "$folder does not exist"
    @assert isdir(joinpath(folder, "metadata")) "No metadata folder found"
    @assert isfile(joinpath(folder, "metadata", "poi.csv")) "No `poi.csv` file found"
    x = cleanit(readcsv(joinpath(folder, "metadata", "poi.csv"), String))
    @assert !all(isempty.(x)) "There are no enteries in the `poi.csv` file" 
    @assert allunique(x) "`poi.csv` contains duplicate items"

    @assert isfile(joinpath(folder, "metadata", "run.csv")) "No `run.csv` file found"
    x = readcsv(joinpath(folder, "metadata", "run.csv"), String)
    for i in 1:size(x,1)
        xi = cleanit(x[i,:])
        @assert !all(isempty.(xi)) "There are no enteries in the `run.csv` file at line $i"
        @assert allunique(xi) "`run.csv` contains duplicate items in line $i"
    end
end


function second2hms(x::Second)::Dict{DataType, Int}
    ps = Dates.canonicalize(Dates.CompoundPeriod(x))
    a = Dict{DataType, Int}(k => 0 for k in [Hour, Minute, Second])
    ts = [Day, Week, Month, Year]
    for p in ps.periods
        if typeof(p) in ts
            a[Hour] += Hour(p).value
        else
            a[typeof(p)] += p.value
        end
    end
    return a
end
shorten(s::String, k::Int) = length(s) > 2k + 1 ? s[1:k]*"…"*s[(end-k + 1):end] : s
function shorten(vfs::OrderedSet{String}, m)
    nmax = maximum(map(length, vfs))
    n = min(m, nmax) - 1
    while n < nmax
        n += 1
        if allunique(shorten(vf, n) for vf in vfs)
            break
        end
    end
    return OrderedDict(shorten(vf, n) => vf for vf in vfs)
end

function openit(f::String)
    isfile(f) || systemerror("$f not found", true)
    cmd = if is_windows()
        `explorer $f`
    elseif is_linux()
        `xdg-open $f` 
    elseif is_apple()
        try 
            `open -a "quicktime player" $f`
        catch 
            `open $f`
        end
    else
        error("Unknown OS")
    end
    return run(ignorestatus(cmd))
        #stream, proc = open(cmd)
        # return proc
        # try to see if you can kill the spawned process (closing the movie player). this will be useful for testing this, and for managing shit once the user is done (not sure if all the players automatically close when the user quits julia)
end
function findshortfile(v::String, d::Dict{String, String})::String
    for k in keys(d)
        d[k] == v && return k
    end
    error("Couldn't find $v in $d")
end
function validargs(_, y, m, d, rest...)
    0 < m < 13 || return Nullable{ArgumentError}(ArgumentError("Month: $m out of range (1:12)"))
    0 < d < daysinmonth(y,m)+1 || return Nullable{ArgumentError}(ArgumentError("Day: $d out of range (1:$(daysinmonth(y,m)))"))
    return Nullable{ArgumentError}()
end
