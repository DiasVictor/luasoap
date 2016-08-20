#!/usr/bin/lua -lluarocks.require
------------------------------------
local function print_r ( t )  
    local print_r_cache={}
    local function sub_print_r(t,indent)
        if (print_r_cache[tostring(t)]) then
            print(indent.."*"..tostring(t))
        else
            print_r_cache[tostring(t)]=true
            if (type(t)=="table") then
                for pos,val in pairs(t) do
                    if (type(val)=="table") then
                        print(indent.."["..pos.."] => "..tostring(t).." {")
                        sub_print_r(val,indent..string.rep(" ",string.len(pos)+8))
                        print(indent..string.rep(" ",string.len(pos)+6).."}")
                    elseif (type(val)=="string") then
                        print(indent.."["..pos..'] => "'..val..'"')
                    else
                        print(indent.."["..pos.."] => "..tostring(val))
                    end
                end
            else
                print(indent..tostring(t))
            end
        end
    end
    if (type(t)=="table") then
        print(tostring(t).." {")
        sub_print_r(t,"  ")
        print("}")
    else
        sub_print_r(t,"  ")
    end
    print()
end

------------------------------------


local client = require"soap.client"


local script_path = "http://localhost/server/example_service.lua" -- MUST have ' http:// '


local args = { ... }
assert (args[1], "HEY, gimme a number!")
local DADO =  args[1]

---[=[
local date = {
        soapaction = '',
        soapversion = nil,

        namespace = nil,
        url = script_path,
        method = "date",
        entries = {},
}

print("Obtendo date : ")
local ok, erro_ou_ns, resposta, result = pcall(client.call, date)
        print ("==== Teste ====")
        print ("== ok?", ok)
        print ("== ns:", erro_ou_ns)
        print ("== resposta:", resposta)
        print ("== resultado:", result)
	print_r(result)


local sucessor = {
        -- O CGILua 5.2 não está preparado para gerar cabeçalho content-type: application/soap+xml, que deveria ser o padrão para SOAP 1.2; portanto, estamos usando SOAP 1.1, então é obrigatório definir a SOAPAction
        soapaction = '',
        soapversion = nil,

        namespace = nil,
        url = script_path,
        method = "sucessor",
        entries = {
              { tag = "ant", DADO },
        },
}

print("Obtendo para sucessor ... "..DADO.." ...")
local ok, erro_ou_ns, resposta, result = pcall(client.call, sucessor)
        print ("==== Teste ====")
        print ("== ok?", ok)
        print ("== ns:", erro_ou_ns)
        print ("== resposta:", resposta)
        print ("== resultado:", result)
	print_r(result)
--]=]

local sincos = {
        soapaction = '',
        soapversion = nil,

        namespace = nil,
        url = script_path,
        method = "sincos",
        entries = {
              { tag = "x", DADO },
        },
}

print("Obtendo para sincos ... "..DADO.." ...")
local ok, erro_ou_ns, resposta, result = pcall(client.call, sincos)
        print ("==== Teste ====")
        print ("== ok?", ok)
        print ("== ns:", erro_ou_ns)
        print ("== resposta:", resposta)
        print ("== resultado:", result)
	print_r(result)


