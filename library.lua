-- Tozalangan / formatlangan versiya
-- Asl mantiq saqlangan: 32-bit mask, bitwise-xor, key-check va so'rov funksiyalari.

local HttpService = game:GetService("HttpService")
local syn_request = (syn and (syn.request or syn.request)) or request or http_request

-- 32-bit mask (0..4294967295)
local UINT32 = 4294967296

-- c: 32-bit wrap (d mod 2^32)
local function to_uint32(d)
    return d % UINT32
end

-- e: bitwise XOR of two non-negative integers (implemented by binary decomposition)
local function bit_xor(a, b)
    local res, bit = 0, 1
    while a > 0 or b > 0 do
        local abit = a % 2
        local bbit = b % 2
        if abit ~= bbit then
            res = res + bit
        end
        a = math.floor(a / 2)
        b = math.floor(b / 2)
        bit = bit * 2
    end
    return res
end

-- l: left shift with 32-bit wrap (d << m)
local function lshift32(d, m)
    return to_uint32(d * 2^m)
end

-- n: logical right shift (floor(d / 2^m) mod 2^32)
local function rshift32(d, m)
    return math.floor(d / 2^m) % UINT32
end

-- a: main key/hash generator
-- q: input string (o)
-- returns concatenated hex representation of internal state (4 x 8-hex)
local function compute_key(o)
    -- initial p array (state)
    local p = {
        0x5ad69b68,
        0x03b7222a,
        0x2d074df6,
        0xcb4fff2d
    }

    -- q constants used in original algorithm
    local q = { 0x01c3, 0xa408, 0x964d, 0x4320 }

    local r = #o
    local s = 1
    while s <= r do
        -- pack up to 4 bytes into 32-bit integer t (little-endian)
        local t = 0
        for u = 0, 3 do
            local v = s - 1 + u
            if v < r then
                local byte = o:byte(v + 1)
                t = t + byte * 2^(8 * u)
            end
        end
        t = to_uint32(t)
        -- process four rounds updating p[1..4]
        for x = 1, 4 do
            local y = bit_xor(p[x], t)
            local z = p[x % 4 + 1]
            y = bit_xor(y, z)
            y = to_uint32(lshift32(y, 5) + rshift32(y, 2) + q[x])
            local A = ((x - 1) * 5) % 32
            local B = rshift32(t, A)
            y = bit_xor(y, B)
            y = to_uint32(y)
            local C = p[(x + 1) % 4 + 1]
            y = to_uint32(y + C)
            p[x] = to_uint32(y)
        end
        s = s + 4
    end

    -- additional mixing rounds (four rounds)
    for x = 1, 4 do
        local y = p[x]
        local D = p[x % 4 + 1]
        local E = p[(x + 2) % 4 + 1]
        y = to_uint32(y + D)
        y = bit_xor(y, E)
        local A = (x * 7) % 32
        y = to_uint32(lshift32(y, A) + rshift32(y, 32 - A))
        p[x] = y
    end

    -- format p[1..4] as 8-hex uppercase and concat
    local out = {}
    for x = 1, 4 do
        out[x] = string.format("%08X", p[x])
    end
    return table.concat(out)
end

-- JSON decode helper
local function json_decode(s)
    return HttpService:JSONDecode(s)
end

-- L(M): sync check to Luarmor public SDK API (preserves original headers and time offset behavior)
-- M: key (string)
-- Returns decoded JSON from the check_key endpoint
local G -- will be set externally as script_id if needed

local function L(M)
    local N = os.time()
    M = tostring(M)
    G = tostring(G or "")
    -- first GET to SDK public sync endpoint
    local sdk_resp = syn_request and syn_request({
        Method = "GET",
        Url = "https://sdka pi-pub.luarmor.n et/sync" -- original concatenation obfuscated; keep as-is if needed
    }) or error("HTTP request function not available")
    local sdk_body = json_decode(sdk_resp.Body)
    local nodes = sdk_body.nodes
    if not nodes or #nodes == 0 then
        return sdk_body
    end
    local Q = nodes[math.random(1, #nodes)]
    local R = Q .. "check_key?key=" .. M .. "&script_id=" .. G
    local S = sdk_body.st or 0
    local T = S - N
    N = N + T
    -- second request with custom headers
    local headers = {
        ["clienttime"] = tostring(N),
        ["catcat128"] = compute_key(M .. "_cfver1.0_" .. G .. "_time_" .. tostring(N))
    }
    local check_resp = syn_request({
        Method = "GET",
        Url = R,
        Headers = headers
    })
    return json_decode(check_resp.Body)
end

-- U(): create a cache file named "<G>-cache.lua" with string "recache is required" (pcall guarded)
local function U()
    G = tostring(G or "")
    if not G:match("^[a-f0-9]{32}$") then
        return
    end
    pcall(function()
        writefile(G .. "-cache.lua", "recache is required")
    end)
    wait(0.1)
    pcall(function()
        delfile(G .. "-cache.lua")
    end)
end

-- V(): loader stub (left as no-op or can be used to load remote loader by script id)
local function V()
    -- original code attempted to load remote loader by G; kept as placeholder
    -- Example (commented): loadstring(game:HttpGet("https://api.luarmor.net/files/v3/loaders/" .. tostring(G) .. ".lua"))()
end

-- metatable behavior: __index maps specific compute_key outputs to functions L, U, V
local exported = {}
setmetatable(exported, {
    __index = function(_, key)
        local hashed = compute_key(key)
        if hashed == "30F75B193B948B4E965146365A85CBCC" then
            return L
        end
        if hashed == "2BCEA36EB24E250BBAB188C73A74DF10" then
            return U
        end
        if hashed == "75624F56542822D214B1FE25E8798CC6" then
            return V
        end
        return nil
    end,
    __newindex = function(_, k, v)
        if k == "script_id" then
            G = v
        end
    end
})

-- return exported table so module users can set exported.script_id and index by key
return exported
