------------------------------------------------------
-- #ģ�������ʼ��ֿ�ģ��
-- #ģ��˵������ǿ�ʼ�����
------------------------------------------------------
local L = AH_Library.LoadLangPack()

_G["AH_MailBank_Loaded"] = true

AH_MailBank = {
	aLootQueue = {},
	tLootQueue = {},
	nLastLootTime = 0,
	tItemCache = {},
	tSendCache = {},
	tMoneyCache = {},
	tMoneyPayCache = {},
	szDataPath = "\\Interface\\AH\\AH_Base\\data\\mail.jx3dat",
	szCurRole = nil,
	nCurIndex = 1,
	szCurKey = "",
	nFilterType = 1,
	bShowNoReturn = false,
	bAutoExange = false,
	bMail = true,
	dwMailNpcID = nil,
	szReceiver = nil,
	bPay = false,
}

RegisterCustomData("AH_MailBank.bAutoExange")

local ipairs = ipairs
local pairs = pairs
local tonumber = tonumber

local szIniFile = "Interface/AH/AH_Mailbank/AH_MailBank.ini"
local bMailHooked = false
local bBagHooked = false
local bInitMail = false
local tFilterType = {
	L("STR_MAILBANK_ITEMNAME"),
	L("STR_MAILBANK_MAILTITLE"),
	L("STR_MAILBANK_SENDER"),
	L("STR_MAILBANK_ENDDATE")
}

-- �����ݷ�ҳ����ÿҳ98�����ݣ����ط�ҳ���ݺ�ҳ��
function AH_MailBank.GetPageMailData(tItemCache)
	--�ȶԴ���ı����ʼ�ID��������
	table.sort(tItemCache, function(a, b)
		local function max(t)
			local index = table.maxn(t)
			return t[index]
		end
		if max(a.tMailIDs) == max(b.tMailIDs) then
			return a.nUiId > b.nUiId
		else
			return max(a.tMailIDs) > max(b.tMailIDs) end
		end
	)
	local tItems, nIndex = {}, 1
	for k, v in ipairs(tItemCache) do
		tItems[nIndex] = tItems[nIndex] or {}
		table.insert(tItems[nIndex], v)
		nIndex = math.ceil(k / 97)
	end
	return tItems, nIndex
end

-- �Ƿ������ʼ�
local function IsOfflineMail()
	if GetClientPlayer().szName ~= AH_MailBank.szCurRole or not AH_MailBank.bMail then
		return true
	end
	return false
end

-- ��ҳ���ظý�ɫ����Ʒ����
function AH_MailBank.LoadMailData(frame, szName, nIndex)
	if not frame or (frame and not frame:IsVisible()) then
		return
	end
	local handle = frame:Lookup("", "")
	local hBg = handle:Lookup("Handle_Bg")
	local hBox = handle:Lookup("Handle_Box")

	--��������
	local tItemCache = AH_MailBank.bShowNoReturn and AH_MailBank.SaveItemCache(false) or AH_MailBank.tItemCache[szName]
	local tCache, nMax = AH_MailBank.GetPageMailData(tItemCache)
	local i = 0
	nIndex = math.max(1, nIndex)
	for k, v in ipairs(tCache[nIndex] or {}) do
		local img = hBg:Lookup(k - 1)
		local box = hBox:Lookup(k - 1)
		box:ClearExtentImage()
		box:ClearObject()
		box:SetOverText(0, "")
		box:SetOverText(1, "")
		img:Show()
		box:Show()
		if v.szName == "money" then
			box.bItem = false
			box.szName = L("STR_MAILBANK_MONEY")
			box.data = v
			box:SetObject(UI_OBJECT_NOT_NEED_KNOWN, 0)
			box:SetObjectIcon(582)
			box:SetAlpha(255)
			box:SetOverTextFontScheme(0, 15)
			box:SetOverText(0, "")
		else
			box.bItem = true
			box.szName = v.szName
			box.data = v
			box:SetObject(UI_OBJECT_ITEM_ONLY_ID, v.nUiId, v.dwID, v.nVersion, v.dwTabType, v.dwIndex)
			box:SetObjectIcon(Table_GetItemIconID(v.nUiId))
			box:SetAlpha(255)
			box:SetOverTextFontScheme(0, 15)
			if not IsOfflineMail() then
				local item = GetItem(v.dwID)
				if item then
					UpdateItemBoxExtend(box, item.nGenre, item.nQuality, item.nStrengthLevel)
				end
				local mail = GetMailClient().GetMailInfo(v.tMailIDs[1])
				if mail then
					local nTime = mail.GetLeftTime()
					if nTime <= 86400 * 2 then
						box:SetOverText(1, L("STR_MAILBANK_WILLEND"))
					else
						box:SetOverText(1, "")
					end
				end
			end
			if v.nStack > 1 then
				box:SetOverText(0, v.nStack)
			else
				box:SetOverText(0, "")
			end
		end
		i = k
	end
	--��������box
	for j = i, 97, 1 do
		local img = hBg:Lookup(j)
		local box = hBox:Lookup(j)
		if box:IsVisible() then
			img:Hide()
			box:Hide()
		end
	end

	frame:Lookup("", ""):Lookup("Text_Account"):SetText(szName)
	-- ��ҳ����
	local hPrev, hNext = frame:Lookup("Btn_Prev"), frame:Lookup("Btn_Next")
	local hPage = frame:Lookup("", ""):Lookup("Text_Page")
	if nMax > 1 then
		hPrev:Show()
		hNext:Show()
		hPage:Show()
		if nIndex == 1 then
			hPrev:Enable(false)
			hNext:Enable(true)
		elseif nIndex == nMax then
			hPrev:Enable(true)
			hNext:Enable(false)
		else
			hPrev:Enable(true)
			hNext:Enable(true)
		end
		hPage:SetText(string.format("%d/%d", nIndex, nMax))
	else
		hPrev:Hide()
		hNext:Hide()
		hPage:Hide()
	end
	--ɸѡ����
	frame:Lookup("", ""):Lookup("Text_Filter"):SetText(tFilterType[AH_MailBank.nFilterType])
	local hType = frame:Lookup("", ""):Lookup("Text_Type")
	if AH_MailBank.nFilterType == 4 then
		hType:SetText(L("STR_MAILBANK_LESSTHAN"))
	else
		hType:SetText(L("STR_MAILBANK_WITHIN"))
	end
	frame:Lookup("Btn_Filter"):Enable(not IsOfflineMail())
	frame:Lookup("Btn_LootAll"):Enable(not IsOfflineMail())
	frame:Lookup("Check_NotReturn"):Enable(not IsOfflineMail())
	local tColor = (not IsOfflineMail()) and {255, 255, 255} or {180, 180, 180}
	frame:Lookup("", ""):Lookup("Text_Filter"):SetFontColor(unpack(tColor))
	frame:Lookup("", ""):Lookup("Text_NotReturn"):SetFontColor(unpack(tColor))
end

-- ���ʼ�����ɸѡ
local function IsMailTitleExist(data, szKey)
	local MailClient = GetMailClient()
	for k, v in ipairs(data) do
		local mail = MailClient.GetMailInfo(v)
		if StringFindW(mail.szTitle, szKey) then
			return true
		end
	end
	return false
end

-- �Լ�����ɸѡ
local function IsMailSenderNameExist(data, szKey)
	local MailClient = GetMailClient()
	for k, v in ipairs(data) do
		local mail = MailClient.GetMailInfo(v)
		if StringFindW(mail.szSenderName, szKey) then
			return true
		end
	end
	return false
end

-- ��ʣ��ʱ��ɸѡ
local function IsLessMailItemTime(data, szKey)
	local nLeft = 86400 * tonumber(szKey) or 0
	local MailClient = GetMailClient()
	for k, v in ipairs(data) do
		local mail = MailClient.GetMailInfo(v)
		if mail.GetLeftTime() < nLeft then
			return true
		end
	end
	return false
end

-- ������Ʒ
function AH_MailBank.FilterMailItem(frame, szKey)
	local handle = frame:Lookup("", "")
	local hBox = handle:Lookup("Handle_Box")
	for i = 0, 97, 1 do
		local box = hBox:Lookup(i)
		if not box:IsEmpty() then
			local bExist = false
			if AH_MailBank.nFilterType == 1 then
				bExist = (StringFindW(box.szName, szKey) ~= nil)
			elseif AH_MailBank.nFilterType == 2 then
				bExist = IsMailTitleExist(box.data[6], szKey)
			elseif AH_MailBank.nFilterType == 3 then
				bExist = IsMailSenderNameExist(box.data[6], szKey)
			elseif AH_MailBank.nFilterType == 4 then
				bExist = IsLessMailItemTime(box.data[6], szKey)
			end
			if bExist then
				box:SetAlpha(255)
				box:SetOverTextFontScheme(0, 15)
			else
				box:SetAlpha(50)
				box:SetOverTextFontScheme(0, 30)
			end
		end
	end
end

-- �����ʼ���Ʒ���ݣ�����ƷnUiIdΪkey�����ݱ�ͬ����Ʒȫ���ۼӣ�ÿ����Ʒ���������ʼ�ID
function AH_MailBank.SaveItemCache(bAll)
	local MailClient = GetMailClient()
	local tMail = MailClient.GetMailList("all") or {}
	local tItems, tCount, tMailIDs, nMoney = {}, {}, {}, 0
	for _, dwID in ipairs(tMail) do
		local mail = MailClient.GetMailInfo(dwID)
		if mail then
			mail.RequestContent(AH_MailBank.dwMailNpcID)
		end
		if bAll or (not bAll and not (mail.GetType() == MAIL_TYPE.PLAYER and (mail.bMoneyFlag or mail.bItemFlag))) then
			local tItem = AH_MailBank.GetMailItem(mail)
			for k, v in pairs(tItem) do
				--�洢��Ʒ�����ʼ�ID
				if not tMailIDs[k] then
					tMailIDs[k] = {dwID}
				else
					table.insert(tMailIDs[k], dwID)
				end
				--����������洢��Ʒ���ݣ���������
				if k == "money" then
					--nMoney = MoneyOptAdd(nMoney, v)
					tItems = AH_MailBank.InsertData(tItems, {
						szName = "money",
						nMoney = v,
						nUiId = -1,
						tMailIDs = tMailIDs["money"]
					})
				else
					tItems = AH_MailBank.InsertData(tItems, {
						szName = k,
						dwID = v[1],
						nVersion = v[2],
						dwTabType = v[3],
						dwIndex = v[4],
						nStack = v[5],
						nUiId = v[6],
						tMailIDs = tMailIDs[k]
					})
				end
			end
		end
	end
	return tItems	--��������������Ʒ��
end

function AH_MailBank.InsertData(tItems, tData)
	local function _get(tItems, szName)
		for k, v in ipairs(tItems) do
			if v.szName == szName then
				return v
			end
		end
		return false
	end
	local v = _get(tItems, tData.szName)
	if not v then
		table.insert(tItems, tData)
	else
		if tData.szName == "money" then
			v.nMoney = MoneyOptAdd(v.nMoney, tData.nMoney)
		else
			v.nStack = v.nStack + tData.nStack
		end
	end
	return tItems
end

-- ��ȡ�����ʼ���������Ʒ���ݣ�������Ǯ��ͬ����Ʒ�������ۼӴ���
function AH_MailBank.GetMailItem(mail)
	local tItems, tCount = {}, {}
	if mail.bItemFlag then
		for i = 0, 7, 1 do
			local item = mail.GetItem(i)
			if item then
				local szKey = GetItemNameByItem(item)
				local nStack = (item.bCanStack) and item.nStackNum or 1
				tCount[szKey] = tCount[szKey] or 0	--������ͬ����Ʒ������
				if not tItems[szKey] then
					tCount[szKey] = nStack
					tItems[szKey] = {item.dwID, item.nVersion, item.dwTabType, item.dwIndex, nStack, item.nUiId}
				else
					tCount[szKey] = tCount[szKey] + nStack
					tItems[szKey] = {item.dwID, item.nVersion, item.dwTabType, item.dwIndex, tCount[szKey], item.nUiId}
				end
			end
		end
	end
	if mail.bMoneyFlag and mail.nMoney ~= 0 then
		tItems["money"] = mail.nMoney
	end
	return tItems
end

function AH_MailBank.OnUpdate()
	local frame = Station.Lookup("Normal/MailPanel")
	if frame and frame:IsVisible() then
		if not bMailHooked then	--�ʼ�������Ӱ�ť
			local page = frame:Lookup("PageSet_Total/Page_Receive")
			local temp = Wnd.OpenWindow("Interface\\AH\\AH_Base\\AH_Widget.ini")
			if not page:Lookup("Btn_MailBank") then
				local hBtnMailBank = temp:Lookup("Btn_MailBank")
				if hBtnMailBank then
					hBtnMailBank:ChangeRelation(page, true, true)
					hBtnMailBank:SetRelPos(50, 8)
					hBtnMailBank:Lookup("", ""):Lookup("Text_MailBank"):SetText(L("STR_MAILBANK_MAILTIP1"))
					hBtnMailBank.OnLButtonClick = function()
						if not AH_MailBank.IsPanelOpened() then
							AH_MailBank.bMail = true
							AH_MailBank.nFilterType = 1
							AH_MailBank.OpenPanel()
						else
							AH_MailBank.ClosePanel()
						end
					end
					hBtnMailBank:Enable(false)
				end
				local hBtnLootAll = temp:Lookup("Btn_Loot")
				if hBtnLootAll then
					hBtnLootAll:ChangeRelation(page, true, true)
					hBtnLootAll:SetRelPos(680, 380)
					hBtnLootAll.OnLButtonClick = function()
						--AH_MailBank.LootAllItem()
						local dwID = Station.Lookup("Normal/MailPanel"):Lookup("PageSet_Total/Page_Receive").dwShowID
						AH_MailBank.LootMailItem(dwID, "all")
					end
					hBtnLootAll.OnMouseEnter = function()
						local x, y = this:GetAbsPos()
						local w, h = this:GetSize()
						local szTip = GetFormatText(L("STR_MAILBANK_LOOTALL"), 162)
						OutputTip(szTip, 400, {x, y, w, h})
					end
					hBtnLootAll.OnMouseLeave = function()
						HideTip()
					end
				end
			end
			page = frame:Lookup("PageSet_Total/Page_Send")
			if not page:Lookup("Check_AutoExange") then	--���ѡ���
				local hCheck = temp:Lookup("Check_AutoExange")
				if hCheck then
					hCheck:ChangeRelation(page, true, true)
					hCheck:SetRelPos(400, 480)
					hCheck:Lookup("", ""):Lookup("Text_AutoExange"):SetText(L("STR_MAILBANK_AUTOEXANGE"))
					hCheck:Check(AH_MailBank.bAutoExange)
					hCheck.OnCheckBoxCheck = function()
						AH_MailBank.bAutoExange = true
					end
					hCheck.OnCheckBoxUncheck = function()
						AH_MailBank.bAutoExange = false
					end
				end
			end
			local hBtnSend = page:Lookup("Btn_Deliver") --Hook���Ͱ�ť
			hBtnSend.OnLButtonDown = function()
				AH_MailBank.tSendCache = {}
				if AH_MailBank.bAutoExange then
					--������
					local szReceiver = page:Lookup("Edit_Name"):GetText()
					if szReceiver and szReceiver ~= AH_MailBank.szReceiver then
						AH_MailBank.szReceiver = szReceiver
					end
					--��Ʒ
					local handle = page:Lookup("", "Handle_Write")
					for i = 0, 7, 1 do
						local box = handle:Lookup("Box_Item"..i)
						if not box:IsEmpty() then
							local nUiId, dwBox, dwX = box:GetObjectData()
							local nCount = box:GetOverText(0)
							nCount = (nCount == "") and 1 or tonumber(nCount)
							table.insert(AH_MailBank.tSendCache, {nUiId, nCount})
						end
					end
					--�����ż�
					local bPay = page:Lookup("CheckBox_PayMail"):IsCheckBoxChecked()
					AH_MailBank.bPay = bPay
					if bPay then
						local szGoldPay = page:Lookup("Edit_GoldPay"):GetText()
						local szSilverPay = page:Lookup("Edit_SilverPay"):GetText()
						local szCopperPay = page:Lookup("Edit_CopperPay"):GetText()
						AH_MailBank.tMoneyPayCache = {
							nGoldPay = (szGoldPay ~= "") and tonumber(szGoldPay) or 0,
							nSilverPay = (szSilverPay ~= "") and tonumber(szSilverPay) or 0,
							nCopperPay = (szCopperPay ~= "") and tonumber(szCopperPay) or 0,
						}
					else	--�ĳ���Ǯ
						local szGold = page:Lookup("Edit_Gold"):GetText()
						local szSilver = page:Lookup("Edit_Silver"):GetText()
						local szCopper = page:Lookup("Edit_Copper"):GetText()
						AH_MailBank.tMoneyCache = {
							nGold = (szGold ~= "") and tonumber(szGold) or 0,
							nSilver = (szSilver ~= "") and tonumber(szSilver) or 0,
							nCopper = (szCopper ~= "") and tonumber(szCopper) or 0,
						}
					end
				end
			end

			AH_MailBank.dwMailNpcID = Station.Lookup("Normal/Target").dwID

			Wnd.CloseWindow(temp)
			bMailHooked = true
		end
		--��ȡ�ʼ�
		if not bInitMail then
			local hTitle = frame:Lookup("PageSet_Total/Page_Receive", "Text_ReceiveTitle")
			local szTitle = hTitle:GetText()
			hTitle:SetText(L("STR_MAILBANK_REQUEST"))
			AH_Library.DelayCall(3 + GetPingValue() / 2000, function()
				local page = frame:Lookup("PageSet_Total/Page_Receive")
				page:Lookup("Btn_MailBank"):Enable(true)
				hTitle:SetText(szTitle)
				FireEvent("MAIL_LIST_UPDATE")
			end)
			bInitMail = true
		end
	elseif not frame or not frame:IsVisible() then
		bMailHooked, bInitMail = false, false
		if not IsOfflineMail() then
			AH_MailBank.Close()
		end
	end

	local frame = Station.Lookup("Normal/BigBagPanel")
	if not bBagHooked and frame and frame:IsVisible() then --�����������һ����ť
		local temp = Wnd.OpenWindow("Interface\\AH\\AH_Base\\AH_Widget.ini")
		if not frame:Lookup("Btn_Mail") then
			local hBtnMail = temp:Lookup("Btn_Mail")
			if hBtnMail then
				hBtnMail:ChangeRelation(frame, true, true)
				hBtnMail:SetRelPos(55, 0)
				hBtnMail.OnLButtonClick = function()
					if not AH_MailBank.IsPanelOpened() then
						AH_MailBank.bMail = false
						AH_MailBank.OpenPanel()
					else
						AH_MailBank.ClosePanel()
					end
				end
				hBtnMail.OnMouseEnter = function()
					local x, y = this:GetAbsPos()
					local w, h = this:GetSize()
					local szTip = GetFormatText(L("STR_MAILBANK_MAILTIP1"), 163) .. GetFormatText("\n" .. L("STR_MAILBANK_MAILTIP2"), 162)
					OutputTip(szTip, 400, {x, y, w, h})
				end
				hBtnMail.OnMouseLeave = function()
					HideTip()
				end
			end
		end
		Wnd.CloseWindow(temp)
		bBagHooked = true
	elseif not frame or not frame:IsVisible() then
		bBagHooked = false
	end
end

-- ����ʣ��ʱ���ʽ��
function AH_MailBank.FormatItemLeftTime(nTime)
	if nTime >= 86400 then
		return FormatString(g_tStrings.STR_MAIL_LEFT_DAY, math.floor(nTime / 86400))
	elseif nTime >= 3600 then
		return FormatString(g_tStrings.STR_MAIL_LEFT_HOURE, math.floor(nTime / 3600))
	elseif nTime >= 60 then
		return FormatString(g_tStrings.STR_MAIL_LEFT_MINUTE, math.floor(nTime / 60))
	else
		return g_tStrings.STR_MAIL_LEFT_LESS_ONE_M
	end
end

-- ȡ����
-- AH_MailBank.LootMailItem(107, 1)
-- AH_MailBank.LootMailItem(107, "all")
-- AH_MailBank.LootMailItem(107, "money")
function AH_MailBank.LootMailItem(nMailID, nIndex)
	local MailClient = GetMailClient()
	local mail = MailClient.GetMailInfo(nMailID)
	if not mail then
		return
	end
	-- ��Ʒ������ȡ����
	if mail.bItemFlag then
		if nIndex == "all" then
			for i = 0, 7, 1 do
				local item = mail.GetItem(i)
				if item then
					local szKey = nMailID .. "," .. i -- ��ֹ�ظ���ȡ
					if not AH_MailBank.tLootQueue[szKey] then
						AH_MailBank.tLootQueue[szKey] = true
						table.insert(AH_MailBank.aLootQueue, {nMailID = nMailID, nIndex = i})
					end
				end
			end
		elseif type(nIndex) == "number" then
			local item = mail.GetItem(nIndex)
			if item then
				local szKey = nMailID .. "," .. nIndex -- ��ֹ�ظ���ȡ
				if not AH_MailBank.tLootQueue[szKey] then
					AH_MailBank.tLootQueue[szKey] = true
					table.insert(AH_MailBank.aLootQueue, {nMailID = nMailID, nIndex = nIndex})
				end
			end
		end
	end
	-- ��Ǯ������ȡ����
	if (nIndex == "money" or nIndex == "all")
	and not AH_MailBank.tLootQueue[nMailID .. ",money"] then
		if mail.bMoneyFlag then
			AH_MailBank.tLootQueue[nMailID .. ",money"] = true
			table.insert(AH_MailBank.aLootQueue, {nMailID = nMailID})
		end
	end
end

function AH_MailBank.LootPage()
	local hFrame = AH_MailBank.GetFrame()
	if IsOfflineMail() or not hFrame then
		return
	end
	local MailClient = GetMailClient()
	local hBoxes = hFrame:Lookup("", "Handle_Box")
	for i = 0, hBoxes:GetItemCount() - 1 do
		local hBox = hBoxes:Lookup(i)
		if hBox and hBox:IsVisible() and hBox:GetAlpha() == 255 then
			if hBox.data.szName == "money" then
				for _, nMailID in ipairs(hBox.data.tMailIDs) do
					AH_MailBank.LootMailItem(nMailID, "money")
				end
			else
				for _, nMailID in ipairs(hBox.data.tMailIDs) do
					local mail = MailClient.GetMailInfo(nMailID)
					if mail then
						for i = 0, 7, 1 do
							local item = mail.GetItem(i)
							if item and item.nUiId == hBox.data.nUiId then
								AH_MailBank.LootMailItem(nMailID, i)
							end
						end
					end
				end
			end
		end
	end
end

--[[function AH_MailBank.LootAllItem()
	local dwID = Station.Lookup("Normal/MailPanel"):Lookup("PageSet_Total/Page_Receive").dwShowID
	local MailClient = GetMailClient()
	local mailInfo = MailClient.GetMailInfo(dwID)
	if not mailInfo then
		return
	end
	AH_MailBank.LootMailItem(dwID, "all")
	if mailInfo.bMoneyFlag then
		mailInfo.TakeMoney()
	end
	if mailInfo.bItemFlag then
		for i = 0, 7, 1 do
			local item = mailInfo.GetItem(i)
			if item then
				AH_MailBank.LootMailItem(dwID, i)
			end
		end
	end
end]]

-- ����ɸѡ
function AH_MailBank.ReFilter(frame)
	if AH_MailBank.szCurKey ~= "" then
		AH_MailBank.FilterMailItem(frame, AH_MailBank.szCurKey)
	end
end

-- ��鵱ǰ��ɫ
function AH_MailBank.CheckCurRole(frame)
	AH_MailBank.nFilterType = 1
	frame:Lookup("", ""):Lookup("Text_Filter"):SetText(tFilterType[AH_MailBank.nFilterType])
	local bTrue = (AH_MailBank.szCurRole == GetClientPlayer().szName)
	frame:Lookup("Btn_Filter"):Enable(bTrue)
	frame:Lookup("Check_NotReturn"):Enable(bTrue)
end

local function GetItemBox(tCache)
	local player = GetClientPlayer()
	for nIndex = 6, 1, -1 do
		local dwBox = INVENTORY_INDEX.PACKAGE + nIndex - 1
		local dwSize = player.GetBoxSize(dwBox)
		if dwSize > 0 then
			for dwX = dwSize, 1, -1 do
				local box = GetUIItemBox(dwBox, dwX - 1, true)
				if box and box:IsObjectEnable() then
					local item = player.GetItem(dwBox, dwX - 1)
					if item and item.nUiId == tCache[1] then
						if not item.bCanStack or (item.bCanStack and item.nStackNum == tCache[2]) then
							local i, j = dwBox, dwX - 1
							return i, j
						end
					end
				end
			end
		end
	end
end

local function UpdateItemLock(handle)
	RemoveUILockItem("mail")
	if handle then
		for i = 0, 7, 1 do
			local box = handle:Lookup("Box_Item"..i)
			if not box:IsEmpty() then
				AddUILockItem("mail", box.nBag, box.nIndex)
			end
		end
	end
end

-- �Զ�������һ�μļ�����Ʒ
function AH_MailBank.OnExchangeItem()
	local page = Station.Lookup("Normal/MailPanel/PageSet_Total/Page_Send")
	if not page then
		return
	end
	local handle = page:Lookup("", "Handle_Write")
	if not handle then
		return
	end

	--������Ʒ
	for nIndex, tCache in ipairs(AH_MailBank.tSendCache) do
		local dwBox, dwX = GetItemBox(tCache)
		local item = GetPlayerItem(GetClientPlayer(), dwBox, dwX)
		if item and not item.bBind then
			local box = handle:Lookup("Box_Item" .. nIndex - 1)
			if not box.bDisable and box:IsEmpty() then
				box:SetObject(UI_OBJECT_ITEM, item.nUiId, dwBox, dwX, item.nVersion, item.dwTabType, item.dwIndex)
				box:SetObjectIcon(Table_GetItemIconID(item.nUiId))
				UpdateItemBoxExtend(box, item)
				box.nBag = dwBox
				box.nIndex = dwX
				if item and item.bCanStack and item.nStackNum > 1 then
					box:SetOverText(0, item.nStackNum)
				else
					box:SetOverText(0, "")
				end
				UpdateItemLock(handle)
				local edit = page:Lookup("Edit_Title")
				if edit:GetText() == "" then
					edit:SetText(GetItemNameByItem(item))
				end
				page:Lookup("Edit_Name"):SetText(AH_MailBank.szReceiver)
			end
		end
	end
	if AH_MailBank.bPay then	--�����ʼ�
		page:Lookup("CheckBox_PayMail"):Check(true)
		for k, v in ipairs({"Edit_GoldPay", "Edit_SilverPay", "Edit_CopperPay"}) do
			local szKey = string.format("n%s", v:match("Edit_(%a+)"))
			page:Lookup(v):SetText(AH_MailBank.tMoneyPayCache[szKey])
		end
	else	--���ý�Ǯ
		for k, v in ipairs({"Edit_Gold", "Edit_Silver", "Edit_Copper"}) do
			local szKey = string.format("n%s", v:match("Edit_(%a+)"))
			page:Lookup(v):SetText(AH_MailBank.tMoneyCache[szKey])
		end
	end
end
------------------------------------------------------------
-- �ص�����
------------------------------------------------------------
function AH_MailBank.OnFrameCreate()
	local handle = this:Lookup("", "")
	handle:Lookup("Text_Title"):SetText(L("STR_MAILBANK_MAILTIP1"))
	handle:Lookup("Text_Tips"):SetText(L("STR_MAILBANK_TIP3"))
	handle:Lookup("Text_NotReturn"):SetText(L("STR_MAILBANK_NORETURN"))
	this:Lookup("Btn_Prev"):Lookup("", ""):Lookup("Text_Prev"):SetText(L("STR_MAILBANK_PREV"))
	this:Lookup("Btn_Next"):Lookup("", ""):Lookup("Text_Next"):SetText(L("STR_MAILBANK_NEXT"))
	this:Lookup("Btn_LootAll"):Lookup("", ""):Lookup("Text_LootAll"):SetText(L("STR_MAILBANK_LOOTPAGE"))

	local hBg = handle:Lookup("Handle_Bg")
	local hBox = handle:Lookup("Handle_Box")
	hBg:Clear()
	hBox:Clear()
	local nIndex = 0
	for i = 1, 7, 1 do
		for j = 1, 14, 1 do
			hBg:AppendItemFromString("<image>w=52 h=52 path=\"ui/Image/LootPanel/LootPanel.UITex\" frame=13 </image>")
			local img = hBg:Lookup(nIndex)
			hBox:AppendItemFromString("<box>w=48 h=48 eventid=304 </box>")
			local box = hBox:Lookup(nIndex)
			box.nIndex = nIndex
			box.bItemBox = true
			local x, y = (j - 1) * 52, (i - 1) * 52
			img:SetRelPos(x, y)
			box:SetRelPos(x + 2, y + 2)
			box:SetOverTextPosition(0, ITEM_POSITION.RIGHT_BOTTOM)
			box:SetOverTextFontScheme(0, 15)
			box:SetOverTextPosition(1, ITEM_POSITION.LEFT_TOP)
			box:SetOverTextFontScheme(1, 16)
			img:Hide()
			box:Hide()

			nIndex = nIndex + 1
		end
	end
	hBg:FormatAllItemPos()
	hBox:FormatAllItemPos()
end

function AH_MailBank.OnFrameBreathe()
	if not IsOfflineMail() -- �����ʼ����ռ�
	and #AH_MailBank.aLootQueue > 0 -- ȷ���ռ����в�Ϊ��
	and GetTime() - AH_MailBank.nLastLootTime > GetPingValue() -- ȡ�����ü��һ��ʱ�䣬�����޷�ȫ��ȡ������Ҫ�����ӳ�
	and AH_MailBank.dwMailNpcID and GetNpc(AH_MailBank.dwMailNpcID) -- ȷ����ʹNPC�ɼ�
	and GetCharacterDistance(UI_GetClientPlayerID(), AH_MailBank.dwMailNpcID) / 64 < 6 -- ���ƾ���ȡ��
	-- and #AH_Library.GetPlayerBagFreeBoxList() > 0 -- ȷ����������
	then
		local tLoot = AH_MailBank.aLootQueue[1]
		local mail = GetMailClient().GetMailInfo(tLoot.nMailID)
		if mail then
			if tLoot.nIndex then
				mail.TakeItem(tLoot.nIndex)
			else
				mail.TakeMoney()
			end
			if not mail.bReadFlag then
				mail.Read()
			end
		end
		-- �Ƴ���ȡ����
		table.remove(AH_MailBank.aLootQueue, 1)
		AH_MailBank.nLastLootTime = GetTime()
		AH_MailBank.tLootQueue[tLoot.nMailID .. "," .. (tLoot.nIndex or "money")] = nil
	end
end

function AH_MailBank.OnEditChanged()
	local szName, frame = this:GetName(), this:GetRoot()
	if szName == "Edit_Search" then
		AH_MailBank.szCurKey = this:GetText()
		AH_MailBank.FilterMailItem(frame, AH_MailBank.szCurKey)
	end
end

function AH_MailBank.OnCheckBoxCheck()
	local szName, frame = this:GetName(), this:GetRoot()
	if szName == "Check_NotReturn" then
		AH_MailBank.bShowNoReturn = true
		AH_MailBank.LoadMailData(frame, AH_MailBank.szCurRole, AH_MailBank.nCurIndex)
		AH_MailBank.ReFilter(frame)
	end
end

function AH_MailBank.OnCheckBoxUncheck()
	local szName, frame = this:GetName(), this:GetRoot()
	if szName == "Check_NotReturn" then
		AH_MailBank.bShowNoReturn = false
		AH_MailBank.LoadMailData(frame, AH_MailBank.szCurRole, AH_MailBank.nCurIndex)
		AH_MailBank.ReFilter(frame)
	end
end

function AH_MailBank.OnLButtonClick()
	local szName, frame = this:GetName(), this:GetRoot()
	if szName == "Btn_Close" then
		AH_MailBank.ClosePanel()
	elseif szName == "Btn_Account" then
		local hText = frame:Lookup("", ""):Lookup("Text_Account")
		local x, y = hText:GetAbsPos()
		local w, h = hText:GetSize()
		local menu = {}
		menu.nMiniWidth = w + 20
		menu.x = x
		menu.y = y + h
		for k, v in pairs(AH_MailBank.tItemCache) do
			local m = {
				szOption = k,
				fnAction = function()
					AH_MailBank.szCurRole = k
					AH_MailBank.LoadMailData(frame, k, 1)
					AH_MailBank.ReFilter(frame)
					AH_MailBank.CheckCurRole(frame)
				end
			}
			table.insert(menu, m)
		end
		PopupMenu(menu)
	elseif szName == "Btn_Filter" then
		local hText = frame:Lookup("", ""):Lookup("Text_Filter")
		local x, y = hText:GetAbsPos()
		local w, h = hText:GetSize()
		local menu = {}
		menu.nMiniWidth = w + 20
		menu.x = x
		menu.y = y + h
		for k, v in ipairs(tFilterType) do
			local m = {
				szOption = v,
				fnAction = function()
					hText:SetText(v)
					AH_MailBank.nFilterType = k
					local hType = frame:Lookup("", ""):Lookup("Text_Type")
					if k == 4 then
						hType:SetText(L("STR_MAILBANK_LESSTHAN"))
					else
						hType:SetText(L("STR_MAILBANK_WITHIN"))
					end
					AH_MailBank.ReFilter(frame)
				end
			}
			table.insert(menu, m)
		end
		PopupMenu(menu)
	elseif szName == "Btn_Setting" then
		local menu = {}
		for k, v in pairs(AH_MailBank.tItemCache) do
			local m = {
				szOption = k,
				{
					szOption = L("STR_MAILBANK_DELETE"),
					fnAction = function()
						AH_MailBank.tItemCache[k] = nil
					end
				}
			}
			table.insert(menu, m)
		end
		PopupMenu(menu)
	elseif szName == "Btn_Prev" then
		AH_MailBank.nCurIndex = AH_MailBank.nCurIndex - 1
		AH_MailBank.LoadMailData(frame, AH_MailBank.szCurRole, AH_MailBank.nCurIndex)
		AH_MailBank.ReFilter(frame)
	elseif szName == "Btn_Next" then
		AH_MailBank.nCurIndex = AH_MailBank.nCurIndex + 1
		AH_MailBank.LoadMailData(frame, AH_MailBank.szCurRole, AH_MailBank.nCurIndex)
		AH_MailBank.ReFilter(frame)
	elseif szName == "Btn_Refresh" then
		FireEvent("MAIL_LIST_UPDATE")
		AH_MailBank.ReFilter(frame)
	elseif szName == "Btn_LootAll" then
		AH_MailBank.LootPage()
	end
end

function AH_MailBank.OnItemLButtonClick()
	local szName, frame = this:GetName(), this:GetRoot()
	if not this.bItemBox then
		return
	end
	this:SetObjectMouseOver(1)

	local d = this.data
	if this.bItem then
		local item = GetItem(d.dwID)
		if item then
			local MailClient = GetMailClient()
			for k, v in ipairs(d.tMailIDs) do
				local mail = MailClient.GetMailInfo(v)
				if mail.bItemFlag then
					for i = 0, 7, 1 do
						local item2 = mail.GetItem(i)
						if item2 and item2.nUiId == d.nUiId then
							AH_MailBank.LootMailItem(v, i)
						end
					end
				end
			end
		end
	else
		local MailClient = GetMailClient()
		for k, v in ipairs(d.tMailIDs) do
			local mail = MailClient.GetMailInfo(v)
			if mail.bMoneyFlag then
				AH_MailBank.LootMailItem(v, "money")
			end
		end
	end
end

function AH_MailBank.OnItemRButtonClick()
	local szName, frame = this:GetName(), this:GetRoot()
	if not this.bItemBox then
		return
	end
	this:SetObjectMouseOver(1)
	local box = this
	
	local d = this.data
	if this.bItem then
		local item = GetItem(d.dwID)
		if item then
			local menu = {}
			local MailClient = GetMailClient()
			for k, v in ipairs(d.tMailIDs) do
				local mail = MailClient.GetMailInfo(v)
				if mail.bItemFlag then
					local m = {
						szOption = string.format(" %s��%s��", mail.szSenderName, mail.szTitle),
						szIcon = "UI\\Image\\UICommon\\CommonPanel2.UITex",
						nFrame = 105,
						nMouseOverFrame = 106,
						szLayer = "ICON_LEFT",
						fnClickIcon = function()
							for i = 0, 7, 1 do
								local item2 = mail.GetItem(i)
								if item2 and item2.nUiId == d.nUiId then
									AH_MailBank.LootMailItem(v, i)
								end
							end
							Wnd.CloseWindow("PopupMenuPanel")
						end
					}
					for i = 0, 7, 1 do
						local item2 = mail.GetItem(i)
						if item2 and item2.nUiId == d.nUiId then
							local nStack = (item2.bCanStack) and item2.nStackNum or 1
							local m_1 = {
								szOption = string.format("%s x%d", GetItemNameByItem(item2), nStack),
								fnAction = function()
									AH_MailBank.LootMailItem(v, i)
								end,
								fnAutoClose = function() return true end
							}
							table.insert(m, m_1)
						end
					end
					table.insert(menu, m)
				end
			end
			PopupMenu(menu)
		end
	else
		local menu = {}
		local MailClient = GetMailClient()
		for k, v in ipairs(d.tMailIDs) do
			local mail = MailClient.GetMailInfo(v)
			if mail.bMoneyFlag then
				local m = {
					szOption = string.format("%s��%s��", mail.szSenderName, mail.szTitle),
					{
						szOption = GetMoneyPureText(FormatMoneyTab(mail.nMoney)),
						fnAction = function()
							AH_MailBank.LootMailItem(v, "money")
						end,
						fnAutoClose = function() return true end
					}
				}
				table.insert(menu, m)
			end
		end
		PopupMenu(menu)
	end
end

function AH_MailBank.OnItemMouseEnter()
	local szName = this:GetName()
	if not this.bItemBox then
		return
	end
	this:SetObjectMouseOver(1)

	local x, y = this:GetAbsPos()
	local w, h = this:GetSize()
	local d = this.data
	if this.bItem then
		if IsAltKeyDown() then
			local _, dwID = this:GetObjectData()
			OutputItemTip(UI_OBJECT_ITEM_ONLY_ID, dwID, nil, nil, {x, y, w, h})
		else
			local item = GetItem(d.dwID)
			if item and not IsOfflineMail() then
				local szName = GetItemNameByItem(item)
				local szTip = "<Text>text=" .. EncodeComponentsString(szName) .. " font=60" .. GetItemFontColorByQuality(item.nQuality, true) .. " </text>"
				local MailClient = GetMailClient()
				for k, v in ipairs(d.tMailIDs) do
					local mail = MailClient.GetMailInfo(v)
					if mail then
						szTip = szTip .. GetFormatText(string.format("\n%s", mail.szSenderName), 164)
						szTip = szTip .. GetFormatText(string.format(" ��%s��", mail.szTitle), 163)
						local szLeft = AH_MailBank.FormatItemLeftTime(mail.GetLeftTime())
						szTip = szTip .. GetFormatText(L("STR_MAILBANK_LEFTTIME", szLeft), 162)
						local nCount = AH_MailBank.GetMailItem(mail)[szName][5]
						szTip = szTip .. GetFormatText(L("STR_MAILBANK_NUMBER", nCount), 162)
					else
						local szTip = GetFormatText(this.szName, 162)
						OutputTip(szTip, 800, {x, y, w, h})
					end
				end
				OutputTip(szTip, 800, {x, y, w, h})
			else
				local szTip = GetFormatText(this.szName, 162)
				OutputTip(szTip, 800, {x, y, w, h})
			end
		end
	else
		local szTip = GetFormatText(g_tStrings.STR_MAIL_HAVE_MONEY, 101) .. GetMoneyTipText(d.nMoney, 106)
		local MailClient = GetMailClient()
		for k, v in ipairs(d.tMailIDs) do
			local mail = MailClient.GetMailInfo(v)
			if mail then
				szTip = szTip .. GetFormatText(string.format("\n%s", mail.szSenderName), 164)
				szTip = szTip .. GetFormatText(string.format(" ��%s��", mail.szTitle), 163)
				local szLeft = AH_MailBank.FormatItemLeftTime(mail.GetLeftTime())
				szTip = szTip .. GetFormatText(L("STR_MAILBANK_LEFTTIME", szLeft), 162)
				szTip = szTip .. GetFormatText(g_tStrings.STR_MAIL_HAVE_MONEY, 162) .. GetMoneyTipText(mail.nMoney, 106)
			end
		end
		OutputTip(szTip, 800, {x, y, w, h})
	end
end

function AH_MailBank.OnItemMouseLeave()
	local szName = this:GetName()
	if not this.bItemBox then
		return
	end

	this:SetObjectMouseOver(0)
	HideTip()
end

function AH_MailBank.GetFrame()
	return Station.Lookup("Normal/AH_MailBank")
end

function AH_MailBank.IsPanelOpened()
	local frame = Station.Lookup("Normal/AH_MailBank")
	if frame and frame:IsVisible() then
		return true
	end
	return false
end

function AH_MailBank.OpenPanel()
	local frame = Station.Lookup("Normal/AH_MailBank")
	if not frame then
		frame = Wnd.OpenWindow(szIniFile, "AH_MailBank")
	end
	frame:Show()
	frame:BringToTop()
	
	local hMailPanel = Station.Lookup("Normal/MailPanel")
	if hMailPanel then
		frame:SetAbsX(hMailPanel:GetAbsX() + hMailPanel:GetW())
		frame:SetAbsY(hMailPanel:GetAbsY())
		frame:CorrectPos()
	end
	
	AH_MailBank.szCurRole = GetClientPlayer().szName
	if not AH_MailBank.tItemCache[AH_MailBank.szCurRole] then
		AH_MailBank.tItemCache[AH_MailBank.szCurRole] = {}
	end
	AH_MailBank.LoadMailData(frame, AH_MailBank.szCurRole, AH_MailBank.nCurIndex)
	PlaySound(SOUND.UI_SOUND,g_sound.OpenFrame)
	RegisterGlobalEsc("AH_MAILBANK", AH_MailBank.IsPanelOpened, AH_MailBank.ClosePanel)
end

function AH_MailBank.ClosePanel()
	local frame = Station.Lookup("Normal/AH_MailBank")
	if frame and frame:IsVisible() then
		frame:Hide()
	end
	PlaySound(SOUND.UI_SOUND,g_sound.CloseFrame)
end

RegisterEvent("LOGIN_GAME", function()
	if IsFileExist(AH_MailBank.szDataPath) then
		AH_MailBank.tItemCache = LoadLUAData(AH_MailBank.szDataPath) or {}
	end
end)

RegisterEvent("GAME_EXIT", function()
	SaveLUAData(AH_MailBank.szDataPath, AH_MailBank.tItemCache)
end)

RegisterEvent("PLAYER_EXIT_GAME", function()
	SaveLUAData(AH_MailBank.szDataPath, AH_MailBank.tItemCache)
end)

RegisterEvent("SEND_MAIL_RESULT", function()
	if AH_MailBank.bAutoExange and arg1 == MAIL_RESPOND_CODE.SUCCEED then
		AH_Library.DelayCall(0.05 + GetPingValue() / 2000, AH_MailBank.OnExchangeItem)	--��Ҫ�ӳټ������
	end
end)

RegisterEvent("MAIL_LIST_UPDATE", function()
	local frame = Station.Lookup("Normal/MailPanel")
	if frame and frame:IsVisible() then
		local szName = GetClientPlayer().szName
		AH_MailBank.tItemCache[szName] = AH_MailBank.SaveItemCache(true)
		AH_MailBank.LoadMailData(Station.Lookup("Normal/AH_MailBank"), AH_MailBank.szCurRole, AH_MailBank.nCurIndex)
		AH_MailBank.ReFilter(AH_MailBank.GetFrame())
	end
end)

local function FireMailListEvent(szMsg, nFont, bRich, r, g, b)
	local frame = Station.Lookup("Normal/AH_MailBank")
	if frame and frame:IsVisible() then
		local szText = GetPureText(szMsg)
		if StringFindW(szText, L("STR_HELPER_OBTAINED")) then
			AH_Library.DelayCall(0.2 + GetPingValue() / 2000, function() FireEvent("MAIL_LIST_UPDATE") end)
		end
	end
end

RegisterMsgMonitor(FireMailListEvent, {"MSG_MONEY", "MSG_ITEM"})

AH_Library.BreatheCall("ON_AH_MAILBANK_UPDATE", AH_MailBank.OnUpdate)
