--[[	ChatLinkIcons - EllesmereUI Chat Integration (local patch for WoW Forever 16001)
	EllesmereUIChat shows chat in its OWN ScrollingMessageFrame per window
	(somewhere under EllesmereUI._chatCFD(cf).bg); Blizzard's ChatFrameN stays
	invisible underneath for link hit-zones. DefaultUI.lua already puts icons
	into those invisible frames; here the text is converted as it is written
	into Ellesmere's visible frames (AddMessage / BackFillMessage), so both
	renderings stay identical and the click zones stay aligned.
	Only Ellesmere's own unnamed (addon-created) frames are touched, never Blizzard's named chat frames.
	/clidebug prints what was found.	]]
--------------------------------------------------------------------------

local AddOn=select(2,...);

local Wrapped={};		-- [smf]=true
local GuidStats;
local LastScan={windows=0,found=0,cfd=false};

local function Convert(msg)
	if type(msg)~="string" then return msg; end
	if issecretvalue and issecretvalue(msg) then return msg; end
	if canaccessvalue and not canaccessvalue(msg) then return msg; end
	local ok,res=pcall(AddOn.LinkConverter_ConvertLinks,msg);
	return (ok and type(res)=="string") and res or msg;
end

local function WrapFrame(smf)
	if Wrapped[smf] then return; end
	Wrapped[smf]=true;

	local orig_AddMessage=smf.AddMessage;
	smf.AddMessage=function(self,msg,...) return orig_AddMessage(self,Convert(msg),...); end

	local orig_BackFill=smf.BackFillMessage;
	if orig_BackFill then
		smf.BackFillMessage=function(self,msg,...) return orig_BackFill(self,Convert(msg),...); end
	end
end

local function FindSMFs(frame,cf,depth,out)
	if depth>4 or not (frame and frame.GetChildren) then return; end
	for _,child in ipairs({frame:GetChildren()}) do
		if child~=cf and not (child.GetName and child:GetName()) and type(child.AddMessage)=="function" and type(child.GetNumMessages)=="function"
			and (child.BackFillMessage or child.SetOnScrollChangedCallback or child.AdjustMessageColors) then
			out[#out+1]=child;
		end
		FindSMFs(child,cf,depth+1,out);
	end
end

local function Scan()
	local EUI=_G.EllesmereUI;
	local CFD=EUI and EUI._chatCFD;
	LastScan.cfd=type(CFD)=="function";
	LastScan.windows,LastScan.found=0,0;
	if not LastScan.cfd then return; end

	for i=1,20 do
		local cf=_G["ChatFrame"..i];
		local d=cf and CFD(cf);
		local bg=d and d.bg;
		if bg then
			LastScan.windows=LastScan.windows+1;
			local list={};
			FindSMFs(bg,cf,1,list);
			for _,smf in ipairs(list) do
				LastScan.found=LastScan.found+1;
				WrapFrame(smf);
			end
		end
	end
end

--	Ellesmere builds its windows after login (and again for pop-out / temporary
--	windows), so scan after entering the world and then periodically (cheap).
local ticker;
EventRegistry:RegisterFrameEventAndCallback("PLAYER_ENTERING_WORLD",function()
	C_Timer.After(0.5,Scan);
	C_Timer.After(3,Scan);
	if not ticker then ticker=C_Timer.NewTicker(3,Scan); end
end);

SLASH_CHATLINKICONSDEBUG1="/clidebug";
SlashCmdList.CHATLINKICONSDEBUG=function()
	Scan();
	local n=0; for _ in pairs(Wrapped) do n=n+1; end
	print(("|cff33ff99ChatLinkIcons|r EllesmereUI: CFD=%s, windows=%d, SMF found=%d, wrapped total=%d")
		:format(tostring(LastScan.cfd),LastScan.windows,LastScan.found,n));
	local cf=_G.ChatFrame1; local EUI=_G.EllesmereUI;
	local d=cf and EUI and EUI._chatCFD and EUI._chatCFD(cf);
	if d and d.bg then
		local t={};
		for _,c in ipairs({d.bg:GetChildren()}) do t[#t+1]=(c.GetObjectType and c:GetObjectType() or "?")..(c.AddMessage and "+AM" or ""); end
		print("|cff33ff99ChatLinkIcons|r ChatFrame1 bg children: "..table.concat(t,", "));
	end
	print("|cff33ff99ChatLinkIcons|r test: "..Convert("|cffffffff|Hitem:6948::::::::1:::::::::|h[Hearthstone]|h|r"));
end

--	Player-icon timing fix: PlayerCache learns name->GUID from CHAT_MSG_* events via
--	EventRegistry, which can fire AFTER the chat frame has already written the line.
--	Default UI re-renders later, but Ellesmere's frames get the text once (AddMessage),
--	so a first-time speaker got no icon. A message event filter runs inside the chat
--	frame's handler BEFORE the line is formatted/added, so the GUID is cached in time.
--	It never changes or blocks the message (returns false).
if ChatFrame_AddMessageEventFilter then
	GuidStats={ok=0,noguid=0,noinfo=0,secret=0};
	SLASH_CHATLINKICONSGUID1="/cliguid";
	SlashCmdList.CHATLINKICONSGUID=function()
		print(("|cff33ff99ChatLinkIcons|r GUID: ok=%d, missing GUID=%d (last: %s), GUID but no class info=%d (last: %s), secret=%d")
			:format(GuidStats.ok,GuidStats.noguid,tostring(GuidStats.lastNoGuid),GuidStats.noinfo,tostring(GuidStats.lastNoInfo),GuidStats.secret));
	end
	local function CacheFilter(_,_,_,author,_,_,_,_,_,_,_,_,_,guid)--	(self,event,msg,author,arg3..arg11,guid=arg12)
		if canaccessvalue and not (canaccessvalue(author) and canaccessvalue(guid)) then GuidStats.secret=GuidStats.secret+1; return false; end
		if issecretvalue and (issecretvalue(author) or issecretvalue(guid)) then GuidStats.secret=GuidStats.secret+1; return false; end
		if type(author)=="string" and author~="" and type(guid)=="string" and guid~="" then
			GuidStats.ok=GuidStats.ok+1;
			AddOn.PlayerCache_AddPlayer(author,guid);
			local _,class=GetPlayerInfoByGUID(guid);
			if not class then GuidStats.noinfo=GuidStats.noinfo+1; GuidStats.lastNoInfo=author; end
		elseif type(author)=="string" and author~="" then
			GuidStats.noguid=GuidStats.noguid+1; GuidStats.lastNoGuid=author;
		end
		return false;
	end
	for _,event in ipairs({
		"CHAT_MSG_CHANNEL","CHAT_MSG_SAY","CHAT_MSG_YELL","CHAT_MSG_WHISPER","CHAT_MSG_WHISPER_INFORM",
		"CHAT_MSG_PARTY","CHAT_MSG_PARTY_LEADER","CHAT_MSG_RAID","CHAT_MSG_RAID_LEADER","CHAT_MSG_RAID_WARNING",
		"CHAT_MSG_GUILD","CHAT_MSG_OFFICER","CHAT_MSG_EMOTE","CHAT_MSG_TEXT_EMOTE",
		"CHAT_MSG_INSTANCE_CHAT","CHAT_MSG_INSTANCE_CHAT_LEADER","CHAT_MSG_AFK","CHAT_MSG_DND",
	}) do ChatFrame_AddMessageEventFilter(event,CacheFilter); end
end
