function table(cur_matrix::Matrix; header_row=[], title=nothing)
    cur_table = ""
    if title != nothing
        cur_table *= "<h2 style='padding: 10px'>$title</h2>"
    end
    cur_table *= "<table class='table table-striped'>"
    if !isempty(header_row)
        cur_table *= "<thead><tr>"
        for cur_header in header_row
            cur_table *= "<th>$cur_header</th>"
        end
        cur_table *= "</tr></thead>"
    end
    cur_table *= "<tbody>"
    for ii in 1:size(cur_matrix, 1)
        cur_table *= "<tr>"
        for jj in 1:size(cur_matrix, 2)
            cur_table *= "<td>"
            cur_table *= string(cur_matrix[ii, jj])
            cur_table *= "</td>"
        end
        cur_table *= "</tr>"
    end
    cur_table *= "</tbody>"
    cur_table *= "</table>"
    return cur_table
end
function show(x::Second)::String
    ps = canonicalize(Dates.CompoundPeriod(Second(x)))
    a = Dict{DataType, Int}(k => 0 for k in [Hour, Minute, Second])
    ts = [Day, Week, Month, Year]
    for p in ps.periods
        if typeof(p) in ts
            a[Hour] += Hour(p).value
        else
            a[typeof(p)] += p.value
        end
    end
    return @sprintf "%i:%02i:%02i" a[Hour] a[Minute] a[Second]
end

function show(x::Time)::String
    i = Hour(x).value
    i = i > 12 ? i - 12 : i
    s = Minute(x).value >= 30 ? 0x1F550+(i-1)+12 : 0x1F550+(i-1)
    t = uppercase(num2hex(s)[end-4:end])
    return string("&#x$t;")
end

function report(folder::String)
    a = loadAssociation(folder)
    delete_empty_metadata!(a)

    rep = counter(Vector{String})
    for r in a.runs
        k = collect(values(r.run.metadata))
        push!(rep, k)
    end

    durs = Dict(poi.name => counter(Vector{String}) for poi in a.pois)
    coun = Dict(poi.name => counter(Vector{String}) for poi in a.pois)
    cosa = Dict(poi.name => Accumulator(Vector{String}, Float64) for poi in a.pois)
    sina = Dict(poi.name => Accumulator(Vector{String}, Float64) for poi in a.pois)
    for (p, r) in a.associations
        k = collect(values(r.run.metadata))
        push!(durs[p.name], k, duration(p, folder))
        push!(coun[p.name], k)
        t = timeofday(p, folder)
        # println(t)
        α = convert(u"rad", t)
        push!(cosa[p.name], k, cos(α))
        push!(sina[p.name], k, sin(α))
    end
    dur = Dict(k1 => Dict(k2 => Second(round(Int, v2/coun[k1][k2])) for (k2, v2) in v1) for (k1, v1) in durs)
    tim = Dict(k1 => Dict(k2 => convert(Time, atan2(u"rad", sina[k1][k2], v2)) for (k2, v2) in v1) for (k1, v1) in cosa)

    m = Matrix{String}[]
    for (k, v) in rep
        run = [k; string(v)]
        poi = [haskey(v1, k) ? show(v1[k])*" "*show(tim[k1][k]) : "" for (k1, v1) in dur]
        push!(m, reshape([run; poi], (1,:)))
    end
    m = vcat(m...)

    txt = table(m, header_row = [String.(collect(keys(a.runs[1].run.metadata))); "Repetition"; collect(keys(dur))], title = "Summary for $folder")
    index = """<!DOCTYPE html> <html> <head> <style> table { font-family: arial, sans-serif; border-collapse: collapse; width: 100%; } td, th { border: 1px solid #dddddd; text-align: left; padding: 8px; } tr:nth-child(even) { background-color: #dddddd; } </style> </head> <body> $txt </body> </html>"""
end


