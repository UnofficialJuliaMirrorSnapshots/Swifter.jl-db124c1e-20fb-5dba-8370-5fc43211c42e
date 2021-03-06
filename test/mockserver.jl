if VERSION >= v"0.5-"
    using Base.Test
else
    using BaseTestNext
    const Test = BaseTestNext
end

using HttpServer
using Swifter
import Swifter: QueryResult, ResultInfo, App


# #16107  230e767f6cecbaed426965f8badc5726bb7db72f
using Compat
if VERSION < v"0.5-dev+4194"
    const bytes_to_string = Compat.utf8
else
    const bytes_to_string = Compat.String
end


function handle(color)
    current_color = color
    HttpHandler() do req::Request, res::Response
        if ismatch(r"^/initial", req.resource)
            Response("""{"typ": "any", "value": ""}""")
        elseif ismatch(r"^/query", req.resource)
            param = JSON.parse(bytes_to_string(req.data))
            if "Setter" == param["type"]
                current_color = first(param["rhs"])
            end
            Response("""{"typ": "any", "value": "$current_color"}""")
        else
            Response("""{"typ": "symbol", "value": "Failed"}""")
        end
    end
end


param = Dict("lhs"=>Any[(:symbol,:vc),(:symbol,:view),(:symbol,:backgroundColor)], "type"=>"Getter")
result = @query vc.view.backgroundColor
@test QueryResult(ResultInfo(:symbol, Swifter.RequireToInitial), App(""),"/query",param) == result
@test Swifter.RequireToInitial == result


server_one = Server(handle("UIDeviceRGBColorSpace 0 0 0 1"))
server_two = Server(handle("UIDeviceRGBColorSpace 0 1 0 1"))
@async run(server_one, 8000)
@async run(server_two, 8001)
sleep(0.1)

vc1 = initial("http://localhost:8000")
vc2 = initial("http://localhost:8001")

@test "UIDeviceRGBColorSpace 0 0 0 1" == @query vc1.view.backgroundColor
@test "UIDeviceRGBColorSpace 0 1 0 1" == @query vc2.view.backgroundColor

@query vc1.view.backgroundColor = vc2.view.backgroundColor

@test "UIDeviceRGBColorSpace 0 1 0 1" == @query vc1.view.backgroundColor
@test "UIDeviceRGBColorSpace 0 1 0 1" == @query vc2.view.backgroundColor

try
    close(server_one.http)
    close(server_two.http)
catch e
end
