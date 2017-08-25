function fragment(folder::String)
    a = loadAssociation(folder)
    # names = shortest_file_names(a)
    i = 0
    allvideofolder = joinpath(folder, "allvideofolder$i")
    while isdir(allvideofolder)
        i += 1
        allvideofolder = replace(allvideofolder, r"(\d*)$", i)
    end
    mkdir(allvideofolder)
    for (i, poi) in enumerate(a.pois)
        name = joinpath(allvideofolder, "$i.mp4")
        if poi.start.file ≠ poi.stop.file
            file = tempname()
            open(file, "w") do o
                for f in (poi.start.file, poi.stop.file)
                    fullname = joinpath(folder, f)
                    println(o, "file $fullname")
                end
            end
            Δ = duration(poi, folder)
            run(`ffmpeg -f concat -safe 0 -i $file -c copy -ss $(Dates.value(poi.start.time)) -to $Δ $name`)
        else
            fullname = joinpath(folder, poi.start.file)
            if poi.start.time == poi.stop.time
                run(`ffmpeg -i $fullname -c copy -ss $(Dates.value(poi.start.time)) -to $(Dates.value(poi.stop.time) + 1) $name`)
            else
                run(`ffmpeg -i $fullname -c copy -ss $(Dates.value(poi.start.time)) -to $(Dates.value(poi.stop.time)) $name`)
            end
        end
    end
end

