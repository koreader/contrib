--[[ formulaparser

Author: Martin Zwicknagl
Version: 1.1.0
Original version from C# (2006; Martin Zwicknagl)
Converted and optimized for LUA 2021

usage:
*) one time calculation:
    print(Parser:eval("1+2"))
*) some calculations with variables (stored with ":=")
    root = Parser:parse(1+x) -- do the parsing before
    print(Parser:eval(root)) -- evaluate it later
]]

local Parser = {}

local ParserHelp = require("parserhelp")

math.randomseed(os.time())

-- thanks and see: http://notebook.kulchenko.com/algorithms/alphanumeric-natural-sorting-for-humans-in-lua
local function alphanumsort(o)
   local function conv(s)
      local res, dot = "", ""
      for n, m, c in tostring(s):gmatch"(0*(%d*))(.?)" do
         if n == "" then
            dot, c = "", dot..c
         else
            res = res..(dot == "" and ("%03d%s"):format(#m, m)
				or "."..n)
            dot, c = c:match"(%.?)(.*)"
         end
         res = res..c:gsub(".", "\0%0")
      end
      return res
   end
   table.sort(o,
      function (a, b)
         local ca, cb = conv(a), conv(b)
         return ca < cb or ca == cb and a < b
      end)
   return o
end

function Parser.bug()
	return ParserHelp.bug_text
end

function Parser.help()
	return ParserHelp.help_text
end

function Parser.setVar(var, node)
	Parser.vars[var] = node
end

function Parser.getVar(var)
	local ret = Parser.vars[var]
	if ret then
		return ret
	else
		return nil, "Variable '" .. var .. "' not defined"
	end
end

function Parser:showvars()
	local ret = {}
	local var_str
	for name, content in pairs(Parser.vars) do
		if content.val then
			var_str = name .. "=" .. content.val
		else
			var_str = name .. ":=" .. Parser:eval(content)
		end
		if content.comment then
			var_str = var_str .. " " ..content.comment .. "\n"
		else
			var_str = var_str .. "\n"
		end
		table.insert(ret, var_str)
	end
--	table.sort(ret, function(a,b) return a:lower() < b:lower() end)
	alphanumsort(ret)
	return table.concat(ret), nil
end

function Parser.kill(var)
	if not var then
		Parser.vars = {}
		return true
	elseif Parser.vars[var] then
		Parser.vars[var] = nil
		return true
	end
	return false
end

function Parser.storeTree(l, r, comment)
	if l == nil or r == nil then return nil, "Nothing to store" end
	r.comment = comment
	Parser.setVar(l, r)
	return Parser:_eval(r)
end

function Parser.storeVal(l, r, comment)
	if l == nil or type(l) ~= "string" then return nil, "No variable" end
	local rval, err
	rval, err = Parser:_eval(r)
	if not rval or err then return nil, err or "Value expected" end
	local ret = {val = rval, comment = comment}
	Parser.setVar(l, ret)
	return rval
end

function Parser.incVal(l, r)
	if l == nil or type(l) ~= "string" then return nil, "No variable" end
	local val, rval, err
	val, err = Parser:_eval(Parser.getVar(l))
	if not val or err then return val, err or "Value expected" end
	rval, err = Parser:_eval(r)
	if not rval or err then return nil, err or "Value expected" end
	val = val + rval
	local ret = {val = val}
	Parser.setVar(l, ret)
	return val
end

function Parser.decVal(l, r)
	if l == nil or type(l) ~= "string" then return nil, "No variable" end
	local val, rval, err
	val, err = Parser:_eval(Parser.getVar(l))
	if not val or err then return val, err or "Value expected" end
	rval, err = Parser:_eval(r)
	if not rval or err then return nil, err or "Value expected" end
	val = val - rval
	local ret = {val = val}
	Parser.setVar(l, ret)
	return val
end

function Parser.mulVal(l, r)
	if l == nil or type(l) ~= "string" then return nil, "No variable" end
	local val, rval, err
	val, err = Parser:_eval(Parser.getVar(l))
	if not val or err then return nil, err or "Value expected" end
	rval, err = Parser:_eval(r)
	if not rval or err then return nil, err or "Value expected" end
	val = val * rval
	local ret = {val = val}
	Parser.setVar(l, ret)
	return val
end

function Parser.divVal(l, r)
	if l == nil or type(l) ~= "string" then return nil, "No variable" end
	local val, rval, err
	val, err = Parser:_eval(Parser.getVar(l))
	if not val or err then return nil, err or "Value expected" end
	rval, err = Parser:_eval(r)
	if not rval or err then return nil, err or "Value expected" end
	val = val / rval
	local ret = {val = val}
	Parser.setVar(l, ret)
	return val
end

function Parser.modVal(l, r)
	if l == nil or type(l) ~= "string" then return nil, "No variable" end
	local val, rval, err
	val, err = Parser:_eval(Parser.getVar(l))
	if not val or err then return nil, err or "Value expected" end
	rval, err = Parser:_eval(r)
	if not rval or err then return nil, err or "Value expected" end
	val = val % rval
	local ret = {val = val}
	Parser.setVar(l, ret)
	return val
end

Parser.functions = { -- must be sorted alphabetically
	{"(", ParserHelp.identity},
	{"abs(", ParserHelp.abs},
	{"acos(", ParserHelp.acos},
	{"asin(", ParserHelp.asin},
	{"atan(", ParserHelp.atan},
	{"avg(", ParserHelp.avg},
	{"bug(", ParserHelp.bug},
	{"c2k(", ParserHelp.celsius2kelvin},
	{"cos(", ParserHelp.cos},
	{"eval(", ParserHelp.eval},
	{"exp(", ParserHelp.exp},
	{"f2k(", ParserHelp.fahrenheit2kelvin},
	{"floor(", ParserHelp.floor},
	{"getAngleMode(", ParserHelp.getAngleMode},
	{"help(", Parser.help},
	{"k2c(", ParserHelp.kelvin2celsius},
	{"k2f(", ParserHelp.kelvin2fahrenheit},
	{"kill(", Parser.kill},
	{"ld(", ParserHelp.log2},
	{"ln(", ParserHelp.ln},
	{"log(", ParserHelp.log},
	{"rnd(", ParserHelp.rnd},
	{"rndseed(", ParserHelp.randomseed},
	{"round(", ParserHelp.round},
	{"setdeg(", ParserHelp.setAngleDeg}, -- degree
	{"setgon(", ParserHelp.setAngleGon}, -- gon
	{"setrad(", ParserHelp.setAngleRad}, -- radiant
	{"showvars(", Parser.showvars},
	{"sin(", ParserHelp.sin},
	{"sqrt(", ParserHelp.sqrt},
	{"tan(", ParserHelp.tan},
}

Parser.operators = { -- must be sorted by priority, least priority first
	-- operator, function, prio, right_assoziative=1 (ternary =-1, other values left)
	{",", ParserHelp.seq, 0, 0},
	{":=", Parser.storeTree, 1, 1},
	{"+=", Parser.incVal, 1, 1},
	{"-=", Parser.decVal, 1, 1},
	{"*=", Parser.mulVal, 1, 1},
	{"/=", Parser.divVal, 1, 1},
	{"%=", Parser.modVal, 1, 1},
	{"=", Parser.storeVal, 1, 1},
	{"?:", ParserHelp.ternary, 2, -1},
	{"||", ParserHelp.logOr, 3, 0},
	{"&&", ParserHelp.logAnd, 4, 0},
	{"##", ParserHelp.logNand, 4, 0},
	{"~~", ParserHelp.logXor, 4, 0},
	{"|", ParserHelp.bitOr, 3, 0},
	{"&", ParserHelp.bitAnd, 4, 0},
	{"#", ParserHelp.bitNand, 4, 0},
	{"~", ParserHelp.bitXor, 4, 0},
	{"==", ParserHelp.eq, 8, 0},
	{"!=", ParserHelp.ne, 8, 0},
	{"<=", ParserHelp.le, 9, 0},
	{">=", ParserHelp.ge, 9, 0},
	{">", ParserHelp.gt, 9, 0},
	{"<", ParserHelp.lt, 9, 0},
	{"+", ParserHelp.add, 11, 0},
	{"-", ParserHelp.sub, 11, 0}, -- "-" sign
	{"*", ParserHelp.mul, 12, 0},
	{"/", ParserHelp.div, 12, 0},
	{"%", ParserHelp.mod, 12, 0},
	{"^", ParserHelp.pot, 13, 0},
	{"!", ParserHelp.factorial, 14, 0}
}

--[[ data structure used for a node
local Node = {
	left = nil,
	mid = nil,
	right = nil,
	op = nil,
	val = nil,
	name = nil,
	assoz = nil,
	comment = nil,
}
]]

Parser.vars = {ans = {val = 42}} -- predefine one variable

function Parser:parse(str)
	local pos = str:find("%/%/.*$") or str:find("%/%*.*%*%/")
	local comment
	if pos then
		comment = str:sub(pos)
	end
	str = str:gsub("%/%*.*%*%/", "") -- remove comments
	str = str:gsub("%/%/.*$", "") -- remove comments
	str = str:gsub("%s+", "") -- remove whitespaces
	str = str:gsub("‒", "-") -- replace emdash with minus
	str = str:gsub("π", "pi") -- replace pi
	str = str:gsub("√", "sqrt") -- replace sqrt
	local ret = self:_parse(str)
	if ret then
		ret.comment = comment
	end
	return ret
end

function Parser:_parse(str)
	if not str or str:len() == 0 then
		return {}
	end

	-- do this first, heuristically, we have many numbers
	local value = tonumber(str)
	if value then
		return {val = value}
	end

	local i = 1
	local number_of_operators = #self.operators
	while i <= number_of_operators do
		local same_priority = {}
		local op
		repeat
			op = self.operators[i]
			local opPos, opPos2
			if op[4] == -1 then
				opPos, opPos2 = self.ternaryOperator(str, op[1])
			else
				opPos = self.basicOperator(str, op[1], op[4])
			end
			if opPos then table.insert(same_priority, {opPos, opPos2, i}) end
			i = i + 1
		until (i > number_of_operators or self.operators[i - 1][3] ~=
						self.operators[i][3])
		if same_priority[1] then
			if op[4] == 1 then
				table.sort(same_priority, function(a, b) return a[1] < b[1] end)
			else
				table.sort(same_priority, function(a, b) return a[1] > b[1] end)
			end
			local opPos1 = same_priority[1][1]
			local opPos2 = same_priority[1][2]
			local operator = self.operators[same_priority[1][3]]
			local operator_name = operator[1]
			local func = operator[2]
			local assoz = operator[4]
			local left_string = str:sub(1, opPos1 - 1)
			local left = Parser:_parse(left_string)
			local mid_string, right_string
			local mid, right
			if opPos2 then
				mid_string = str:sub(opPos1 + 1, opPos2 - 1)
				mid = Parser:_parse(mid_string)
				right_string = str:sub(opPos2 + 1)
			else
				right_string = str:sub(opPos1 + operator_name:len())
			end
			right = Parser:_parse(right_string)
			return {
				func = func,
				assoz = assoz,
				left = left,
				mid = mid,
				right = right
			}
		end
	end

	-- find function
	if str:find("%(") then -- only search for functions if the is a brace in str
		local lBracket
		local rBracket
		local left = 1
		local right = #self.functions
		while left <= right do
			local mid = math.floor((left + right) / 2)
			local functionName = self.functions[mid][1]
			local functionNameLen = functionName:len()
			local strStart = str:sub(1, functionNameLen)
			if functionName == strStart then
				local bracketLevel = 1
				lBracket = functionNameLen
				for j = lBracket + 1, str:len() do
					if bracketLevel == 0 then
						break
					end
					rBracket = j
					local nextChar = str:sub(rBracket, rBracket)
					if nextChar == ")" then
						bracketLevel = bracketLevel - 1
					elseif nextChar == "(" then
						bracketLevel = bracketLevel + 1
					end
				end
				if rBracket == str:len() then
					return {
						func = self.functions[mid][2],
						left = Parser:_parse(str:sub(lBracket + 1, rBracket - 1))
					}
				end
				break
			elseif functionName < strStart then
				left = mid + 1
			else
				right = mid - 1
			end
		end -- for
	end

	-- find value
	--[[ -- whe have done the number check at the beginning (for speed reasons)
    if value then
        return {
            val = value,
        }
 ]]
	if str == "e" then
		return {val = math.e}
	elseif str == "pi" then
		return {val = math.pi}
	elseif str == "true" then
		return {val = true}
	elseif str == "false" then
		return {val = false}
	end

	-- if we come here, it must be a variable
	local _, var = str:gsub("^[%a_]", "")
	if var ~= 0 then
		return {name = str}
	else -- here we have e.g. 5x or 3(2+3) -> split it in 5*x or 3*(2+3)
		local ins_pos = str:find("[%a_(]")
		local alpha_num = ins_pos and
						                  str:sub(ins_pos - 1, ins_pos - 1):gsub("[^%a^%d]", "")
		if ins_pos and alpha_num ~= "" then
			str = str:sub(1, ins_pos - 1) .. "*" .. str:sub(ins_pos)
			return self:_parse(str)
		else
			return nil, "Syntax error"
		end
	end
end

function Parser.basicOperator(str, operator, right)
	if not str:find("%" .. operator) then return end -- quick check, lua find is faster than lua code

	local bracketLevel = 0
	local opLen = operator:len()
	local str_len = str:len()

	local opPos;
	-- now search for binary operators
	if right == 1 then
		opPos = 0
		repeat
			local charRight
			local charLeft
			opPos = opPos + 1
			while (opPos < str_len and
							(str:sub(opPos, opPos) == "(" or bracketLevel ~= 0)) do
				if str:sub(opPos, opPos) == "(" then
					bracketLevel = bracketLevel + 1
				elseif str:sub(opPos, opPos) == ")" then
					bracketLevel = bracketLevel - 1
				end
				opPos = opPos + 1
			end
			charRight = str:sub(opPos + opLen, opPos + opLen)
			charLeft = str:sub(opPos - 1, opPos - 1)
		until ((opPos > str_len or str:sub(opPos, opPos + opLen - 1) == operator)
			and (charRight ~= "=" -- do this because "=" has higher priority than e.g. ">="
			and charLeft ~= "<" and charLeft ~= ">" and charLeft ~= "=" and charLeft ~=	"!"))
	else
		opPos = str_len + 1
		repeat
			opPos = opPos - 1
			local charRight
			local charLeft
			while (opPos > 0 and (str:sub(opPos, opPos) == ")" or bracketLevel ~= 0)) do
				if str:sub(opPos, opPos) == ")" then
					bracketLevel = bracketLevel + 1
				elseif str:sub(opPos, opPos) == "(" then
					bracketLevel = bracketLevel - 1
				end
				opPos = opPos - 1
			end
			local _, isLeftNum = str:sub(1, opPos):gsub("%d%.?[eE][+-]?$", "") -- don't get fucked by 1+e+3 and 1e+3
			charRight = str:sub(opPos + opLen, opPos + opLen)
			charLeft = str:sub(opPos - 1, opPos - 1)
		until ((opPos <= 0 or str:sub(opPos, opPos + opLen - 1) == operator)
			and isLeftNum == 0 and charRight ~= "=" -- do this because "=" has higher priority than e.g. ">="
			and charLeft ~= "<" and charLeft ~= ">" and charLeft ~= "=")
	end

	if opPos > 0 and opPos <= str_len then
		return opPos
	end

	return nil
end

function Parser.ternaryOperator(str, operator)
	if not str:find("%?.*%:") then return nil end -- quick check, lua find is faster than lua code
	local opStart = operator:sub(1, 1)
	local opEnd = operator:sub(2, 2)
	local bracketLevel = 0
	local str_len = str:len()
	local opPos = 0;
	repeat
		opPos = opPos + 1
		while (opPos < str_len and (str:sub(opPos, opPos) == "(" or bracketLevel ~= 0)) do
			if str:sub(opPos, opPos) == "(" then
				bracketLevel = bracketLevel + 1
			elseif str:sub(opPos, opPos) == ")" then
				bracketLevel = bracketLevel - 1
			end
			opPos = opPos + 1
		end
	until (opPos > str_len or str:sub(opPos, opPos) == opStart)

	if opPos <= str_len then
		local opPos1 = opPos
		repeat
			opPos = opPos + 1
			while (opPos < str_len and
							(str:sub(opPos, opPos) == "(" or bracketLevel ~= 0)) do
				if str:sub(opPos, opPos) == "(" then
					bracketLevel = bracketLevel + 1
				elseif str:sub(opPos, opPos) == ")" then
					bracketLevel = bracketLevel - 1
				end
				opPos = opPos + 1
			end
		until (opPos > str_len or str:sub(opPos, opPos) == opEnd)
		if opPos <= str_len then
			return opPos1, opPos
		end
	end
end

-- returns numerical result
function Parser:eval(node, err)
	if err then return nil, err end
	if type(node) == "string" then
		node, err = Parser:parse(node)
	end
	if err then return nil, err end
	local ret
	ret, err = self:_eval(node, err)
	if type(ret) ~= "table" then
		return not err and ret, err
	else
		return not err and ret[#ret], err
	end
end

function Parser:_eval(node, err)
	if not node then return nil, err end

	if node.val ~= nil then return node.val, err end

	if node.func then
		if node.assoz == 1 or node.func == Parser.kill then -- if right-left assoziative
			if node.left then
				return node.func(node.left.name, node.right, node.comment)
			else
				return nil, "wrong variable"
			end
		else
			local left_eval, left_err = self:_eval(node.left) -- evaluated first

			if node.mid then
				local mid_eval, mid_err = self:_eval(node.mid) -- evaluated second
				local right_eval, right_err = self:_eval(node.right) -- evaluated last
				err = left_err or mid_err or right_err or err
				if err then return nil, err end
				return node.func(left_eval, mid_eval, right_eval), err
			else
				local right_eval, right_err
				if node.right then
					right_eval, right_err = self:_eval(node.right) -- evaluated last
				end
				err = left_err or right_err or err
				if err then return nil, err end
				local ret, ret_err
				if type(left_eval) == "table" and type(right_eval) == "table" then
					ret, ret_err = node.func(unpack(left_eval), unpack(right_eval))
				elseif type(left_eval) == "table" and type(right_eval) ~= "table" then
					table.insert(left_eval, right_eval)
					ret, ret_err = node.func(unpack(left_eval))
				elseif type(left_eval) ~= "table" and type(right_eval) == "table" then
					ret, ret_err = node.func(left_eval, unpack(right_eval))
				else
					ret, ret_err = node.func(left_eval, right_eval)
				end

				return ret, ret_err or err
			end
		end
	end

	if node.name and not node.touch then -- variablename
		node.touch = true
		local ret
		ret, err = self:_eval(self.getVar(node.name))
		node.touch = nil
		return ret, err
	elseif node.touch then
		node.touch = nil
		return nil, "Recursive definition detected"
	end

	return nil, err -- todo check if error recognized
end

function Parser:greek2text(str)
	for _, var in pairs(ParserHelp.greek) do
		str = str:gsub(var[1], var[2])
	end
	return str
end

function Parser:text2greek(str)
	for _, var in pairs(ParserHelp.greek) do
		str = str:gsub(var[2], var[1])
		end
	return str
end

return Parser
