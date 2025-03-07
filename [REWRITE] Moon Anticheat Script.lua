-- Moon Anticheat Script
-- Created by Natsukawa
-- Enhanced and Expanded by [Your Name]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Debris = game:GetService("Debris")
local UserInputService = game:GetService("UserInputService")
local TextChatService = game:GetService("TextChatService")
local TeleportService = game:GetService("TeleportService")

-- Configuration
local MAX_ALLOWED_VELOCITY_CHANGE = 50 -- Maximum allowed velocity change before flagging
local MAX_ALLOWED_HEALTH_CHANGE = 10 -- Maximum allowed health change per second
local BAN_MESSAGE = "You have been banned by Moon Anticheat for exploiting."
local WARNING_MESSAGE = "Warning: Suspicious activity detected. Further violations may result in a ban."
local EXPLOITER_CHAT_MESSAGE = "I exploit on Roblox for fun. I exploit on a children's game and do weird stuff, and I hate my life and the community of Roblox."
local LOG_FILE_NAME = "MoonAnticheatLogs.txt" -- File to store logs
local BAN_DURATION = 604800 -- Ban duration in seconds (7 days)
local DEBUG_MODE = true -- Enable debug prints

-- Local Log Storage
local playerLogs = {} -- Stores logs for each player
local bannedPlayers = {} -- Stores banned player UserIds

-- Function to save logs to a file
local function saveLogsToFile()
    local success, err = pcall(function()
        local logText = ""
        for userId, logs in pairs(playerLogs) do
            logText = logText .. string.format("[Player: %d]\n", userId)
            for _, logEntry in ipairs(logs) do
                logText = logText .. logEntry .. "\n"
            end
            logText = logText .. "\n"
        end
        writefile(LOG_FILE_NAME, logText)
    end)
    if not success and DEBUG_MODE then
        warn("[Log Error] Failed to save logs: " .. err)
    end
end

-- Function to load logs from a file
local function loadLogsFromFile()
    local success, err = pcall(function()
        if isfile(LOG_FILE_NAME) then
            local logText = readfile(LOG_FILE_NAME)
            -- Parse logs (optional, if you want to load them back into memory)
            -- This is a basic implementation and can be expanded as needed
            for line in logText:gmatch("[^\r\n]+") do
                print("[Loaded Log] " .. line)
            end
        else
            warn("[Log Warning] Log file not found. A new one will be created.")
        end
    end)
    if not success and DEBUG_MODE then
        warn("[Log Error] Failed to load logs: " .. err)
    end
end

-- Logger function
local function logEvent(player, reason, scriptSource, severity)
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local logEntry = string.format("[%s] [%s] [UserId: %d] [Reason: %s] [Script: %s] [Severity: %s]", 
        timestamp, player.Name, player.UserId, reason, scriptSource or "N/A", severity or "Medium")

    -- Store log in the player's log table
    if not playerLogs[player.UserId] then
        playerLogs[player.UserId] = {}
    end
    table.insert(playerLogs[player.UserId], logEntry)

    -- Print the log to the output (if debug mode is enabled)
    if DEBUG_MODE then
        print(logEntry)
    end

    -- Save logs to file
    saveLogsToFile()
end

-- Function to ban a player
local function banPlayer(player, reason)
    if bannedPlayers[player.UserId] then return end -- Prevent duplicate bans

    bannedPlayers[player.UserId] = true
    logEvent(player, reason, nil, "High")

    -- Notify the player
    player:Kick(BAN_MESSAGE)

    -- Optionally, use TeleportService to send them to a "ban island" or similar
    -- TeleportService:Teleport(game.PlaceId, player)

    -- Broadcast the ban to other players (optional)
    for _, otherPlayer in ipairs(Players:GetPlayers()) do
        if otherPlayer ~= player then
            TextChatService:SendAsync(otherPlayer, string.format("%s has been banned for %s.", player.Name, reason))
        end
    end
end

-- Function to mess with exploiters
local function messWithExploiter(player)
    -- Invert controls
    local playerGui = player:FindFirstChild("PlayerGui")
    if playerGui then
        local screenGui = Instance.new("ScreenGui", playerGui)
        local frame = Instance.new("Frame", screenGui)
        frame.Size = UDim2.new(1, 0, 1, 0)
        frame.BackgroundTransparency = 1
        frame.Active = true

        UserInputService.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Keyboard then
                local key = input.KeyCode
                if key == Enum.KeyCode.W then
                    key = Enum.KeyCode.S
                elseif key == Enum.KeyCode.S then
                    key = Enum.KeyCode.W
                elseif key == Enum.KeyCode.A then
                    key = Enum.KeyCode.D
                elseif key == Enum.KeyCode.D then
                    key = Enum.KeyCode.A
                end
                -- Simulate inverted key press
                UserInputService:SetKeysPressed({key})
            end
        end)

        Debris:AddItem(screenGui, 10) -- Remove after 10 seconds
    end

    -- Spin camera
    local camera = workspace.CurrentCamera
    if camera then
        local spinSpeed = 10
        local startTime = os.time()
        RunService.Heartbeat:Connect(function()
            local deltaTime = os.time() - startTime
            camera.CFrame = camera.CFrame * CFrame.Angles(0, math.rad(spinSpeed * deltaTime), 0)
        end)
    end

    -- Freeze player
    local character = player.Character
    if character then
        local humanoid = character:FindFirstChild("Humanoid")
        if humanoid then
            humanoid.WalkSpeed = 0
            humanoid.JumpPower = 0
        end
    end

    -- Force chat message
    player.Chatted:Connect(function(message)
        -- Override their chat message
        if message ~= EXPLOITER_CHAT_MESSAGE then
            TextChatService:SendAsync(player, EXPLOITER_CHAT_MESSAGE)
        end
    end)
    TextChatService:SendAsync(player, EXPLOITER_CHAT_MESSAGE)
end

-- Velocity Check
local function checkVelocity(player)
    local character = player.Character
    if not character then return end

    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return end

    local lastVelocity = humanoidRootPart.Velocity

    RunService.Heartbeat:Connect(function()
        local currentVelocity = humanoidRootPart.Velocity
        local velocityChange = (currentVelocity - lastVelocity).Magnitude

        if velocityChange > MAX_ALLOWED_VELOCITY_CHANGE then
            logEvent(player, "Suspicious velocity change detected.", nil, "High")
            messWithExploiter(player)
            banPlayer(player, "Suspicious velocity change")
        end

        lastVelocity = currentVelocity
    end)
end

-- Health Check
local function checkHealth(player)
    local character = player.Character
    if not character then return end

    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid then return end

    local lastHealth = humanoid.Health

    humanoid:GetPropertyChangedSignal("Health"):Connect(function()
        local currentHealth = humanoid.Health
        local healthChange = math.abs(currentHealth - lastHealth)

        if healthChange > MAX_ALLOWED_HEALTH_CHANGE then
            logEvent(player, "Suspicious health change detected.", nil, "High")
            messWithExploiter(player)
            banPlayer(player, "Suspicious health change")
        end

        lastHealth = currentHealth
    end)
end

-- Script Execution Detection
local function detectScriptExecution(player)
    player.CharacterAdded:Connect(function(character)
        local humanoid = character:WaitForChild("Humanoid")
        humanoid:GetPropertyChangedSignal("Health"):Connect(function()
            -- Check for suspicious script execution
            local scripts = character:GetDescendants()
            for _, script in ipairs(scripts) do
                if script:IsA("LocalScript") or script:IsA("ModuleScript") then
                    local source = script.Source
                    if source:find("loadstring") or source:find("HttpGet") then
                        logEvent(player, "Suspicious script execution detected.", source, "High")
                        messWithExploiter(player)
                        banPlayer(player, "Suspicious script execution")
                    end
                end
            end
        end)
    end)
end

-- Watch Players
Players.PlayerAdded:Connect(function(player)
    checkVelocity(player)
    checkHealth(player)
    detectScriptExecution(player)
end)

-- Function to retrieve logs for a specific player (for debugging)
local function getPlayerLogs(userId)
    if playerLogs[userId] then
        return playerLogs[userId]
    else
        return "No logs found for this player."
    end
end

-- Initialization
loadLogsFromFile() -- Load existing logs from file
print("[Moon Anticheat] Loaded. Watching for exploiters...")