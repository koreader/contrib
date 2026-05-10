--[[
    Helper functions for formulaparser

    Author: Martin Zwicknagl
    Version: 1.1.0
]]

local angle_convert = 1 -- use 1 for RAD, pi/180 for Deg, pi/200 for Gon

local err_bool_arith = "Arithmetics on boolean?"
local err_bool_comp = "Comparison on boolean?"
local err_mixed_comp = "Mixed comparison!"
local err_no_val = "Value expected!"
local err_a_val = "No value allowed!"
local err_domain = "Domain error!"
local err_bitwise = "Bitoperations only on integer values!"

local ParserHelp = {}

ParserHelp.help_text = [[Help:

random generator is seeded by os.time()

Variables names may start with [_A-Za-z] but not with [0-9]

1.) Variables stored with ":=":
    If you define "b=2,x:=4+b" and then set "b=5", "x" evaluates to 9.
    So you can use the variable like a function.
2.) Variables stored with "=":
    If you define "b=2,x=4+b" and then set "b=5", "x" evaluates to 6

Predefined constants:
    "e"        Euler's number
    "pi", "π"  Two pi :)

Predefined var:
    "ans"   42

The following operators are supported with increasing priority:
    ","  sequential
    ":=" store tree
    "+=" increase evaluated value by
    "-=" decrease evaluated value by
    "*=" multiply evaluated value by
    "/=" divide evaluated value by
    "="  store evaluated value,
    "?:" ternary like in C
    "&&" logical and, the lua way
    "||" logical or, the lua way
    "##" logical nand, the lua way, -> logical not
    "~~" logical nand, the lua way
    "&"  bitwise and
    "|"  bitwise or
    "#"  bitwise nand -> bitwise not
    "~"  bitwise nand
    "<="
    "=="
    ">="
    "!="
    ">"
    "<"
    "+"  sign, add
    "-"  sign, subtract
    "*"  multiply
    "/"  divide
    "%"  modulo
    "^"  power
    "!"  factorial

The following functions are supported:
the angular functions can operate on degree, radiant and gon.

    "(", braces for identity function
    "abs("
    "acos("
    "asin("
    "atan("
    "avg("      average of multiple parameters
    "bug("      show hints for a bug
    "c2k("      Celsius to Kelvin
    "cos("
    "exp("
    "f2k("      Fahrenheit to Kelvin
    "floor("    round down
    "getAngleMode(" Info: degree, radiant, gon; not for calculations
    "k2c("      Kelvin to Celsius
    "k2f("      Kelvin to Fahrenheit
    "kill("     delete a variable
    "ld("       logarithmus dualis
    "ln("       logarithmus naturalis
    "log("      logarithmus decadis
    "rnd("      random
    "rndseed("  randomseed
    "round("    round
    "setdeg(",  set angle mode to degree
    "setgon(",  set angle mode to gon
    "setrad(",  set angle mode to radiant
    "showvars(",  show defined variables
    "sin("
    "sqrt("
    "tan("
    "√("

Examples:
    3+4*5    -> 23
    ld(1024) -> 10
    3<4      -> true
    4!=4     -> false
    x=3>4?1:-1 -> -1, set x=-1
    x=2,y=4  -> 4, set x=2 and y=4
    1>2||2<10&&7 -> 7
]]

ParserHelp.bug_text = [[You have triggered a BUG!
Please report an issue on
https://github.com/zwim/formulaparser
Please note the offending formula and the output of 'showvars()'.
]]

---------------------- additions to math ------------
math.e = math.exp(1)
function math.finite(value)
	if not value then
		return nil
	elseif type(value) == "string" then
		value = tonumber(value)
		if value == nil then return nil end
	elseif type(value) ~= "number" then
		return nil
	else
		local value_str = tostring(value)
		if value_str:find("inf") or value_str:find("nan") then
			return nil
		end
	end
    return true
end
-----------------------------------------------------


function ParserHelp.abs(l)
	if l == nil then
		return nil, err_no_val
	elseif type(l) == "boolean" then
		return nil, err_bool_arith
	end
	return math.abs(l)
end

function ParserHelp.identity(...)
	local retval = {...}
	return retval[#retval]
end

function ParserHelp.acos(l)
	if l == nil then
		return nil, err_no_val
	elseif type(l) == "boolean" then
		return nil, err_bool_arith
	end
	return math.acos(l) / angle_convert
end
function ParserHelp.asin(l)
	if l == nil then
		return nil, err_no_val
	elseif type(l) == "boolean" then
		return nil, err_bool_arith
	end
	return math.asin(l) / angle_convert
end
function ParserHelp.atan(l)
	if l == nil then
		return nil, err_no_val
	elseif type(l) == "boolean" then
		return nil, err_bool_arith
	end
	return math.atan(l) / angle_convert
end

function ParserHelp.cos(l)
	if l == nil then
		return nil, err_no_val
	elseif type(l) == "boolean" then
		return nil, err_bool_arith
	end
	return ParserHelp.sin(l + math.pi/2/angle_convert)
end
function ParserHelp.sin(l)
	if l == nil then
		return nil, err_no_val
	elseif type(l) == "boolean" then
		return nil, err_bool_arith
	end
	--bring to unit circle
	local sign
	local angle
	if l > 0 then
		sign = 1
		angle = l * angle_convert
	else
		sign = -1
		angle = -l * angle_convert
	end
	angle = angle % (2*math.pi) --less error
	if angle >= math.pi then -- bring to 1st or 2nd quadrant
		sign = -sign
		angle = angle - math.pi
	end
	if angle >= math.pi/2 then -- bring to 1st quadrand
		angle = math.pi - angle
	end
	if angle > math.pi/4 then
		return sign * math.cos(angle - math.pi/2)
	else
		return sign * math.sin(angle)
	end
end
function ParserHelp.tan(l)
	if l == nil then
		return nil, err_no_val
	elseif type(l) == "boolean" then
		return nil, err_bool_arith
	end

	if (l * angle_convert) % math.pi == math.pi/2 then
		return 0/0 -- NAN
	end

	return ParserHelp.sin(l) / ParserHelp.cos(l)
end

function ParserHelp.factorial(l, r)
	if l == nil then
		return nil, err_no_val
	elseif type(l) == "boolean" then
		return nil, err_bool_arith
	elseif r then
		return nil, err_a_val
	end
	local x = 1
	for i = 2, l do x = x * i end
	return x
end

function ParserHelp.exp(l)
	if l == nil then
		return nil, err_no_val
	elseif type(l) == "boolean" then
		return nil, err_bool_arith
	end
	return math.exp(l)
end

function ParserHelp.ln(l)
	if l == nil then
		return nil, err_no_val
	elseif type(l) == "boolean" then
		return nil, err_bool_arith
	elseif l <= 0 then
		return nil, err_domain
	end
	return math.log(l)
end
function ParserHelp.log2(l)
	if l == nil then
		return nil, err_no_val
	elseif type(l) == "boolean" then
		return nil, err_bool_arith
	elseif l <= 0 then
		return nil, err_domain
	end
	return math.log(l) / math.log(2)
end
function ParserHelp.log(l)
	if l == nil then
		return nil, err_no_val
	elseif type(l) == "boolean" then
		return nil, err_bool_arith
	elseif l <= 0 then
		return nil, err_domain
	end
	return math.log10(l)
end

function ParserHelp.add(l, r)
	if r == nil then
		return nil, err_no_val
	elseif type(l) == "boolean" or type(r) == "boolean" then
		return nil, err_bool_arith
	elseif l == nil then
		return r
	else
		return l + r
	end
end
function ParserHelp.sub(l, r)
	if r == nil then
		return nil, err_no_val
	elseif type(l) == "boolean" or type(r) == "boolean" then
		return nil, err_bool_arith
	elseif l == nil then
		return -r
	else
		return l - r
	end
end

function ParserHelp.mul(l, r)
	if l == nil or r == nil then
		return nil, err_no_val
	elseif type(l) == "boolean" or type(r) == "boolean" then
		return nil, err_bool_arith
	end
	return l * r
end
function ParserHelp.div(l, r)
	if l == nil or r == nil then
		return nil, err_no_val
	elseif type(l) == "boolean" or type(r) == "boolean" then
		return nil, err_bool_arith
	end
	return l / r
end
function ParserHelp.mod(l, r)
	if l == nil or r == nil then
		return nil, err_no_val
	elseif type(l) == "boolean" or type(r) == "boolean" then
		return nil, err_bool_arith
	end
	return l % r
end

function ParserHelp.pot(l, r)
	if l == nil or r == nil then
		return nil, err_no_val
	elseif type(l) == "boolean" or type(r) == "boolean" then
		return nil, err_bool_arith
	end
	return l ^ r
end

function ParserHelp.floor(l)
	if l == nil then
		return nil, err_no_val
	elseif type(l) == "boolean" then
		return nil, err_bool_arith
	end
	return math.floor(l)
end
function ParserHelp.round(l)
	if l == nil then
		return nil, err_no_val
	elseif type(l) == "boolean" then
		return nil, err_bool_arith
	end
	return math.floor(l + 0.5)
end

function ParserHelp.randomseed(l)
	if l == nil then
		return nil
	elseif type(l) == "boolean" then
		return nil, err_bool_arith
	end
	if l > 0 then
		return math.randomseed(l)
	else
		return math.randomseed(os.clock())
	end
end
function ParserHelp.rnd(l)
	if l == nil then
		return nil
	elseif type(l) == "boolean" then
		return nil, err_bool_arith
	end
	if l > 0 then
		return math.random(0, l)
	else
		return math.random()
	end
end

function ParserHelp.sqrt(l)
	if l == nil then
		return nil, err_no_val
	elseif type(l) == "boolean" then
		return nil, err_bool_arith
	elseif l < 0 then
		return nil, err_domain
	end
	return math.sqrt(l)
end

function ParserHelp.setAngleDeg()
	angle_convert = math.pi / 180
	return angle_convert
end
function ParserHelp.setAngleRad()
	angle_convert = 1
	return angle_convert
end
function ParserHelp.setAngleGon()
	angle_convert = math.pi / 200
	return angle_convert
end
function ParserHelp.getAngleMode()
	if angle_convert == 1 then
		return "radiant"
	elseif angle_convert == math.pi / 180 then
		return "degree"
	else
		return "gon"
	end
end

function ParserHelp.celsius2kelvin(val)
	return val + 273.15
end
function ParserHelp.kelvin2celsius(val)
	return val - 273.15
end
function ParserHelp.fahrenheit2kelvin(val)
	return (val-32) * 5/9 + 273.15
end
function ParserHelp.kelvin2fahrenheit(val)
	return (val-273.15) * 9/5 + 32
end

function ParserHelp.seq(...)
--	if l == nil or r == nil then return nil, err_no_val end --todo
	return {...}
end

-- average
function ParserHelp.avg(...)
	local retval = 0
	for _,v in pairs{...} do
		retval = retval + v
	end
	return retval/#{...}
end

function ParserHelp.ternary(l, m, r)
	if l == nil or m == nil or r == nil then return nil, err_no_val end
	if l then
		return m
	else
		return r
	end
end

function ParserHelp.bitOr(l, r)
	if l == nil or r == nil then return nil, err_no_val end
	if math.floor(l) ~= l or math.floor(r) ~= r then return nil, err_bitwise end
	return bit.bor(l, r)
end
function ParserHelp.bitAnd(l, r)
	if l == nil or r == nil then return nil, err_no_val end
	if math.floor(l) ~= l or math.floor(r) ~= r then return nil, err_bitwise end
	return bit.band(l, r)
end
function ParserHelp.bitNand(l, r)
	if l == nil and r == nil then return nil, err_no_val end
	if l == nil and math.floor(r) == r then
		return bit.bnot(r)
	end
	if math.floor(l) ~= l or math.floor(r) ~= r then return nil, err_bitwise end
	return bit.bnot(bit.band(l, r))
end
function ParserHelp.bitXor(l, r)
	if l == nil or r == nil then return nil, err_no_val end
	if math.floor(l) ~= l or math.floor(r) ~= r then return nil, err_bitwise end
	return bit.bxor(l, r)
end

function ParserHelp.logOr(l, r)
	if l == nil or r == nil then return nil, err_no_val end
	return l or r
end
function ParserHelp.logAnd(l, r)
	if l == nil or r == nil then return nil, err_no_val end
	return l and r
end
function ParserHelp.logNand(l, r)
	if l == nil and r == nil then return nil, err_no_val end
	if l == nil then  return not r end
	return not (l and r)
end
function ParserHelp.logXor(l, r)
	if l == nil or r == nil then return nil, err_no_val end
	return l ~= r
end

function ParserHelp.lt(l, r)
	if l == nil or r == nil then
		return nil
	elseif type(l) == "boolean" or type(r) == "boolean" then
		return nil, err_bool_comp
	end
	return (l < r)
end
function ParserHelp.le(l, r)
	if l == nil or r == nil then
		return nil
	elseif type(l) == "boolean" or type(r) == "boolean" then
		return nil, err_bool_comp
	end
	return (l <= r)
end
function ParserHelp.ge(l, r)
	if l == nil or r == nil then
		return nil
	elseif type(l) == "boolean" or type(r) == "boolean" then
		return nil, err_bool_comp
	end
	return (l >= r)
end
function ParserHelp.gt(l, r)
	if l == nil or r == nil then
		return nil
	elseif type(l) == "boolean" or type(r) == "boolean" then
		return nil, err_bool_comp
	end
	return (l > r)
end
function ParserHelp.ne(l, r)
	if l == nil or r == nil then
		return nil
	elseif type(l) ~= type(r) then
		return nil, err_mixed_comp
	end
	return (l ~= r)
end
function ParserHelp.eq(l, r)
	if l == nil or r == nil then
		return nil
	elseif type(l) ~= type(r) then
		return nil, err_mixed_comp
	end
	return (l == r)
end

ParserHelp.greek = {
	{"α", "alpha"}, {"β", "beta"}, {"γ", "gamma"}, {"δ", "delta"},
	{"ε", "epsilon"}, {"ζ", "zeta"}, {"η", "eta"}, {"ϑ", "thita"},
	{"ι", "iota"}, {"ϰ", "kappa"}, {"λ", "lambda"}, {"μ", "my"}, {"ν", "ny"},
	{"ξ", "xi"}, {"π", "pi"}, {"ρ", "rho"}, {"σ", "sigma"}, {"τ", "tau"},
	{"φ", "phi"}, {"χ", "chi"}, {"ψ", "psi"}, {"ω", "omega"}, {"Σ", "Sigma"}
}

return ParserHelp
