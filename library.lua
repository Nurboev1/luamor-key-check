-- ModuleScript: ApiModule
local ApiModule = {}

-- Bu yerda sizning "key"lar ro'yxati
local validKeys = {
    ["ABC123"] = true,
    ["XYZ789"] = true,
}

-- Key tekshirish funksiyasi
function ApiModule.check_key(key)
    if validKeys[key] then
        return { code = "KEY_VALID", message = "Key is valid." }
    else
        return { code = "KEY_INVALID", message = "Key is invalid." }
    end
end

return ApiModule
