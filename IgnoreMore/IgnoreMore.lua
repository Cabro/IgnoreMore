


IgM_SV = {
	enabled = true,
	list = {},
}

local list;	-- will be pointed to the relevant realm entry inside IgM_SV.list on init (if IgM is enabled)

IgM_SysIgnoreList = {}




-----------------------------------------------------------------------
-- Utilities



local function fixname(name)
	if(string.find(name, "^[a-z]")) then		-- can't just strupper first char. flat out. they can be utf-8. and hope that the user typed the rest in correct case (and the first in correct case if it isn't ASCII!)
		return string.upper(strsub(name,1,1))..strsub(name,2);
	end
	return name;
end




-----------------------------------------------------------------------
-- Fake event generators


function IgM_SysMsg(txt)
	local a1,a2,a3,a4,a5,a6,a7,a8,a9 = arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9;
	local e = event;
	local t = this;
	
	event="CHAT_MSG_SYSTEM";
	arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9 = "","","","",  "","","",  "","","";
	arg1 = txt;
	this = CURRENT_CHAT_FRAME or DEFAULT_CHAT_FRAME;
	
	ChatFrame_OnEvent(event);
	
	this=t;
	event=e;
	arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9 = a1, a2, a3, a4, a5, a6, a7, a8, a9;
end


function IgM_FireFriendEvent(evtname)
	local a1,a2,a3,a4,a5,a6,a7,a8,a9 = arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9;
	local e = event;
	local t = this;
	
	event=evtname;
	arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9 = nil,nil,nil,nil,nil,nil,nil,nil,nil;
	this = FriendsFrame;
	
	FriendsFrame_OnEvent();
	
	this=t;
	event=e;
	arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9 = a1, a2, a3, a4, a5, a6, a7, a8, a9;
end






-----------------------------------------------------------------------
-- API Hooks


local orig_AddIgnore = AddIgnore;
local orig_AddOrDelIgnore = AddOrDelIgnore;
local orig_DelIgnore = DelIgnore;
local orig_GetIgnoreName = GetIgnoreName;
local orig_GetNumIgnores = GetNumIgnores;
local orig_GetSelectedIgnore = GetSelectedIgnore;
local orig_SetSelectedIgnore = SetSelectedIgnore;


-- AddIgnore

function IgM_AddIgnore(name, reason, quiet)
	name=fixname(name);
	
	if(name==UnitName("player")) then
		if(not quiet) then
			IgM_SysMsg(ERR_IGNORE_SELF);
		end
		return false;
	end
	
	if(not reason and list[name] and type(list[name])=="table") then
		if(not quiet) then 
			IgM_SysMsg(format(ERR_IGNORE_ALREADY_S, name));
		end
		return false;
	end
	
	if(list[name] and type(list[name])=="table") then
		-- just an update, no creation
	else
		tinsert(IgM_Idx, name);
		list[name]={};
	end
	
	list[name].time=time();
	list[name].reason=reason;
	
	if(not quiet) then
		if(reason) then 
			IgM_SysMsg(format(ERR_IGNORE_ADDED_S, name)..' "'..reason..'"');
		else
			IgM_SysMsg(format(ERR_IGNORE_ADDED_S, name));
		end			
	end
	
	IgM_FireFriendEvent("IGNORELIST_UPDATE");
	return false;
end

function AddIgnore(name)
	if(not list) then 
		return orig_AddIgnore(name);
	end
	local _,_,n,r = string.find(name, "^([^ ]+) +(.*)");
	if(n and r) then
		return IgM_AddIgnore(n, r);
	else
		return IgM_AddIgnore(name);
	end
end


-- DelIgnore

function IgM_DelIgnore(name, quiet)
	name=fixname(name);
	
	if(not list[name] or type(list[name])~="table") then
		if(not quiet) then
			IgM_SysMsg(ERR_IGNORE_NOT_FOUND);
		end
		return false;
	end

	for k,v in pairs(IgM_Idx) do
		if(v==name) then
			tremove(IgM_Idx, k);
			break;
		end
	end
	
	list[name]=0;
	
	if(IgM_SysIgnoreList[name]) then
		orig_DelIgnore(name);
		IgM_SysIgnoreList[name]=nil;
	end
	
	if(not quiet) then
		IgM_SysMsg(format(ERR_IGNORE_REMOVED_S,name));
		IgM_FireFriendEvent("IGNORELIST_UPDATE");
	end
	return true;
end

function DelIgnore(name)
	if(not list) then 
		return orig_DelIgnore(name);
	end
	IgM_DelIgnore(name);
end


-- AddOrDelIgnore

function IgM_AddOrDelIgnore(name, reason, quiet)
	if(list[name] and type(list[name])=="table") then
		IgM_DelIgnore(name,quiet);
	else
		IgM_AddIgnore(name,reason,quiet);
	end
end

function AddOrDelIgnore(name)
	if(not list) then 
		return orig_AddOrDelIgnore(name);
	end
	local _,_,n,r = string.find(name, "^([^ ]+) +(.*)");
	if(n and r and r~="") then
		return IgM_AddIgnore(n, r);
	else
		return IgM_AddOrDelIgnore(name);
	end
end


-- GetIgnoreName

function GetIgnoreName(i)
	if(not list) then
		return orig_GetIgnoreName(i);
	end
	return IgM_Idx[i] or "Unknown";
end


-- GetNumIgnores

function GetNumIgnores()
	if(not list) then
		return orig_GetNumIgnores();
	end
	return getn(IgM_Idx);
end


-- GetSelectedIgnore   (god this is pointless..)

function GetSelectedIgnore()
	if(not list) then
		return orig_GetSelectedIgnore();
	end
	return IgM_SelectedIgnore;
end


-- SetSelectedIgnore   (god this is pointless..)

function SetSelectedIgnore(i)
	if(not list) then
		return orig_SetSelectedIgnore(i);
	end
	IgM_SelectedIgnore = i;
end


-- IgM_GetIgnoreReason
function IgM_GetIgnoreReason(who)
	if(not list) then
		return nil;
	end
	local i = tonumber(who);
	if(i) then
		who=IgM_Idx[i];
	end
	if(not who) then
		return nil;
	end
	if(not list[who]) then
		return nil;
	end
	return list[who].reason or "";
end


-----------------------------------------------------------------------
-- Extend IgnoreList with time and reason info

IgnoreList_Extras = {};


local orig_IgnoreList_Update = IgnoreList_Update;
function IgnoreList_Update()
	
	orig_IgnoreList_Update();
	if(not list or not FriendsFrameIgnoreScrollFrame) then
		return;
	end
	
	local ignoreOffset = FauxScrollFrame_GetOffset(FriendsFrameIgnoreScrollFrame);
	local maxwid=0;
	local buttonwid=0;
	for i=1, IGNORES_TO_DISPLAY, 1 do
		local ignoreIndex = i + ignoreOffset;
		local nameText = getglobal("FriendsFrameIgnoreButton"..i.."ButtonTextName");
		local ignoreButton = getglobal("FriendsFrameIgnoreButton"..i);
		if(nameText and ignoreButton) then
			buttonwid = ignoreButton:GetWidth();
			if(not IgnoreList_Extras[i]) then
				IgnoreList_Extras[i] = ignoreButton:CreateFontString("FontString", "OVERLAY", "GameFontHighlightSmall");
				IgnoreList_Extras[i]:SetJustifyH("LEFT");
				IgnoreList_Extras[i]:SetPoint("BOTTOMRIGHT", ignoreButton);
				IgnoreList_Extras[i]:SetPoint("TOP", ignoreButton);
			end
			
			local txt="";
			maxwid = max(maxwid, nameText:GetStringWidth());
			local entry = list[nameText:GetText()];
			if(entry and type(entry)=="table") then
				if(entry.time) then 
					if(time() - entry.time < 3600*24*200) then
						txt=txt..date("%d %b", entry.time);
					else
						txt=txt..date("%b %Y", entry.time);
					end
				end
				if(entry.reason) then
					txt=txt..": "..entry.reason;
				end
			end
			IgnoreList_Extras[i]:SetText(txt);
		end
	end
	
	for i=1, IGNORES_TO_DISPLAY, 1 do
		if(IgnoreList_Extras[i]) then
			IgnoreList_Extras[i]:SetWidth(buttonwid-maxwid-30);
		end
	end
	
	
end


local last_FriendsFrameIgnoreButton_OnClick = { time=0 }

local orig_FriendsFrameIgnoreButton_OnClick = FriendsFrameIgnoreButton_OnClick;
function FriendsFrameIgnoreButton_OnClick()
	orig_FriendsFrameIgnoreButton_OnClick();
	if(not list) then
		return;
	end
	if(last_FriendsFrameIgnoreButton_OnClick.button == this and 
	   GetTime() - last_FriendsFrameIgnoreButton_OnClick.time < 0.3) then
		StaticPopup_Show("EDIT_IGNORE_REASON");
	end
	
	last_FriendsFrameIgnoreButton_OnClick.button = this;
	last_FriendsFrameIgnoreButton_OnClick.time = GetTime();
end



-----------------------------------------------------------------------
-- Hook ChatFrame_OnEvent() to suppress ignored players

local orig_ChatFrame_OnEvent = ChatFrame_OnEvent;
function ChatFrame_OnEvent(event)
	if(list and strsub(event,1,9)=="CHAT_MSG_" and type(list[arg2])=="table") then
		if(event=="CHAT_MSG_WHISPER_INFORM") then
			arg1=arg1.."  (NOTE: You are ignoring this player!)";
		else
			return;
		end
	end
	return orig_ChatFrame_OnEvent(event);
end

-- And Chatr: Chatr_Event
if(Chatr_Event) then
	local orig_Chatr_Event = Chatr_Event;
	function Chatr_Event()
		if(list and strsub(event,1,9)=="CHAT_MSG_" and type(list[arg2])=="table") then
			if(event=="CHAT_MSG_WHISPER_INFORM") then
				arg1=arg1.."  (NOTE: You are ignoring this player!)";
			else
				return;
			end
		end
		return orig_Chatr_Event(event);
	end
end

-- And ForgottenChat: FC_OnEvent
if(FC_OnEvent) then
	local orig_FC_OnEvent = FC_OnEvent;
	function FC_OnEvent(event)
		if(list and strsub(event,1,9)=="CHAT_MSG_" and type(list[arg2])=="table") then
			if(event=="CHAT_MSG_WHISPER_INFORM") then
				arg1=arg1.."  (NOTE: You are ignoring this player!)";
			else
				return;
			end
		end
		return orig_FC_OnEvent(event);
	end
end


-----------------------------------------------------------------------
-- Initialization


function IgM_Init()

	if(not IgM_SV.enabled) then
		list = nil;
		return;
	end
	
	local realm = GetRealmName() .. "-" .. UnitFactionGroup("player");
	
	if(not IgM_SV.list[realm]) then
		IgM_SV.list[realm] = {}
	end
	
	list = IgM_SV.list[realm];
	
	for i=(orig_GetNumIgnores()),1,-1 do
		local name = orig_GetIgnoreName(i);
		if(not list[name]) then
			list[name] = {time=time(), reason="From "..UnitName("player").."'s system ignore list"};
			IgM_SysIgnoreList[name] = true;
		elseif(type(list[name])~="table") then
			orig_DelIgnore(name);
		else
			IgM_SysIgnoreList[name] = true;
		end
	end
	
	IgM_Idx = {}
	for k,v in pairs(list) do
		if(type(v)=="table") then
			tinsert(IgM_Idx, k);
		end
	end
	
	table.sort(IgM_Idx);
	
	
	StaticPopupDialogs["EDIT_IGNORE_REASON"] = {};
	for k,v in pairs(StaticPopupDialogs["ADD_IGNORE"]) do
		StaticPopupDialogs["EDIT_IGNORE_REASON"][k] = v;
	end
	StaticPopupDialogs["EDIT_IGNORE_REASON"].maxLetters=64;
	StaticPopupDialogs["EDIT_IGNORE_REASON"].text = "Reason for ignoring this player:";
	StaticPopupDialogs["EDIT_IGNORE_REASON"].EditBoxOnEnterPressed = function()
		local editBox = getglobal(this:GetParent():GetName().."EditBox");
		IgM_AddIgnore(GetIgnoreName(GetSelectedIgnore()), editBox:GetText());
		this:GetParent():Hide();
	end
	StaticPopupDialogs["EDIT_IGNORE_REASON"].OnAccept = StaticPopupDialogs["EDIT_IGNORE_REASON"].EditBoxOnEnterPressed;
	StaticPopupDialogs["EDIT_IGNORE_REASON"].OnShow = function()
		getglobal(this:GetName().."EditBox"):SetText(IgM_GetIgnoreReason(GetSelectedIgnore()));
		getglobal(this:GetName().."EditBox"):SetFocus();
	end
	
end


IgM_Frame = CreateFrame("Frame");
IgM_Frame:SetScript("OnEvent", IgM_Init);
IgM_Frame:RegisterEvent("PLAYER_LOGIN");

