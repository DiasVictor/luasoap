#!/usr/bin/env cgilua.cgi
---------------------------------

local server_address = "http://localhost/server/" -- http?
local aux_types = {
        { tag = "s:element",
                attr = { name = "x", },
                { tag = "s:complexType",
                        { tag = "s:sequence",
                                { tag = "s:element",
                                        attr = {
                                                minOccurs = "0",
                                                maxOccurs = "1",
                                                name = "x",
                                                type = "s:integer",
                                        },
                                },

                        },

                },

        },
        { tag = "s:element",
                attr = { name = "date", },
                { tag = "s:complexType",
                        { tag = "s:sequence",
                                { tag = "s:element",
                                        attr = {
                                                minOccurs = "1",
                                                maxOccurs = "1",
                                                name = "date",
                                                type = "s:string",
                                        },
                                },

                        },

                },

        },
        { tag = "s:element",
                attr = { name = "prox", },
                { tag = "s:complexType",
                        { tag = "s:sequence",
                                { tag = "s:element",
                                        attr = {
                                                minOccurs = "1",
                                                maxOccurs = "1",
                                                name = "prox",
                                                type = "s:integer",
                                        },
                                },

                        },

                },

        },
        { tag = "s:element",
                attr = { name = "sincos", },
                { tag = "s:complexType",
                        { tag = "s:sequence",
                                { tag = "s:element",
                                        attr = {
                                                minOccurs = "1",
                                                maxOccurs = "1",
                                                name = "sin",
                                                type = "s:double",
                                        },
                                },
				{ tag = "s:element",
					attr = {
                                                minOccurs = "1",
                                                maxOccurs = "1",
                                                name = "cos",
                                                type = "s:double",
                                        },
                                }
                        },

                },

        },
}


local server = require"soap.server".new{
    name = "example_service", -- Service Name
    targetNamespace = server_address, 
--  url = server_address.."path/virtual/objeto.lua", --TODO URL do objeto que oferece o serviço
    url = server_address.."example_service.lua",

    mode = { 1.2, 1.1, }, -- opcional: default == { 1.2 }
    types = aux_types,
}


server:export {
    name = "date", -- Method identifier
    method = function (namespace, args) 
		return { { tag = 'date', tostring(os.date('%c')) } } -- you must return a table, preferably a LOM table
	end,
    response = {
		name = nil, -- default == desc.name.."SoapOut"
		{ name = "date", type = "s:string", },
	},
    portTypeName = nil, -- default == name.."Soap"
    bindingName = nil, -- default == name.."Soap"
}

server:export {
    name = "sucessor", -- Method identifier
    method = function (namespace, args)
		local x = args[1][1] -- args is a LOM table that comes with the request data
		if x then
			return { { tag = 'prox', x+1 } }
		end
		return { { tag = 'prox', '' } }
	end,
    request = { { name = "x", type = "tns:x", }, },
    response = { { name = "prox", type = "tns:prox", }, },
}

server:export {
    name = "sincos", -- Method identifier
    method = function (namespace, args)
	local x = args[1][1]
        return {
		{ tag = "sin", math.sin(x) },
		{ tag = "cos", math.cos(x) },
        }
    end,
    namespace = nil, -- default == "tns:, you can use this if you have a diferent namespace
    request = {
        name = nil, -- default == desc.name.."SoapIn"
        { name = "x", type = "s:double", },
    },
    response = {
        name = nil, -- default == desc.name.."SoapOut"
	{ name = "result", type = "tns:sincos", },
--[=[
        { name = "sin", type = "s:double", },
        { name = "cos", type = "s:double", },
--]=]
    }, 
--  fault = { }, -- equivalente ao request
    portTypeName = nil, -- default == name.."Soap"
    bindingName = nil, -- default == name.."Soap"
}



server:handle_request(cgilua.POST[1], cgilua.servervariable("QUERY_STRING"))

