--[[
    Keyboard layout for calculator
]]

local calc_popup = {
   _a_ = {
        "a",
        north = "A",
        northeast = "alpha",
        east = "α",
    },
   _b_ = {
        "b",
        north = "B",
        northeast = "beta",
        east = "β",
    },
   _c_ = {
        "c",
        north = "C",
        northeast = "chi",
        east = "χ",
    },
   _d_ = {
        "d",
        north = "D",
        northeast = "delta",
        east = "δ",
    },
   _e_ = {
        "e",
        north = "E",
        northeast = "epsilon",
        east = "ε",
        west = "exp"
    },
   _f_ = {
        "f",
        north = "F",
        northeast = "phi",
        east = "φ",
    },
   _g_ = {
        "g",
        north = "G",
        northeast = "gamma",
        east = "γ",
    },
   _h_ = {
        "h",
        north = "H",
    },
   _i_ = {
        "i",
        north = "I",
        northeast = "iota",
        east = "ι",
    },
   _j_ = {
        "j",
        north = "J",
    },
   _k_ = {
        "k",
        north = "K",
        northeast = "kappa",
        east = "ϰ",
    },
    _l_ = {
        "l",
        north = "L",
        northeast = "lambda",
        east = "λ",
    },
   _m_ = {
        "m",
        north = "M",
        northeast = "my",
        east = "μ",
    },
   _n_ = {
        "n",
        north = "N",
        northeast = "ny",
        east = "ν",
    },
   _o_ = {
        "o",
        north = "O",
    },
   _p_ = {
        "p",
        north = "P",
        northeast = "pi",
        east = "π",
        northwest = "psi",
        west =  "ψ",
    },
   _q_ = {
        "q",
        north = "Q",
    },
   _r_ = {
        "r",
        north = "R",
        northeast = "rho",
        east = "ρ",
    },
   _s_ = {
        "s",
        north = "S",
        northeast = "sigma",
        east = "σ",
        northwest = "Sigma",
        west = "Σ",
    },
   _t_ = {
        "t",
        north = "T",
        northeast = "tau",
        east = "τ",
        northwest = "thita",
        west= "ϑ"
    },
   _u_ = {
        "u",
        north = "U",
    },
   _v_ = {
        "v",
        north = "V",
    },
   _w_ = {
        "w",
        north = "W",
        northeast = "omega",
        east = "ω",
    },
   _x_ = {
        "x",
        north = "X",
        northeast = "xi",
        east = "ξ",
    },
   _y_ = {
        "y",
        north = "Y",
    },
   _z_ = {
        "z",
        north = "Z",
        northeast = "zeta",
        east = "ζ",
    },
    _eq = {
        "==",
        north = "!=",
        northeast = ">",
        northwest = "<",
        east = ">=",
        west = "<=",
        south = " ",
        southeast = "≥",
        southwest = "≤",
    },
    _vl = {
        "=",
        north = ":=",
        northeast = "-=",
        northwest = "+=",
        east = " ",
        west = " ",
        south = "%=",
        southeast = "/=",
        southwest = "*=",
    },
    _dm = {
        "/",
        north = "%",
    },
    _facTer = {
        "!",
        northeast = "?",
        east = ":",
    },
    _ml = {
        "*",
        northeast = "&",
        east = "&&",
        northwest = "#",
        west = "##",
    },
    _al = {
        "+",
        northeast = "|",
        east = "||",
    },
    _sl = {
        "-",
        northeast = "~",
        east = "~~",
    },
    _Sl = {
        "‒",
        northeast = "~",
        east = "~~",
    },
    _vx = {
        "x",
        northwest = "s",
        north = "t",
        northeast = "u",
        east = "v",
        southeast = "ω",
        south = "α",
        southwest = " ",
        west = "l",
    },
    _vy = {
        "y",
    },
    _vz = {
        "z",
        east = "o",
        west = "i",
    },
}

local _a_ = calc_popup._a_
local _b_ = calc_popup._b_
local _c_ = calc_popup._c_
local _d_ = calc_popup._d_
local _e_ = calc_popup._e_
local _f_ = calc_popup._f_
local _g_ = calc_popup._g_
local _h_ = calc_popup._h_
local _i_ = calc_popup._i_
local _j_ = calc_popup._j_
local _k_ = calc_popup._k_
local _l_ = calc_popup._l_
local _m_ = calc_popup._m_
local _n_ = calc_popup._n_
local _o_ = calc_popup._o_
local _p_ = calc_popup._p_
local _q_ = calc_popup._q_
local _r_ = calc_popup._r_
local _s_ = calc_popup._s_
local _t_ = calc_popup._t_
local _u_ = calc_popup._u_
local _v_ = calc_popup._v_
local _w_ = calc_popup._w_
local _x_ = calc_popup._x_
local _y_ = calc_popup._y_
local _z_ = calc_popup._z_

local _eq = calc_popup._eq
local _vl = calc_popup._vl
local _dm = calc_popup._dm --div/modulo
local _facTer = calc_popup._facTer --factorial, ternary
local _ml = calc_popup._ml --mul/and/nand
local _al = calc_popup._al --add/or
local _sl = calc_popup._sl --sub/xor
local _Sl = calc_popup._Sl --sub/xor
local _vx = calc_popup._vx --variables
local _vy = calc_popup._vy --variables
local _vz = calc_popup._vz --variables

return {
    min_layer = 1,
    max_layer = 4,
    shiftmode_keys = {[""] = true, ["Var"] = true, ["+-*/"] = true, ["xxx"] = true},
    symbolmode_keys = {["OP"] = true, ["Calc"] = true},
    utf8mode_keys = {["🌐"] = true},
    keys = {
        -- first row
        {  --  1      2        3       4
            { _q_,   _facTer,     " ",    "+=", },
            { _w_,   _vx,     " ",    "-=", },
            { _e_,   _vy,     " ",    "*=", },
            { _r_,   _vz,     " ",    "/=", },
            { _t_,   "EE",    " ",    "<<", },
            { _z_,   "(",     " ",    ">>", },
            { _u_,   ")",     " ",    "?", },
            { _i_,   _vl,     " ",    "<", },
            { _o_,   _eq,     " ",    ">", },
        },
        -- second row
        {  --  1      2        3       4
            { _a_,   "π",     " ",    "||", },
            { _s_,   "sin",   " ",    "&&", },
            { _d_,   "cos",   " ",    "##", },
            { _f_,   "tan",   " ",    "~~", },
            { _g_,   "7",     " ",    " ", },
            { _h_,   "8",     " ",    " ", },
            { _j_,   "9",     " ",    ":", },
            { _k_,   _dm,     " ",    "<=", },
            { _l_,   "^",     " ",    ">=", },
        },
        -- third row
        {  --  1      2        3       4
            { _y_,   _e_,     " ",    "|", },
            { _x_,   "asin",  " ",    "&", },
            { _c_,   "acos",  " ",    "#", },
            { _v_,   "atan",  " ",    "~", },
            { _b_,   "4",     " ",    " ", },
            { _n_,   "5",     " ",    " ", },
            { _m_,   "6",     " ",    " ", },
            { "_",   _ml,     " ",    "!=", },
            { _p_,   "√",     " ",    "==", },
        },
        -- fourth row
        {  --  1      2        3       4
            { _al,   "rnd",   " ",    "+", },
            { _sl,   "ln",    " ",    "-", },
            { _ml,   "ld",    " ",    "*", },
            { _dm,   "log",   " ",    "/", },
            { "^",   "1",     " ",    "^", },
            { "(",   "2",     " ",    ",", },
            { ")",   "3",     " ",    "↑", },
            { "ans", _Sl,     " ",    ":=", },
            { label = "",  width = 1.0, bold = false  },  --delete

        },
        -- fifth row
        { --  1      2        3       4
            {"+-*/", "Var", "+-*/",  "xxx", bold = true, },
            { "OP",  "OP",  "Calc",  "Calc", bold = true,},
            { label = "🌐", },
            { " ",    "ans",  " ",    " ", },
            { " ",    "0",    " ",    "~", },
            { " ",    ".",    " ",    "←", },
            { " ",    _sl,    " ",    "↓", },
            { _vl,    _al,    " ",    "→", },
            { label = "⮠",
              "\n",   "\n",   "\n",   "\n",
              width = 1.0,
              bold = true
            },
        },
    },
}
