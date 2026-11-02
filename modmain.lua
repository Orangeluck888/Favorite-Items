-- 一键 GLOBAL
GLOBAL.setmetatable(env, {
    __index = function(t, k)
        return GLOBAL.rawget(GLOBAL, k)
    end
})

local json = require("json")

local INVENTORY_UPDATE_TIME = 0.2
local HAVE_FAVORITED = false
local FAVORITED_ITEMS = {}
local FAVITSAVE = "FAVORITEITEMS"

local LANG = GetModConfigData("LANGUAGE") or "en"
local STRINGS_MOD = {
	en = {
		REMOVED = " was removed from slot ",
		REPLACED = " replaced item in slot ",
		MOVED = " was moved to slot ",
		FAVORITED = " was favorited on slot ",
		FAVORITE_HINT = "Favorite",
	},
	zh = {
		REMOVED = " 已从格子中移除 ",
		REPLACED = " 已替换格子中的物品 ",
		MOVED = " 已移动到格子 ",
		FAVORITED = " 已收藏到格子 ",
		FAVORITE_HINT = "收藏",
	},
}
local S = STRINGS_MOD[LANG] or STRINGS_MOD.en

-- ==================== 边框颜色 ====================
local COLOR_PRESETS = {
	yellow = {1, 0.85, 0.2, 1},
	pink   = {1, 0.45, 0.75, 1},
	blue   = {0.3, 0.6, 1, 1},
	green  = {0.3, 1, 0.4, 1},
	purple = {0.7, 0.3, 1, 1},
	red    = {1, 0.25, 0.25, 1},
	white  = {1, 1, 1, 1},
	cyan   = {0.3, 1, 1, 1},
}
local BORDER_COLOR_KEY = GetModConfigData("BORDER_COLOR") or "yellow"
local BORDER_COLOR = COLOR_PRESETS[BORDER_COLOR_KEY] or COLOR_PRESETS.yellow

-- ==================== 边框大小 / 透明度 ====================
local BORDER_SIZE = GetModConfigData("BORDER_SIZE") or 0.62
local BORDER_ALPHA = GetModConfigData("BORDER_ALPHA") or 1.0

-- ==================== 星标颜色 ====================
local STAR_COLOR_PRESETS = {
	yellow = {1, 1, 1, 1},
	pink   = {1, 0.5, 0.9, 1},
	orange = {1, 0.7, 0, 1},
	red    = {1, 0.3, 0.1, 1},
	green  = {0.5, 1, 0.3, 1},
	white  = {1, 1, 1, 1},
}
local STAR_COLOR_KEY = GetModConfigData("STAR_COLOR") or "yellow"
local STAR_COLOR = STAR_COLOR_PRESETS[STAR_COLOR_KEY] or STAR_COLOR_PRESETS.yellow

-- ==================== 星标大小 / 位置 ====================
local STAR_SIZE = GetModConfigData("STAR_SIZE") or 0.9
local STAR_POS_KEY = GetModConfigData("STAR_POS") or "tr"

local STAR_POS = {
	tr = {18, 18},
	tl = {-18, 18},
	br = {18, -18},
	bl = {-18, -18},
}
local star_pos = STAR_POS[STAR_POS_KEY] or STAR_POS.tr

-- ==================== 提示模式 / 隐藏星标 ====================
local SHIFT_HINT_MODE = GetModConfigData("SHIFT_HINT") or "compact"
local HIDE_STAR = GetModConfigData("HIDE_STAR") or false

-- ==================== 音效 ====================
local SOUND_FAVORITE = "dontstarve/HUD/click_move"
local SOUND_REMOVE   = "dontstarve/HUD/click_negative"

local function PlayFavSound(is_add)
	pcall(function()
		if GLOBAL.TheFocalPoint and GLOBAL.TheFocalPoint.SoundEmitter then
			GLOBAL.TheFocalPoint.SoundEmitter:PlaySound(
				is_add and SOUND_FAVORITE or SOUND_REMOVE, nil, 0.6
			)
		end
	end)
end

local function SavePersistentData(name, data)
	local tstring = json.encode(data)
	GLOBAL.TheSim:SetPersistentString(name, tstring, false)
end

local function GetContainerType(widget)
	if not widget then return nil end
	local ok, result = pcall(function()
		if not widget.owner or not widget.container then return nil end
		local replica = widget.owner.replica
		if not replica then return nil end
		local inv = replica.inventory
		if not inv then return nil end
		if widget.container == inv then return "inv" end
		if type(inv.GetOverflowContainer) == "function" then
			local overflow = inv:GetOverflowContainer()
			if overflow and widget.container == overflow then
				return "overflow"
			end
		end
		return nil
	end)
	if ok then return result end
	return nil
end

local function ContainsItemInTable(t, item, container_type)
	for k, v in pairs(t) do
		local v_container = v.container or "inv"
		if v_container == container_type and v.item == item then return k end
	end
	return false
end

local function SlotIsBusy(t, slot, container_type)
	for k, v in pairs(t) do
		local v_container = v.container or "inv"
		if v_container == container_type and v.slot == slot then return k end
	end
	return false
end


AddClassPostConstruct("widgets/invslot", function(invslot)
	-- ==================== 星标 ====================
	invslot.star = invslot:AddChild(require("widgets/image")("images/crafting_menu.xml", "favorite_checked.tex"))
	invslot.star:SetScale(STAR_SIZE, STAR_SIZE)
	invslot.star:SetTint(STAR_COLOR[1], STAR_COLOR[2], STAR_COLOR[3], STAR_COLOR[4])
	invslot.star:SetPosition(star_pos[1], star_pos[2], 0)
	invslot.star:Hide()
	-- 隐藏星标模式下，彻底禁用鼠标交互，防止任何残留拦截
	if HIDE_STAR then
		pcall(function() invslot.star:SetClickable(false) end)
	end

	-- ==================== 边框 ====================
	invslot.border = invslot:AddChild(require("widgets/image")("images/crafting_menu.xml", "slot_frame_highlight.tex"))
	invslot.border:SetScale(BORDER_SIZE, BORDER_SIZE)
	invslot.border:SetTint(BORDER_COLOR[1], BORDER_COLOR[2], BORDER_COLOR[3], BORDER_ALPHA)
	invslot.border:Hide()
	-- 边框也不应该拦截鼠标
	pcall(function() invslot.border:SetClickable(false) end)

	invslot.star:MoveToBack()
	invslot.border:MoveToBack()
	if invslot.bgimage then
		invslot.bgimage:MoveToBack()
	end

	local old_SetTile = invslot.SetTile
	invslot.SetTile = function(self, tile)
		if old_SetTile then
			old_SetTile(self, tile)
		end

		local ok, is_favorite = pcall(function()
			if not tile or not tile.item or not tile.item.prefab then return false end
			if not FAVORITED_ITEMS then return false end
			local container_type = GetContainerType(self)
			if not container_type then return false end
			for k, v in pairs(FAVORITED_ITEMS) do
				local v_container = v.container or "inv"
				if v_container == container_type and v.slot == self.num and v.item == tile.item.prefab then
					return true
				end
			end
			return false
		end)
		if not ok then is_favorite = false end

		if is_favorite then
			if not HIDE_STAR then
				self.star:Show()
				self.star:MoveToFront()
			else
				self.star:Hide()
			end
			self.border:Show()
			self.border:MoveToBack()
			if self.bgimage then
				self.bgimage:MoveToBack()
			end
		else
			self.star:Hide()
			self.border:Hide()
		end
	end

	local old_OnMouseButton = invslot.OnMouseButton
	invslot.OnMouseButton = function(self, button, down, x, y)
		local success, result = GLOBAL.pcall(function()
			if button == GLOBAL.MOUSEBUTTON_MIDDLE and down then
				if GLOBAL.TheInput:IsControlPressed(GLOBAL.CONTROL_FORCE_TRADE) then
					local container_type = GetContainerType(self)
					if self.tile and self.tile.item and self.tile.item.prefab and container_type then
						local prefab = self.tile.item.prefab
						local slot = self.num
						local item_name = tostring(self.tile.item.name)

						local item_idx = ContainsItemInTable(FAVORITED_ITEMS, prefab, container_type)
						local slot_idx = SlotIsBusy(FAVORITED_ITEMS, slot, container_type)

						if item_idx and FAVORITED_ITEMS[item_idx].slot == slot then
							table.remove(FAVORITED_ITEMS, item_idx)
							GLOBAL.ThePlayer.components.talker:Say(item_name .. S.REMOVED .. tostring(slot))
							PlayFavSound(false)
						else
							if item_idx then
								table.remove(FAVORITED_ITEMS, item_idx)
							end

							slot_idx = SlotIsBusy(FAVORITED_ITEMS, slot, container_type)
							if slot_idx then
								FAVORITED_ITEMS[slot_idx].item = prefab
								GLOBAL.ThePlayer.components.talker:Say(item_name .. S.REPLACED .. tostring(slot))
								PlayFavSound(true)
							else
								table.insert(FAVORITED_ITEMS, {
									item = prefab,
									slot = slot,
									container = container_type,
								})
								if item_idx then
									GLOBAL.ThePlayer.components.talker:Say(item_name .. S.MOVED .. tostring(slot))
								else
									GLOBAL.ThePlayer.components.talker:Say(item_name .. S.FAVORITED .. tostring(slot))
								end
								PlayFavSound(true)
							end
						end

						HAVE_FAVORITED = GLOBAL.next(FAVORITED_ITEMS) ~= nil
						SavePersistentData(FAVITSAVE, FAVORITED_ITEMS)

						if GLOBAL.ThePlayer and GLOBAL.ThePlayer.HUD and GLOBAL.ThePlayer.HUD.controls.inv then
							for k, v in pairs(GLOBAL.ThePlayer.HUD.controls.inv.inv) do
								if v.SetTile then
									v:SetTile(v.tile)
								end
							end
						end
					end
					return true
				end
			end
		end)

		if success and result then return true end
		if old_OnMouseButton then return old_OnMouseButton(self, button, down, x, y) end
	end
end)

AddClassPostConstruct("widgets/itemtile", function(self)
	local old_GetDescriptionString = self.GetDescriptionString
	self.GetDescriptionString = function(self)
		local success, str = GLOBAL.pcall(function()
			local s = old_GetDescriptionString(self)
			if SHIFT_HINT_MODE ~= "off" and GLOBAL.TheInput:IsControlPressed(GLOBAL.CONTROL_FORCE_TRADE) then
				if self.parent and GetContainerType(self.parent) then
					-- 紧凑模式：只追加一行，避免把提示框抬高两行
					s = s .. "\n\238\132\130: " .. S.FAVORITE_HINT
				end
			end
			return s
		end)
		return success and str or (old_GetDescriptionString and old_GetDescriptionString(self) or "")
	end
end)

local task_running = false

local function doRunTask()
	GLOBAL.pcall(function()
		task_running = false

		if not GLOBAL.TheFrontEnd or not GLOBAL.TheFrontEnd:GetActiveScreen() then return end
		if GLOBAL.TheFrontEnd:GetActiveScreen().name ~= "HUD" then return end

		if not HAVE_FAVORITED then return end

		local inventory = GLOBAL.ThePlayer and GLOBAL.ThePlayer.replica.inventory
		if not inventory then return end

		if inventory:GetActiveItem() ~= nil then return end

		local changed = false

		local virtual_inv = {}
		for k, item in pairs(inventory:GetItems()) do
			if item and item.prefab then
				virtual_inv[k] = item.prefab
			end
		end

		local virtual_overflow = {}
		local overflow = nil
		local ok_overflow, raw_overflow = pcall(function()
			if type(inventory.GetOverflowContainer) ~= "function" then return nil end
			return inventory:GetOverflowContainer()
		end)
		if ok_overflow and raw_overflow then
			overflow = raw_overflow
			local ok_items, items = pcall(function() return overflow:GetItems() end)
			if ok_items and items then
				for k, item in pairs(items) do
					if item and item.prefab then
						virtual_overflow[k] = item.prefab
					end
				end
			end
		end

		for _, fav in pairs(FAVORITED_ITEMS) do
			local fav_container = fav.container or "inv"
			if fav_container == "inv" then
				local found_slot = nil
				local found_in_overflow = false

				if virtual_inv[fav.slot] == fav.item then
					found_slot = fav.slot
					found_in_overflow = false
				else
					for k, prefab in pairs(virtual_inv) do
						if prefab == fav.item then
							found_slot = k
							break
						end
					end

					if not found_slot and overflow then
						for k, prefab in pairs(virtual_overflow) do
							if prefab == fav.item then
								found_slot = k
								found_in_overflow = true
								break
							end
						end
					end
				end

				if found_slot then
					if not found_in_overflow and found_slot == fav.slot then
						-- already in place
					else
						if found_in_overflow then
							GLOBAL.SendRPCToServer(GLOBAL.RPC.TakeActiveItemFromAllOfSlot, found_slot, overflow.inst)
						else
							GLOBAL.SendRPCToServer(GLOBAL.RPC.TakeActiveItemFromAllOfSlot, found_slot)
						end

						if virtual_inv[fav.slot] ~= nil then
							GLOBAL.SendRPCToServer(GLOBAL.RPC.SwapActiveItemWithSlot, fav.slot)
							if found_in_overflow then
								GLOBAL.SendRPCToServer(GLOBAL.RPC.PutAllOfActiveItemInSlot, found_slot, overflow.inst)
								virtual_overflow[found_slot] = virtual_inv[fav.slot]
								virtual_inv[fav.slot] = fav.item
							else
								GLOBAL.SendRPCToServer(GLOBAL.RPC.PutAllOfActiveItemInSlot, found_slot)
								virtual_inv[found_slot] = virtual_inv[fav.slot]
								virtual_inv[fav.slot] = fav.item
							end
						else
							GLOBAL.SendRPCToServer(GLOBAL.RPC.PutAllOfActiveItemInSlot, fav.slot)
							virtual_inv[fav.slot] = fav.item
							if found_in_overflow then
								virtual_overflow[found_slot] = nil
							else
								virtual_inv[found_slot] = nil
							end
						end

						changed = true
					end
				end
			end
		end

		if changed then
			GLOBAL.SendRPCToServer(GLOBAL.RPC.ReturnActiveItem)
		end
	end)
end

local function runTask()
	if task_running then return end
	if GLOBAL.ThePlayer then
		task_running = true
		GLOBAL.ThePlayer:DoTaskInTime(0.15, doRunTask)
	end
end

AddPlayerPostInit(function(inst)
	inst:ListenForEvent("playeractivated", function(inst)
		if inst ~= GLOBAL.ThePlayer then return end

		task_running = false

		inst:ListenForEvent("itemget", runTask)
		inst:ListenForEvent("itemlose", runTask)
		inst:ListenForEvent("gotnewitem", runTask)
		inst:ListenForEvent("dropitem", runTask)
		inst:ListenForEvent("equip", runTask)
		inst:ListenForEvent("unequip", runTask)
		inst:ListenForEvent("newactiveitem", runTask)

		GLOBAL.TheSim:GetPersistentString(FAVITSAVE,
			function(load_success, str)
				if load_success then
					local success, sTable = GLOBAL.pcall(function() return json.decode(str) end)

					if success and type(sTable) == "table" then
						FAVORITED_ITEMS = sTable
						HAVE_FAVORITED = true

						if GLOBAL.ThePlayer and GLOBAL.ThePlayer.HUD and GLOBAL.ThePlayer.HUD.controls.inv then
							for k, v in pairs(GLOBAL.ThePlayer.HUD.controls.inv.inv) do
								if v.SetTile then
									v:SetTile(v.tile)
								end
							end
						end
						runTask()
					end
				end
			end)
	end)
end)

GLOBAL.TheInput:AddKeyDownHandler(GLOBAL.KEY_Z, function()
	if GLOBAL.TheInput:IsKeyDown(GLOBAL.KEY_CTRL) and GLOBAL.TheInput:IsKeyDown(GLOBAL.KEY_SHIFT) then
		HAVE_FAVORITED = false
		FAVORITED_ITEMS = {}

		GLOBAL.TheSim:ErasePersistentString(FAVITSAVE)

		if GLOBAL.ThePlayer and GLOBAL.ThePlayer.HUD and GLOBAL.ThePlayer.HUD.controls.inv then
			for k, v in pairs(GLOBAL.ThePlayer.HUD.controls.inv.inv) do
				if v.SetTile then
					v:SetTile(v.tile)
				end
			end
		end
	end
end)