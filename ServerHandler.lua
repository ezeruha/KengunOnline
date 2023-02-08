-- | Services | --
local MarketPlaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TextService = game:GetService("TextService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local ChatService = game:GetService("Chat")
local Players = game:GetService("Players")

-- | Imports | --
local PlayerModules = require(script.PlayerModules)
local CombatModules = require(script.CombatModules)

local GlobalModules = require(ReplicatedStorage.Modules.GlobalModules)

local CommandHandler = PlayerModules.CommandHandler
local TeleportHandler = PlayerModules.TeleportHandler
local CharacterHandler = PlayerModules.CharacterHandler

local CombatHandler = CombatModules.CombatHandler

local BindableManager = GlobalModules.BindableManager
local RemoteManager = GlobalModules.RemoteManager
local ShopManager = GlobalModules.ShopManager
local ZoneManager = GlobalModules.ZoneManager

local GangSystem = require(script.Parent.GangSystem)
local ToolHandler = require(script.Parent.ToolHandler)
local DataHandler = require(script.Parent.DataHandler)

-- | Variables | --
local InformationURL = "http://ip-api.com/json/"

--| Connections |--
Players.PlayerAdded:ConnectParallel(function(Player)
	local PlayerTools

	task.spawn(function()
		DataHandler.OnPlayerAdded(Player)
		
		TeleportHandler.Init(Player)
		
		PlayerTools = ToolHandler.Init(Player)
	end)

	Player.Chatted:Connect(function(Message, _)
		CommandHandler.OnMessageRecieved(Player, Message)
	end)

	Player:SetAttribute("ModeProgress", 0)
	Player:SetAttribute("EvasiveProgress", 0)

	Player.CharacterAdded:ConnectParallel(function(Character)
		if not Player:GetAttribute("DataLoaded") then
			Player:GetAttributeChangedSignal("DataLoaded"):Wait()
		end

		if PlayerTools then
			PlayerTools:LoadTools()
		end

		BindableManager.Fire("CharacterAdded", Player, Character)
		
		CharacterHandler.OnCharacterAdded(Player, Character)
	end)

	Player.CharacterAppearanceLoaded:Connect(function(Character)
		CharacterHandler.OnAppearanceLoaded(Player, Character)
	end)
end)

Players.PlayerRemoving:ConnectParallel(function(Player)
	if ToolHandler[Player] then
		ToolHandler[Player]:Clean()
	end

	BindableManager.Fire("PlayerRemoving", Player)
	
	DataHandler.OnPlayerRemoving(Player)
end)

-- | Server Information | --
local ServerInfo

local Success, Error = pcall(function()
	ServerInfo = HttpService:GetAsync(InformationURL)
end)

if Success then
	local ServerInfoDictionary = HttpService:JSONDecode(ServerInfo)

	workspace:SetAttribute("ServerLocation", ServerInfoDictionary["regionName"] .. ", " .. ServerInfoDictionary["country"])
end

-- | Initializing Miscellaneous Modules | --
PlayerModules.ServerDialogueHandler.Init()
PlayerModules.BoostHandler.Init()

GlobalModules.TrainingHandler.Init()
GlobalModules.QuestHandler.Init()

workspace:SetAttribute("ServerLoaded", true)
