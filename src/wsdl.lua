------------------------------------------------------------------------------
-- LuaSOAP support to WSDL semi-automatic generation.
-- See Copyright Notice in license.html
------------------------------------------------------------------------------

local soap = require"soap"
local strformat = require"string".format
local tconcat = require"table".concat
local qname_patt = "^%g*%:%g*$"

local M = {
	_COPYRIGHT = "Copyright (C) 2015 Kepler Project",
	_DESCRIPTION = "LuaSOAP provides a very simple API that convert Lua tables to and from XML documents",
	_VERSION = "LuaSOAP 4.0 WSDL generation helping functions",
}

-- internal data structure details
-- self.name -- service name
-- self.encoding -- string with XML encoding
-- self.targetNamespace -- target namespace
-- self.otherNamespaces -- optional table with other namespaces
-- self.url
-- self.wsdl -- string with complete WSDL document
-- self.types[..] -- table indexed by numbers (to guarantee the order of type definitions)
-- self.methods[methodName] -- table indexed by strings (each method name)
--	request -- table 
--		name -- string with message request name
--		[..] -- table with parameter definitions
--			name -- string with part name
--			element -- string with type element's name (optional)
--			type -- string with type (simple or complex) name (optional)
--	response -- idem
--	portTypeName -- string with portType name attribute
--	bindingName -- string with binding name attribute
--[=[
-- programador fornece a descrição abaixo:
methods = {
	GetQuote = {
		method = function (...) --[[...]] end,
		request = {
			name = "GetQuoteSoapIn",
			{ name = "parameters", element = "tns:GetQuote" },
		},
		response = {
			name = "GetQuoteSoapOut",
			{ name = "parameters", element = "tns:GetQuoteResponse" },
		},
		portTypeName = "StockQuoteSoap",
		bindingName = "StockQuoteSoap",
	},

}
=> soap.wsdl.generate_wsdl() produz a tabela abaixo e depois, serializa ela, produzindo o documento WSDL final:
{
	{
		tag = "wsdl:message",
		attr = { name = "GetQuoteSoapIn" },
		{
			tag = "wsdl:part",
			attr = { name = "parameters", element = "tns:GetQuote" }
		}
	},
	{
		tag = "wsdl:message",
		attr = { name = "GetQuoteSoapOut" },
		{
			tag = "wsdl:part",
			attr = { name = "parameters", element = "tns:GetQuoteResponse" }
		}
	},
	{
		tag = "wsdl:portType",
		attr = { name = "StockQuoteSoap" },
		{
			tag = "wsdl:operation",
			attr = { name = "GetQuote", parameterOrder = "??" },
			{
				tag = "wsdl:input",
				attr = { message = "tns:GetQuoteSoapIn" },
			},
			{
				tag = "wsdl:output",
				attr = { message = "tns:GetQuoteSoapOut" },
			},
		},
	},
...
}
--]=]

------------------------------------------------------------------------------
------------------------------------------------------------------------------
function M:gen_definitions ()
	return strformat([[
<wsdl:definitions
	xmlns:http="http://schemas.xmlsoap.org/wsdl/http/"
	xmlns:soap="http://schemas.xmlsoap.org/wsdl/soap/"
	xmlns:wsoap12="http://schemas.xmlsoap.org/wsdl/soap12/"
	xmlns:s="http://www.w3.org/2001/XMLSchema"
	xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/"
	xmlns:tns="%s"
	xmlns:mime="http://schemas.xmlsoap.org/wsdl/mime/"
	targetNamespace="%s"
	xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/" %s>]],
	self.targetNamespace, self.targetNamespace, soap.attrs (self.otherNamespaces))
end

------------------------------------------------------------------------------
------------------------------------------------------------------------------
function M:gen_types ()
	if self.types then
		local all_types = {
			tag = "wsdl:types",
		}

		all_types[1] = {
			tag = "s:schema",
			attr = {
				--TODO sempre qualified ??? Como prever?
				elementFormDefault = "qualified",
				targetNamespace = self.targetNamespace,
			},
		}
		for _ , elem in ipairs (self.types) do
			all_types[1][ #all_types[1] + 1] = elem
		end
		return soap.serialize (all_types)
	end

	return ''
end

-----------------------------------------------------------------------------
-----------------------------------------------------------------------------
-- Generate messeges
-- generate one <wsdl:message> element with N <wsdl:part> elements inside it.
-- @param elem Table with message description.
-- @param name String with type of message ("request" or "response").
-- @return String with a <wsdl:message>.

local function gen_message (elem, method_name)
	local message = {	
		tag = "wsdl:message",
		attr = {
			name = assert (elem.name , method_name.." Message MUST have a name!"),
		},
	}
		
	for i=1, #elem do 
	-- pode ter mais de um <wsdl:part> na mesma mensagem 
		message[i] = {
			tag = "wsdl:part",
			attr = {
				name = assert (elem[i].name , method_name.." Message part MUST have a name!"),
			},
		}
		if elem[i].element then
			message[i].attr.element = assert (elem[i].element:match(qname_patt), method_name.." Element must be qualified '"..elem[i].element.."'")
		elseif elem[i].type then
			message[i].attr.type =  assert (elem[i].type:match(qname_patt), method_name.." Type must be qualified '"..elem[i].type.."'")
		else
			error ("Incomplete description: "..method_name.." in "..elem[i].name.." parameters MUST have an 'element' or a 'type' attribute")
		end
	-- pode ter os atributos type E element no mesmo <wsdl:part ...> ???
	-- acho que não, já que o  element se refere a um element em type e o type a um simpletype ou complex type
	end
	return soap.serialize (message)
end

------------------------------------------------------------------------------
-- generate two <wsdl:message> elements for each method.
-- @return String with all <wsdl:message>s.

function M:gen_messages ()
	local m = {}
	for method_name, desc in pairs (self.methods) do
		if desc.request then 
			m[#m+1] = gen_message (desc.request, method_name )
		end		
		if desc.response then 
			m[#m+1] = gen_message (desc.response, method_name )
		end		
		if desc.fault then 
			m[#m+1] = gen_message (desc.fault, method_name )
		end		
		-- Sim, você pode não ter nenhuma mensagem
	end
	return tconcat (m)
end

------------------------------------------------------------------------------
------------------------------------------------------------------------------
-- generate portType

local function gen_portType (desc, method_name)
	local portType = {
		tag = "wsdl:portType",
		attr = {
			name = assert (desc.portTypeName , method_name.." You MUST have a portTypeName!"),
		},
	}

	portType[1] = {
		tag = "wsdl:operation",
		attr = {
			name = method_name,
			--[parameterOrder], why would you need that in Lua?!
		},
	}

	if desc.request then
		portType[1][ #portType[1] + 1] = {
						tag = "wsdl:input",
						attr = { message = (desc.namespace or "tns:")..desc.request.name },
						}	
	end
	if desc.response then
		portType[1][ #portType[1] + 1] = {
						tag = "wsdl:output",
						attr = { message =  (desc.namespace or "tns:")..desc.response.name }, 
						}
	end
	if desc.fault then
		portType[1][ #portType[1] + 1] = {
						tag = "wsdl:fault",
						attr = { 
							name = desc.fault.name,
							message = (desc.namespace or "tns:")..desc.fault.name,
							},
						}
	end

	return soap.serialize (portType)
end

------------------------------------------------------------------------------
-- generate portTypes

function M:gen_portTypes ()
	local p = {}
	for method_name, desc in pairs (self.methods) do
		p[#p+1] = gen_portType (desc, method_name)
	end
	return tconcat (p)
end

------------------------------------------------------------------------------
------------------------------------------------------------------------------
local soap_attr = {
	transport = "http://schemas.xmlsoap.org/soap/http", -- Other URI may be used
	style = "document", --TODO "rpc"
}

local get_attr = {
	verb = "GET",
}

local post_attr = {
	verb = "POST",
}

local binding_tags = {
	[1.1] = { tag = "soap:binding", attr = soap_attr, },
	["1.1"] = { tag = "soap:binding", attr = soap_attr, },
	[1.2] = { tag = "wsoap12:binding", attr = soap_attr, },
	["1.2"] = { tag = "wsoap12:binding", attr = soap_attr, },
	--["GET"] = { tag = "http:binding", attr = get_attr, },
	--["POST"] = { tag = "http:binding", attr = post_attr, },
}

local function gen_binding_mode (mode, desc)
	return binding_tags[mode]
end

------------------------------------------------------------------------------
local operation_tags = {
	[1.1] = { tag = "soap:operation", attr = { soapAction = "To be filled", style = "document"}, }, --TODO "rpc"
	["1.1"] = { tag = "soap:operation", attr = { soapAction = "To be filled", style = "document"}, },
	[1.2] = { tag = "wsoap12:operation", attr = { soapAction = "To be filled", style = "document"}, },
	["1.2"] = { tag = "wsoap12:operation", attr = { soapAction = "To be filled", style = "document"}, },
	--["GET"] = { tag = "http:operation", attr = {}, },
	--["POST"] = { tag = "http:operation", attr = {}, },
}

local function gen_binding_operation (mode, url)
	operation_tags[mode].attr.soapAction = url
	return operation_tags[mode]
end

------------------------------------------------------------------------------
local body_tags = {
	[1.1] = { tag = "soap:body", attr = { use = "literal" }, },
	["1.1"] = { tag = "soap:body", attr = { use = "literal" }, },
	[1.2] = { tag = "wsoap12:body", attr = { use = "literal" }, },
	["1.2"] = { tag = "wsoap12:body", attr = { use = "literal" }, },
	--["GET"] = { tag = "http:binding", attr = {}, },
	--["POST"] = { tag = "http:binding", attr = {}, },
}

local function gen_binding_op_body (mode, desc)
	return body_tags[mode]
end

------------------------------------------------------------------------------
local body_fault_tags = {
	[1.1] = { tag = "soap:body", attr = { name = "To be filled", use = "literal" }, },
	["1.1"] = { tag = "soap:body", attr = { name = "To be filled", use = "literal" }, },
	[1.2] = { tag = "wsoap12:body", attr = { name = "To be filled", use = "literal" }, },
	["1.2"] = { tag = "wsoap12:body", attr = { name = "To be filled", use = "literal" }, },
	--["GET"] = { tag = "http:binding", attr = {}, },
	--["POST"] = { tag = "http:binding", attr = {}, },
}

local function gen_binding_op_body_fault (mode, desc)
	body_fault_tags[mode].attr.name = desc.fault.name
	return body_fault_tags[mode]
end

------------------------------------------------------------------------------
--Generate binding

local function gen_binding (desc, method_name, url, mode)
	local binding = {
		tag = "wsdl:binding",
		attr = {
			name = assert (desc.bindingName..tostring(mode) , method_name.."You MUST have a bindingName!"),
			--TODO Melhorar bindingName
			type = ( desc.namespace or "tns:")..desc.portTypeName,
		},
		[1] = gen_binding_mode(mode, desc)
	}

	binding[2] = {
		tag = "wsdl:operation",
		attr = { name = method_name },
		[1] =  gen_binding_operation (mode, url)
		--TODO Qual URL usar??
	}

	if desc.request then
		binding[2][ #binding[2] +1] = { tag = "wsdl:input",
						[1] = gen_binding_op_body (mode, desc),
						}
end
	if desc.response then
		binding[2][ #binding[2] +1] = { tag = "wsdl:output",
						[1] = gen_binding_op_body (mode, desc),
						}
end
	if desc.fault then
		binding[2][ #binding[2] +1] = { tag = "wsdl:fault",
						[1] = gen_binding_op_body_fault (mode, desc),
						}
	end
	
	return soap.serialize (binding)
end

------------------------------------------------------------------------------
--Generate bindings

function M:gen_bindings ()
	local b = {}
	if type(self.mode) == "table" then
		for _, mode in ipairs(self.mode) do
			for method_name, desc in pairs (self.methods) do
				b[#b+1] = gen_binding (desc, method_name, self.url, mode)
			end
		end
	else
		for method_name, desc in pairs (self.methods) do
			b[#b+1] = gen_binding (desc, method_name, self.url, self.mode)
		end
	end
	return tconcat (b)
	

end

------------------------------------------------------------------------------
------------------------------------------------------------------------------
--Generate port

local address_tags = {
	[1.1] = "soap:address",
	["1.1"] = "soap:address",
	[1.2] = "wsoap12:address",
	["1.2"] = "wsoap12:address",
	--["GET"] = "http:address",
	--["POST"] = "http:address",
}

local function gen_port (desc, url, mode)
	local port = {
		tag = "wsdl:port",
		attr = {
			name = desc.bindingName..tostring(mode),
			--TODO Melhorar bindingName
			binding = (desc.namespace or "tns:")..desc.bindingName..tostring(mode),
		},
		[1] = {
			tag = address_tags[mode],
			attr = { location = url },
		},
	}
	return port
end

------------------------------------------------------------------------------
--Generate service

function M:gen_service ()
	local service = { 
		tag = "wsdl:service",
		attr = {
			name = self.name,
		},
	}
	if type(self.mode) == "table" then
		for _, mode in ipairs(self.mode) do
			for method_name, desc in pairs (self.methods) do
				service[#service+1] = gen_port (desc, self.url, mode)
			end
		end
	else
		for method_name, desc in pairs (self.methods) do
			service[#service+1] = gen_port (desc, self.url, self.mode)
		end
	end
	return soap.serialize (service)
end

------------------------------------------------------------------------------
------------------------------------------------------------------------------
function M:generate_wsdl ()
	if self.wsdl then
		return self.wsdl
	end
	local doc = {}
	doc[1] = self:gen_definitions ()
	doc[2] = self:gen_types ()
	doc[3] = self:gen_messages ()
	doc[4] = self:gen_portTypes ()
	doc[5] = self:gen_bindings ()
	doc[6] = self:gen_service ()
	doc[7] = "</wsdl:definitions>"
	return tconcat (doc)
end

------------------------------------------------------------------------------
return M
