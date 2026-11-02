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
    {
        name = "BORDER_COLOR",
        label = is_chinese and "边框颜色" or "Border Color",
        hover = is_chinese and "收藏物品外圈边框的颜色" or "The color of the favorite item border",
        options = {
            { description = is_chinese and "黄色（默认）" or "Yellow (default)", data = "yellow" },
            { description = is_chinese and "粉色" or "Pink", data = "pink" },
            { description = is_chinese and "蓝色" or "Blue", data = "blue" },
            { description = is_chinese and "绿色" or "Green", data = "green" },
            { description = is_chinese and "紫色" or "Purple", data = "purple" },
            { description = is_chinese and "红色" or "Red", data = "red" },
            { description = is_chinese and "白色" or "White", data = "white" },
            { description = is_chinese and "青色" or "Cyan", data = "cyan" },
        },
        default = "yellow",
    },
    {
        name = "STAR_COLOR",
        label = is_chinese and "星标覆盖颜色" or "Star Cover Color",
        hover = is_chinese
            and "收藏物品星标的颜色（默认黄色底图限制，蓝/紫/白效果较差）"
            or "The color of the favorite star (Default limited by yellow base image; blue/purple/white may look off)",
        options = {
            { description = is_chinese and "黄色（默认）" or "Yellow (default)", data = "yellow" },
            { description = is_chinese and "粉色" or "Pink", data = "pink" },
            { description = is_chinese and "橙色" or "Orange", data = "orange" },
            { description = is_chinese and "红色" or "Red", data = "red" },
            { description = is_chinese and "绿色" or "Green", data = "green" },
            { description = is_chinese and "白色" or "White", data = "white" },
        },
        default = "yellow",
    },
        -- 放在 BORDER_COLOR 和 STAR_COLOR 之后
    {
        name = "BORDER_SIZE",
        label = is_chinese and "边框大小" or "Border Size",
        hover = is_chinese
            and "收藏物品外圈边框的大小"
            or "The size of the favorite item border",
        options = {
            { description = is_chinese and "小" or "Small", data = 0.50 },
            { description = is_chinese and "中（默认）" or "Medium (default)", data = 0.62 },
            { description = is_chinese and "大" or "Large", data = 0.75 },
            { description = is_chinese and "特大" or "Extra Large", data = 0.88 },
        },
        default = 0.62,
    },
    {
        name = "BORDER_ALPHA",
        label = is_chinese and "边框透明度" or "Border Opacity",
        hover = is_chinese
            and "边框的透明程度（越低越透明）"
            or "How transparent the border is (lower = more transparent)",
        options = {
            { description = "50%", data = 0.5 },
            { description = "75%", data = 0.75 },
            { description = is_chinese and "100%（默认）" or "100% (default)", data = 1.0 },
        },
        default = 1.0,
    },
    {
        name = "STAR_SIZE",
        label = is_chinese and "星标大小" or "Star Size",
        hover = is_chinese
            and "收藏星标的大小"
            or "The size of the favorite star",
        options = {
            { description = is_chinese and "小" or "Small", data = 0.7 },
            { description = is_chinese and "中（默认）" or "Medium (default)", data = 0.9 },
            { description = is_chinese and "大" or "Large", data = 1.1 },
        },
        default = 0.9,
    },
    {
        name = "STAR_POS",
        label = is_chinese and "星标位置" or "Star Position",
        hover = is_chinese
            and "星标在槽位中的位置"
            or "Where the star appears in the slot",
        options = {
            { description = is_chinese and "右上（默认）" or "Top-Right (default)", data = "tr" },
            { description = is_chinese and "左上" or "Top-Left", data = "tl" },
            { description = is_chinese and "右下" or "Bottom-Right", data = "br" },
            { description = is_chinese and "左下" or "Bottom-Left", data = "bl" },
        },
        default = "tr",
    },
    {
        name = "SHIFT_HINT",
        label = is_chinese and "Shift 悬停提示" or "Shift Hover Hint",
        hover = is_chinese
            and "按住 Shift 悬停物品时是否显示「收藏」提示。紧凑模式只多一行，关闭后提示框与原版一致"
            or "Whether to show the \"Favorite\" hint when hovering with Shift held. Compact adds only one line; Off restores vanilla tooltip height",
        options = {
            { description = is_chinese and "紧凑（默认）" or "Compact (default)", data = "compact" },
            { description = is_chinese and "关闭" or "Off", data = "off" },
        },
        default = "compact",
    },
    {
        name = "HIDE_STAR",
        label = is_chinese and "隐藏星标（只留边框）" or "Hide Star (Border Only)",
        hover = is_chinese
            and "开启后收藏物品只显示边框，不显示星标。可避免星标遮挡鼠标悬停提示"
            or "When enabled, favorited items show only the border without the star. Prevents the star from blocking mouse hover tooltips",
        options = {
            { description = is_chinese and "关闭" or "Off (default)", data = false },
            { description = is_chinese and "开启（默认）" or "On", data = true },
        },
        default = true,
    },
}