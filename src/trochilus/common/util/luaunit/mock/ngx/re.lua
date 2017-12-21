local ffi = require "ffi"
local C = ffi.C

local FLAG_DFA           = 0x02
local FLAG_DUPNAMES      = 0x08
local FLAG_NO_UTF8_CHECK = 0x10

local PCRE_CASELESS          = 0x00000001
local PCRE_MULTILINE         = 0x00000002
local PCRE_DOTALL            = 0x00000004
local PCRE_EXTENDED          = 0x00000008
local PCRE_ANCHORED          = 0x00000010
local PCRE_UTF8              = 0x00000800
local PCRE_NO_UTF8_CHECK     = 0x00002000
local PCRE_DUPNAMES          = 0x00080000
local PCRE_JAVASCRIPT_COMPAT = 0x02000000

local PCRE_INFO_CAPTURECOUNT  = 2
local PCRE_INFO_NAMEENTRYSIZE = 7
local PCRE_INFO_NAMECOUNT     = 8
local PCRE_INFO_NAMETABLE     = 9

local PCRE_ERROR_NOMATCH = -1

ffi.cdef[[
void* pcre_compile(const char*, int, const char**, int*, const unsigned char*);
int pcre_fullinfo(const void*, const void*, int, void*);
int pcre_dfa_exec(const void*, const void*, const char*, int, int, int, int*, int, int*, int);
int pcre_exec(const void*, const void*, const char*, int, int, int, int *, int);
]]
local pcre_lib = ffi.load("/usr/lib/x86_64-linux-gnu/libpcre.so")

-------------
-- match/find
-------------

local OPTS_MAP = {
    o = {}, j = {}, i = {PCRE_CASELESS}, s = {PCRE_DOTALL}, m = {PCRE_MULTILINE}, u = {PCRE_UTF8},
    U = {PCRE_UTF8, FLAG_NO_UTF8_CHECK}, x = {PCRE_EXTENDED}, d = {nil, FLAG_DFA}, a = {PCRE_ANCHORED},
    D = {PCRE_DUPNAMES, FLAG_DUPNAMES}, J = {PCRE_JAVASCRIPT_COMPAT}
}
local parse_opts = function(opts)
    local flags = 0
    local pcre_opts = 0
    for i = 1, #opts do
        local opt = string.sub(opts, i, i)
        local m = OPTS_MAP[opt]
        if not m then return error(string.format("unknown flag: %s", opt)) end
        if m[1] then pcre_opts = bit.bor(pcre_opts, m[1]) end
        if m[2] then flags = bit.bor(flags, m[2]) end
    end
    return flags, pcre_opts
end

local compile_pattern_int = function(pattern, opts)
    local errbuf = ffi.new("const char*[1]")
    local erroff = ffi.new("int[1]")
    local pcre = pcre_lib.pcre_compile(pattern, opts, errbuf, erroff, nil)

    if not pcre then
        errbuf = ffi.string(errbuf[0])
        erroff = erroff[0]
        if erroff == #pattern then
            return nil, nil, string.format('pcre_compile failed: %s in "%s"', errbuf, pattern)
        else
            return nil, nil, string.format('pcre_compile failed: %s in "%s" at %s',
                errbuf, pattern, string.sub(pattern, erroff + 1))
        end
    end

    local cap_count = ffi.new("int[1]")
    local rc = pcre_lib.pcre_fullinfo(pcre, nil, PCRE_INFO_CAPTURECOUNT, cap_count);
    if rc < 0 then return nil, nil, string.format("pcre_fullinfo failed: %s", rc) end
    return pcre, cap_count[0]
end

local compile_pattern = function(pattern, flags, pcre_opts)
    local pcre, cap_count, err = compile_pattern_int(pattern, pcre_opts)
    if not pcre then return nil, err end
    local out = {
        pattern = pattern,
        pcre = pcre,
        cap_count = cap_count,
        name_entry_size = 0
    }

    local name_count = ffi.new("int[1]")
    if pcre_lib.pcre_fullinfo(pcre, nil, PCRE_INFO_NAMECOUNT, name_count) ~= 0 then
         return nil, "failed to acquire named subpattern count"
    end
    out.name_count = name_count[0]

    if out.name_count > 0 then
        local name_entry_size = ffi.new("int[1]")
        if (pcre_lib.pcre_fullinfo(pcre, nil, PCRE_INFO_NAMEENTRYSIZE, name_entry_size) ~= 0) then
            return nil, "failed to acquire named subpattern entry size"
        end
        out.name_entry_size = name_entry_size[0]

        local name_table = ffi.new("char*[1]")
        if (pcre_lib.pcre_fullinfo(pcre, nil, PCRE_INFO_NAMETABLE, name_table) ~= 0) then
            return nil, "failed to acquire named subpattern table"
        end
        out.name_table = name_table[0]
    end
    return out
end

local exec_regex = function(compiled, flags, subject, ctx)
    local pos = 0
    if ctx then
        pos = ctx.pos
        pos = (((not pos) or (pos <= 0)) and 0) or (pos - 1)
    end
    local exec_opts = (bit.band(flags, FLAG_NO_UTF8_CHECK) ~= 0 and PCRE_NO_UTF8_CHECK) or 0

    local rc, caps
    if bit.band(flags, FLAG_DFA) ~= 0 then
        caps = ffi.new("int[2]")
        local ws = ffi.new("int[100]")
        rc = pcre_lib.pcre_dfa_exec(compiled.pcre, nil, subject, #subject, pos, exec_opts, caps, 2, ws, 100)
    else
        local ovecsize = (compiled.cap_count + 1) * 3
        caps = ffi.new("int[?]", ovecsize)
        rc = pcre_lib.pcre_exec(compiled.pcre, nil, subject, #subject, pos, exec_opts, caps, ovecsize)
    end
    compiled.caps = caps

    if rc < 0 then
        if rc == PCRE_ERROR_NOMATCH then return nil end
        return nil, "pcre_exec failed: " .. rc
    end
    if rc == 0 then
        if bit.band(flags, FLAG_DFA) == 0 then return nil, "insufficiant capture size" end
        rc = 1
    end

    if ctx then
        ctx.pos = compiled.caps[1] + 1
    end
    return rc
end

local collect_capture_numbers = function(compiled, rc, nth)
    if not nth or nth < 0 then nth = 0 end
    if nth > compiled.cap_count then return nil, "nth out of bound" end
    if nth >= rc then return nil end

    local from = compiled.caps[nth * 2] + 1
    local to = compiled.caps[nth * 2 + 1]
    if from < 0 or to < 0 then return nil end
    return {from, to}
end

local collect_named_captures = function(compiled, flags, res)
    local name_table = compiled.name_table
    local dup_names = (bit.band(flags, FLAG_DUPNAMES) ~= 0)
    local idx = 0
    for i = 1, compiled.name_count do
        local n = bit.bor(bit.lshift(name_table[idx], 8), name_table[idx + 1])
        local name = ffi.string(name_table + idx + 2)
        local res_n = res[n]
        if dup_names then
            if res_n then
                local res_name = res[name]
                if res_name then
                    res[name][#res_name + 1] = res_n
                else
                    res[name] = {res_n}
                end
            end
        else
            res[name] = res_n
        end
        idx = idx + compiled.name_entry_size
    end
end

local collect_captures = function(compiled, rc, subject, flags, res)
    if not res then res = {} end
    local i, n = 0, 0
    while i <= compiled.cap_count do
        if i > rc then
            res[i] = false
        else
            local from = compiled.caps[n]
            if from >= 0 then
                res[i] = string.sub(subject, from + 1, compiled.caps[n + 1])
            else
                res[i] = false
            end
        end
        i = i + 1
        n = n + 2
    end

    if compiled.name_count > 0 then
        collect_named_captures(compiled, flags, res)
    end
    return res
end

local re_match_ex = function(subject, pattern, opts, ctx, return_caps, arg)
    subject = tostring(subject)
    local flags, pcre_opts = 0, 0
    if opts then flags, pcre_opts = parse_opts(opts) end
    local compiled, err = compile_pattern(pattern, flags, pcre_opts)
    if not compiled then return nil, err end

    local rc, err = exec_regex(compiled, flags, subject, ctx)
    if not rc then return nil, err end
    if not return_caps then return collect_capture_numbers(compiled, rc, arg) end
    return collect_captures(compiled, rc, subject, flags, arg)
end

-----------
-- sub/gsub
-----------

local copy_cb = function(code, se)
    se.parts[#se.parts + 1] = code[2]
end
local cap_cb = function(code, se)
    if code[2] < se.n_cap then
        se.parts[#se.parts + 1] = string.sub(se.subject, se.caps[code[2]] + 1, se.caps[code[2] + 1])
    end
end

local REP_INPUT_DOLLAR, REP_INPUT_LB, REP_INPUT_RB, REP_INPUT_NUM, REP_INPUT_OTHER = 1, 2, 3, 4, 5
local REP_STATE_DOLLAR, REP_STATE_BRACKET, REP_STATE_NUM, REP_STATE_NORMAL, REP_STATE_ERR = 1, 2, 3, 4, 5
local parse_replace = function(replace)
    local i, codes = 1, {}
    local input, state, s = nil, REP_STATE_NORMAL, ""

    while i <= #replace do
        local ch = string.sub(replace, i, i)
        local ch_code = string.byte(ch)
        if ch == "$" then input = REP_INPUT_DOLLAR
        elseif ch == "{" then input = REP_INPUT_LB
        elseif ch == "}" then input = REP_INPUT_RB
        elseif ch_code >= 48 and ch_code <= 57 then input = REP_INPUT_NUM
        else input = REP_INPUT_OTHER end

        if REP_STATE_NORMAL == state then
            if REP_INPUT_DOLLAR == input then
                state = REP_STATE_DOLLAR
                codes[#codes + 1] = {copy_cb, s}
                s = ""
            else
                s = s .. ch
            end
        elseif REP_STATE_DOLLAR == state then
            if REP_INPUT_DOLLAR == input then
                state = REP_STATE_NORMAL
                codes[#codes + 1] = {copy_cb, "$"}
            elseif REP_INPUT_LB == input then
                state = REP_STATE_BRACKET
            elseif REP_INPUT_NUM == input then
                state = REP_STATE_NUM
                s = s .. ch
            else
                state = REP_STATE_ERR
            end
        elseif REP_STATE_BRACKET == state then
            if REP_INPUT_NUM == input then
                s = s .. ch
            elseif REP_INPUT_RB == input then
                if #s > 0 then
                    state = REP_STATE_NORMAL
                    codes[#codes + 1] = {cap_cb, tonumber(s) * 2}
                    s = ""
                else
                    state = REP_STATE_ERR
                end
            else
                state = REP_STATE_ERR
            end
        elseif REP_STATE_NUM == state then
            if REP_INPUT_NUM == input then
                s = s .. ch
            else
                state = REP_STATE_NORMAL
                codes[#codes + 1] = {cap_cb, tonumber(s) * 2}
                s = ch
            end
        end

        if REP_STATE_ERR == state then return nil, "invalid capturing string" end
        i = i + 1
    end

    if REP_STATE_NUM == state then
        codes[#codes + 1] = {cap_cb, tonumber(s) * 2}
    elseif REP_STATE_NORMAL == state then
        codes[#codes + 1] = {copy_cb, s}
    else
        return nil, "invalid capturing string"
    end
    return codes
end

local function re_sub_ex(subject, pattern, replace, opts, global)
    subject = tostring(subject)
    local flags, pcre_opts = 0, 0
    if opts then flags, pcre_opts = parse_opts(opts) end
    local compiled, err = compile_pattern(pattern, flags, pcre_opts)
    if not compiled then return nil, nil, err end

    local rep_is_func = ("function" == type(replace))
    local parts = {}
    local se, codes = {subject = subject, parts = parts}, nil
    if not rep_is_func then
        replace = tostring(replace)
        codes, err = parse_replace(replace)
        if not codes then return nil, nil, err end
    end

    local cnt, pos = 0, 1
    local ctx = {pos = 0}
    while true do
        local rc, err = exec_regex(compiled, flags, subject, ctx)
        if not rc then
            if not err then break end
            return nil, nil, err
        end

        cnt = cnt + 1
        se.n_cap = rc * 2
        se.caps = compiled.caps
        parts[#parts + 1] = string.sub(subject, pos, compiled.caps[0])
        if rep_is_func then
            parts[#parts + 1] = tostring(replace(collect_captures(compiled, rc, subject, flags)))
        else
            for _, code in ipairs(codes) do
                code[1](code, se)
            end
        end

        pos = ctx.pos
        if ctx.pos == compiled.caps[0] + 1 then
            ctx.pos = ctx.pos + 1
            if ctx.pos > #subject + 1 then break end
        end
        if not global then break end
    end

    if cnt > 0 then
        if ctx.pos < #subject + 1 then
            parts[#parts + 1] = string.sub(subject, pos)
        end
        return table.concat(parts), cnt
    end
    return subject, 0
end


local re_match = function(subject, pattern, opts, ctx, res)
    return re_match_ex(subject, pattern, opts, ctx, true, res)
end

local re_find = function(subject, pattern, opts, ctx, nth)
    local res, err = re_match_ex(subject, pattern, opts, ctx, false, nth)
    if not res then return nil, nil, err end
    return res[1], res[2]
end

local re_sub = function(subject, pattern, replace, opts)
    return re_sub_ex(subject, pattern, replace, opts, false)
end

local re_gsub = function(subject, pattern, replace, opts)
    return re_sub_ex(subject, pattern, replace, opts, true)
end

local exports = {}

exports.mixin = function(ngx)
    ngx.re = {}
    ngx.re.match = re_match
    ngx.re.find = re_find
    ngx.re.sub = re_sub
    ngx.re.gsub = re_gsub
end

return exports
