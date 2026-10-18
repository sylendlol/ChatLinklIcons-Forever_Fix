--[[	ChatLinkIcons - Link Processor Tools
	by SDPhantom
	https://www.wowinterface.com/forums/member.php?u=34145
	https://www.curseforge.com/members/sdphantomgamer/projects	]]
--------------------------------------------------------------------------

local AddOn=select(2,...);
local GetSpellTexture=GetSpellTexture or (C_Spell and C_Spell.GetSpellTexture) or function() return nil; end;--	Moved in TWW, hasn't happened in Classic yet
--	WoW Forever (16001) patch: GetItemIcon was removed, fall back to C_Item / GetItemInfoInstant
local GetItemIcon=GetItemIcon or (C_Item and C_Item.GetItemIconByID) or function(itemid)
	local GetInstant=GetItemInfoInstant or (C_Item and C_Item.GetItemInfoInstant);
	if GetInstant then return select(5,GetInstant(itemid)); end
	return nil;
end;

local UnknownIconMarkup="|TInterface\\Icons\\INV_Misc_QuestionMark:0|t";

local RaceAtlasMap={
	Scourge="Undead";
	HighmountainTauren="Highmountain";
	LightforgedDraenei="Lightforged";
	ZandalariTroll="Zandalari";
	EarthenDwarf="Earthen";
	Harronir="Haranir";
};

local RaceAtlasMarkupCache; do
	local RaceAtlasPrefixOrder={
		"raceicon128";
		"raceicon";
	};

	RaceAtlasMarkupCache=setmetatable({},{__index=function(t,k)
		for _,prefix in ipairs(RaceAtlasPrefixOrder) do
			local atlas=("%s-%s"):format(prefix,k);
			if C_Texture.GetAtlasInfo(atlas) then
				local markup=CreateAtlasMarkup(atlas);
				t[k]=markup;
				return markup;
			end
		end

		return nil;
	end});
end

local ClassAtlasMarkupCache; do
	local function CreateTextureMarkupFromGrid(file,filew,fileh,x,y,tilew,tileh)
		return CreateTextureMarkup(file,filew,fileh,0,0,GetTexCoordsByGrid(x,y,filew,fileh,tilew,tileh));
	end

	local FallbackClassMarkups={};
	for k,v in pairs({
		MONK={"Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES",256,256,3,3,64,64};
	}) do FallbackClassMarkups[k]=CreateTextureMarkupFromGrid(unpack(v)); end

	ClassAtlasMarkupCache=setmetatable({},{__index=function(t,k)
		local atlas=GetClassAtlas(k);
		if C_Texture.GetAtlasInfo(atlas) then
			local markup=CreateAtlasMarkup(atlas);
			t[k]=markup;
			return markup;
		end

		if FallbackClassMarkups[k] then
			local markup=FallbackClassMarkups[k];
			t[k]=markup;
			return markup
		end

		return nil;
	end});
end

function AddOn.LinkProcessorTools_CreateTextureMarkup(path) return path and ("|T%s:0|t"):format(tostring(path)); end
function AddOn.LinkProcessorTools_CreateTextureMarkupFromItemID(itemid) return itemid and AddOn.LinkProcessorTools_CreateTextureMarkup(GetItemIcon(itemid)); end
function AddOn.LinkProcessorTools_CreateTextureMarkupFromSpellID(spellid) return spellid and AddOn.LinkProcessorTools_CreateTextureMarkup(GetSpellTexture(spellid)); end

function AddOn.LinkProcessorTools_CreateTextureMarkupFromPlayerGUID(guid)
	if not guid then return nil; end

--	GenderID is 2=Male 3=Female
	local _,class,_,race,gender=GetPlayerInfoByGUID(guid);

	race,class=
		AddOn.Options.Links_Player_Race
			and ((race and gender) and RaceAtlasMarkupCache[("%s-%s"):format(RaceAtlasMap[race] or race,gender==3 and "female" or "male")] or UnknownIconMarkup)
			or nil
		,AddOn.Options.Links_Player_Class
			and (class and ClassAtlasMarkupCache[class] or UnknownIconMarkup)
			or nil;
	return (race and class) and race..class or (race or class);
end

function AddOn.LinkProcessorTools_CreateTextureMarkupFromPlayerName(name)
	return AddOn.LinkProcessorTools_CreateTextureMarkupFromPlayerGUID(AddOn.PlayerCache_GetPlayerGUID(name));
end



--[[	Debug: Prints out a list of found race and class atlases
--	Race atlases are shown in a grid comparing variants

function SlashCmdList.CLI_ATLASTEST()
	local classes={};
	local prefixes,races,genders={},{},{};

	for _,atlas in ipairs(C_Texture.GetAtlasElements()) do
		local class=atlas:match("^classicon%-(.*)");
		if class then table.insert(classes,class); end

		local prefix,race,gender=atlas:match("^(raceicon.-)%-(.*)%-(.-)$");
		if prefix and race and gender then
			if not prefixes[prefix] then
				table.insert(prefixes,prefix);
				prefixes[prefix]=true;
			end

			if not races[race] then
				table.insert(races,race);
				races[race]=true;
			end

			if not genders[gender] then
				table.insert(genders,gender);
				genders[gender]=true;
			end
		end
	end

	table.sort(classes);
	table.sort(prefixes);
	table.sort(races);
	table.sort(genders);

	for _,class in ipairs(classes) do print(ClassAtlasMarkupCache[class],class); end
	print("Classes:",#classes);

	print(" ");
	print(table.concat(prefixes," || "));
	for _,race in ipairs(races) do
		local prefixentries={};
		for _,prefix in ipairs(prefixes) do
			local genderentries={};
			for _,gender in ipairs(genders) do
				local atlas=("%s-%s-%s"):format(prefix,race,gender);
				table.insert(genderentries,C_Texture.GetAtlasInfo(atlas) and CreateAtlasMarkup(atlas) or UnknownIconMarkup);
			end
			table.insert(prefixentries,table.concat(genderentries,""));
		end
		print(table.concat(prefixentries,"    "),race);
	end

	print(("Prefixes: %d || Races: %d || Genders: %d"):format(#prefixes,#races,#genders));
end
SLASH_CLI_ATLASTEST1="/cliatlastest";
--]]
