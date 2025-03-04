nothing == nothing

if true println("true") end

if true || x println(x) end

break

const local x = 2

function f(x)
    while true
        if x
            println("x is true")
            continue
        elseif false
            break
        end
    end

    const y = [3, 4]

    for i in eachindex(y)
        const local z = 3
        x += z
    end

    break

    return y
end
