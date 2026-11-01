local function GetLanguage()
    return locale ~= nil and locale or "zh"
end
local is_chinese = GetLanguage():find("zh") ~= nil

name = is_chinese and "物品栏收藏" or "Inventory Favorites"
description = is_chinese
    and "使用「鼠标中键 + SHIFT」收藏物品栏或背包中的物品到指定格子，物品被移动后自动归位（仅主物品栏）。\n\nCtrl+Shift+Z 清空收藏。"
    or "Use Middle Mouse + SHIFT to favorite items in your inventory or backpack. Favorites auto-restore to their slot (inventory only).\n\nPress Ctrl+Shift+Z to clear all favorites."

author = "salt510"
version = "1.0.0"

dst_compatible = true
dont_starve_compatible = false
reign_of_giants_compatible = false
shipwrecked_compatible = false
hamlet_compatible = false
client_only_mod = true
all_clients_require_mod = false
api_version = 10

icon_atlas = "modicon.xml"
icon = "modicon.tex"

server_filter_tags = {
    "salt510",
    "物品栏收藏",
    "Inventory Favorites",
}

configuration_options = {
    {
        name = "LANGUAGE",
        label = is_chinese and "语言" or "Language",
        options = {
            { description = is_chinese and "英语" or "English", data = "en" },
            { description = is_chinese and "简体中文" or "Chinese (Simplified)", data = "zh" },
        },
        default = is_chinese and "zh" or "en",
    },
}