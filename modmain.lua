-- 一键 GLOBAL：让当前环境找不到的变量自动去 GLOBAL 里找
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
		LOCKED = " is locked and cannot be dropped",
	},
	zh = {
		REMOVED = " 已从格子中移除 ",
		REPLACED = " 已替换格子中的物品 ",
		MOVED = " 已移动到格子 ",
		FAVORITED = " 已收藏到格子 ",
		FAVORITE_HINT = "收藏",
		LOCKED = " 已锁定，无法丢弃",
	},
}
local S = STRINGS_MOD[LANG] or STRINGS_MOD.en

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

-- 安全判断槽位属于哪个容器（"inv" / "overflow" / nil），整体 pcall 保护
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

-- 判断某个槽位是否已收藏（用于锁定判断）
local function IsSlotFavorite(widget)
	if not widget or not widget.tile or not widget.tile.item then return false end
	local prefab = widget.tile.item.prefab
	if not prefab then return false end
	local ctype = GetContainerType(widget)
	if not ctype then return false end
	for _, v in pairs(FAVORITED_ITEMS) do
		local vc = v.container or "inv"
		if vc == ctype and v.slot == widget.num and v.item == prefab then
			return true
		end
	end
	return false
end

-- 提示冷却，防止刷屏
local last_lock_msg = 0
local LOCK_MSG_COOLDOWN = 1.5

local function SayLocked(widget)
	local now = GLOBAL.GetTime and GLOBAL.GetTime() or 0
	if now - last_lock_msg < LOCK_MSG_COOLDOWN then return end
	last_lock_msg = now
	pcall(function()
		local name = widget.tile and widget.tile.item and widget.tile.item.name or ""
		GLOBAL.ThePlayer.components.talker:Say(tostring(name) .. S.LOCKED)
	end)
	PlayFavSound(false)
end


AddClassPostConstruct("widgets/invslot", function(invslot)
	-- ==================== 星标（黄色小图标） ====================
	invslot.star = invslot:AddChild(require("widgets/image")("images/crafting_menu.xml", "favorite_checked.tex"))
	invslot.star:SetScale(0.9, 0.9)
	invslot.star:SetPosition(1, 40, 0)
	invslot.star:Hide()

	-- ==================== 黄色外圈边框 ====================
	invslot.border = invslot:AddChild(require("widgets/image")("images/crafting_menu.xml", "slot_frame_highlight.tex"))
	invslot.border:SetScale(0.62, 0.62)   -- 稍微放大，比槽位本身大一圈，更明显
	invslot.border:SetTint(1, 0.85, 0.2, 1) -- 金黄色，醒目
	invslot.border:Hide()

	-- 层级：bgimage 最底，border 在 bgimage 之上但物品图标之下，star 在物品之上
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
			self.star:Show()
			self.border:Show()
			-- 确保层级：星标在上，边框在物品图标下
			self.border:MoveToBack()
			if self.bgimage then
				self.bgimage:MoveToBack()
			end
			self.star:MoveToFront()
		else
			self.star:Hide()
			self.border:Hide()
		end
	end


	local old_OnMouseButton = invslot.OnMouseButton
	invslot.OnMouseButton = function(self, button, down, x, y)
		-- ==================== 锁定：拦截左键拿起收藏物品 ====================
		if button == GLOBAL.MOUSEBUTTON_LEFT and down then
			if IsSlotFavorite(self) then
				SayLocked(self)
				return true  -- 直接吞掉，不传给原函数 → 无法拿起 → 无法丢弃/拖拽
			end
		end

		-- ==================== 锁定：拦截 Ctrl+左键快速丢弃 ====================
		-- （左键已被上面拦截，Ctrl+左键自然也不会触发丢弃，这里是双保险）
		if button == GLOBAL.MOUSEBUTTON_LEFT and down
			and GLOBAL.TheInput:IsControlPressed(GLOBAL.CONTROL_FORCE_TRADE) then
			if IsSlotFavorite(self) then
				SayLocked(self)
				return true
			end
		end

		-- ==================== 中键+Ctrl：收藏/取消 ====================
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
			if GLOBAL.TheInput:IsControlPressed(GLOBAL.CONTROL_FORCE_TRADE) then
				if self.parent and GetContainerType(self.parent) then
					s = s .. "\n\238\132\130: " .. S.FAVORITE_HINT .. "\n\n "
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