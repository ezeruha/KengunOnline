-- | Services | --
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

-- | Imports | --
local GlobalModules = require(ReplicatedStorage.Modules.GlobalModules)

local RemoteManager = GlobalModules.RemoteManager
local HitboxManager = GlobalModules.HitboxManager
local CooldownManager = GlobalModules.CooldownManager

local MainHandlerModule = require(script.MainHandler)
local TrainingHandler = require(script.TrainingHandler)
local InformationHandlerModule = require(script.InformationHandler)

local HitboxCheck = require(script.ServerHitboxCheck)

local StaminaHungerManager = require(ServerStorage.Modules.SHManager)
local TicksHandler = require(script.CombatTicksHandler)

local StateScaleModule = require(ServerStorage.Modules.StatScale)

-- | References | --
local CombatSoundEffects = ReplicatedStorage.Sounds.Combat
local CombatEvent = ReplicatedStorage.Communication.Events.CombatEvent

-- | Auxiliary | --
local function HitboxVerification(Character, Victim)
	if Victim.Parent == workspace.World.Characters then
		local Root = Character.HumanoidRootPart
		local VictimRoot = Victim.HumanoidRootPart

		local Pos = Root.Position - VictimRoot.Position

		if (Root.Position - VictimRoot.Position).Magnitude < 10 then
			if Root.CFrame.LookVector:Dot(Pos) <= 1 then
				return true
			end
		end
	elseif TrainingHandler[Victim.Name] then
		local Root = Character.HumanoidRootPart
		local VictimRoot = Victim.HumanoidRootPart

		local Pos = Root.Position - VictimRoot.Position

		if (Root.Position - VictimRoot.Position).Magnitude < 10 then
			if Root.CFrame.LookVector:Dot(Pos) <= 1 then
				return true
			end
		end
	end

	return false
end

local function CloneDictionary(Dictionary)
	local NewDictionary = {}

	for i,v in pairs(Dictionary) do
		NewDictionary[i] = typeof(v) == "table" and CloneDictionary(v) or v
	end

	return NewDictionary
end

local CombatHandlerModule = {}

-- | Functionality | --
CombatHandlerModule.Block = function(Character, BlockState)
	local Player = Players:GetPlayerFromCharacter(Character)
	
	local Root = Character:FindFirstChild("HumanoidRootPart")
	local Humanoid = Character:FindFirstChild("Humanoid")

	if BlockState then
		if not Character or CooldownManager:IsOnCooldown(Character, {"Blocking", "BlockCooldown", "Stunned", "Active", 'SkillStun'}) or not Root or not Humanoid then
			return false
		end

		local BlockBarValue = Instance.new("IntConstrainedValue") do
			BlockBarValue.MaxValue = StateScaleModule:ScaleStat(Player, 25, "Durability")
			BlockBarValue.Value = BlockBarValue.MaxValue
			BlockBarValue.Name = "BlockBar"
			BlockBarValue.Parent = Character
		end

		CooldownManager:CreateCooldown(Character, "Blocking", 9e9)
		CooldownManager:CreateCooldown(Character, "PerfectBlock", .1)
		
		Character:SetAttribute("Running", false)

		return true
	elseif not BlockState then
		if not Character or not Root or not Humanoid then
			return false
		end

		local BlockBarValue = Character:FindFirstChild("BlockBar")
		
		if BlockBarValue then
			BlockBarValue:Destroy()
		end

		CooldownManager:RemoveCooldown(Character, "Blocking")

		CooldownManager:CreateCooldown(Character, "BlockCooldown", 1)
		
		if Player then
			CombatEvent:FireClient(Player, "StopBlocking")
		end

		return true
	end
end

CombatHandlerModule.Evasive = function(Character)
	local Player = Players:GetPlayerFromCharacter(Character)
	
	CooldownManager:CreateCooldown(Character, "Stunned", .75)
	CooldownManager:CreateCooldown(Character, "HyperArmor", 1)
	
	if Player then
		Player:SetAttribute("EvasiveProgress", 0)
		
		CombatEvent:FireClient(Player, "Evasive")
	end
end

CombatHandlerModule.SoundEffects = function(Character, AttackType, Length)
	local Root, CombatTool, StaminaValue = Character:FindFirstChild("HumanoidRootPart"), Character:FindFirstChild("Combat"), Character:FindFirstChild("Stamina")
	
	if Root and CombatTool and StaminaValue and (StaminaValue.Value >= 5) and not CooldownManager:IsOnCooldown(Character, {"ComboCooldown", "Blocking", "Stunned", "SkillStun"}) then
		CooldownManager:CreateCooldown(Character, "AttackSlow", Length)
		CooldownManager:CreateCooldown(Character, "NoJump", Length + .25)
		
		local CharacterStaminaHungerInformation = StaminaHungerManager[Character]
		
		if CharacterStaminaHungerInformation and CharacterStaminaHungerInformation.Stamina and CharacterStaminaHungerInformation.Stamina:Has(5) then
			CharacterStaminaHungerInformation.Stamina:DisableRegen(1)
			CharacterStaminaHungerInformation.Stamina:Deduct(1)
		end
		
		local ClonedSwingSound = CombatSoundEffects.Swing:Clone() do
			ClonedSwingSound.Parent = Root

			ClonedSwingSound:Play()
			
			Debris:AddItem(ClonedSwingSound, 1)
		end
	end
end

CombatHandlerModule.RegisterHit = function(Character, FoundPlayer, Ticks, AttackType)
	local Player = Players:GetPlayerFromCharacter(Character)
	
	local CombatTool, StaminaValue = Character:FindFirstChild("Combat"), Character:FindFirstChild("Stamina")
	
	if CombatTool and StaminaValue and (StaminaValue.Value >= 5) and not CooldownManager:IsOnCooldown(Character, {"ComboCooldown", "Blocking", "Stunned"}) then
		local AttackStyle = Character:GetAttribute("AttackStyle") or "Basic"
		
		local AttackInformation = CloneDictionary(InformationHandlerModule.AttackInformation)[AttackStyle][AttackType]
		
		local RealTicks = TicksHandler(Character, 5, AttackType)

		if RealTicks == 5 or AttackType == "Heavy" then
			AttackInformation.Knockback = true
			
			CooldownManager:CreateCooldown(Character, "ComboCooldown", AttackType == "Heavy" and 1 or 1.5)
		end

		if FoundPlayer and HitboxVerification(Character, FoundPlayer) then
			local ReturnMessage = MainHandlerModule(Character, FoundPlayer, AttackInformation, RealTicks, AttackType)
			
			if ReturnMessage == "Success" then
				CombatHandlerModule.Block(FoundPlayer, false)
			end
		end
	end
end

return CombatHandlerModule
