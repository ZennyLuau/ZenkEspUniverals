local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

local SETTINGS = {
    ShowTracers = true, 
    ESP_Color = Color3.fromRGB(150, 0, 255), -- PURPLE (3D Boxes & Lines)
    Text_Color = Color3.fromRGB(255, 128, 0), -- ORANGE (Names & Distance)
    LineThickness = 1.5
}
-- ==========================================

local guiTarget = (gethui and gethui()) or (pcall(function() return CoreGui.Name end) and CoreGui) or LocalPlayer:WaitForChild("PlayerGui")


if guiTarget:FindFirstChild("MyESP_GUI") then guiTarget.MyESP_GUI:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "MyESP_GUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = guiTarget

local ESP_DATA = {}

local function formatDist(dist)
    dist = math.floor(dist)
    if dist >= 1000 then
        return string.format("%.1f", dist / 1000) .. "k"
    end
    return tostring(dist)
end

-- Math function to get the 8 corners of the 3D Box
local function GetCorners(cframe, size)
    local half = size / 2
    return {
        cframe * CFrame.new(-half.X,  half.Y, -half.Z),  -- Top 4
        cframe * CFrame.new( half.X,  half.Y, -half.Z),
        cframe * CFrame.new( half.X,  half.Y,  half.Z),
        cframe * CFrame.new(-half.X,  half.Y,  half.Z),
        cframe * CFrame.new(-half.X, -half.Y, -half.Z),  -- Bottom 4
        cframe * CFrame.new( half.X, -half.Y, -half.Z),
        cframe * CFrame.new( half.X, -half.Y,  half.Z),
        cframe * CFrame.new(-half.X, -half.Y,  half.Z),
    }
end

-- Initializes the empty ESP UI for a player
local function createESP(plr)
    if plr == LocalPlayer or ESP_DATA[plr] then return end

    -- Create 12 Lines for the 3D Box
    local boxLines = {}
    if Drawing then
        for i = 1, 12 do
            local line = Drawing.new("Line")
            line.Color = SETTINGS.ESP_Color
            line.Thickness = SETTINGS.LineThickness
            line.Transparency = 1
            line.Visible = false
            boxLines[i] = line
        end
    end

    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.new(0, 220, 0, 40)
    billboard.StudsOffset = Vector3.new(0, 3.5, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = ScreenGui

    local text = Instance.new("TextLabel")
    text.BackgroundTransparency = 1
    text.Size = UDim2.new(1, 0, 1, 0)
    text.TextColor3 = SETTINGS.Text_Color
    text.TextStrokeTransparency = 1 
    text.TextSize = 16
    text.Font = Enum.Font.SourceSansBold
    text.Parent = billboard

    local tracerLine = nil
    if Drawing and SETTINGS.ShowTracers then
        tracerLine = Drawing.new("Line")
        tracerLine.Thickness = SETTINGS.LineThickness
        tracerLine.Transparency = 1
        tracerLine.Color = SETTINGS.ESP_Color
    end

    -- Store the UI elements and empty cache slots
    ESP_DATA[plr] = {
        boxLines = boxLines, billboard = billboard, text = text, tracerLine = tracerLine,
        char = nil, root = nil, head = nil, hum = nil
    }
end

-- Setup existing players
for _, plr in ipairs(Players:GetPlayers()) do
    createESP(plr)
end
Players.PlayerAdded:Connect(createESP)

-- 🚀 HIGH-PERFORMANCE LOOP
local connection = RunService.RenderStepped:Connect(function()
    local myChar = LocalPlayer.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local cam = workspace.CurrentCamera
    
    if not myRoot or not cam then 
        for _, data in pairs(ESP_DATA) do
            for _, line in ipairs(data.boxLines) do line.Visible = false end
            data.billboard.Enabled = false
            if data.tracerLine then data.tracerLine.Visible = false end
        end
        return 
    end

    local vp = cam.ViewportSize
    local bottom = Vector2.new(vp.X * 0.5, vp.Y - 5)

    for plr, data in pairs(ESP_DATA) do
        local char = plr.Character

        -- CACHE SYSTEM
        if char ~= data.char then
            data.char = char
            data.root = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso"))
            data.head = char and char:FindFirstChild("Head")
            data.hum = char and char:FindFirstChildOfClass("Humanoid")
            
            data.billboard.Adornee = data.head
        end

        -- Hide if not loaded or dead
        if not data.char or not data.root or not data.root.Parent or not data.hum or data.hum.Health <= 0 then
            for _, line in ipairs(data.boxLines) do line.Visible = false end
            data.billboard.Enabled = false
            if data.tracerLine then data.tracerLine.Visible = false end
            continue
        end

        local dist = (myRoot.Position - data.root.Position).Magnitude
        
        -- 3D Box Math
        local size = data.char:GetExtentsSize() * 1.1 -- Padding for perfect fit
        local corners3D = GetCorners(data.root.CFrame, size)
        local screenPoints = {}
        local onScreen = true
        
        for i, cf in ipairs(corners3D) do
            local pos, visible = cam:WorldToViewportPoint(cf.Position)
            screenPoints[i] = Vector2.new(pos.X, pos.Y)
            if not visible then onScreen = false end
        end

        -- Update Text
        data.text.Text = plr.Name .. "\n[" .. formatDist(dist) .. "m]"
        
        -- If player is completely on screen, draw the box and lines
        if onScreen then
            local lines = data.boxLines
            -- Top face
            lines[1].From = screenPoints[1]; lines[1].To = screenPoints[2]
            lines[2].From = screenPoints[2]; lines[2].To = screenPoints[3]
            lines[3].From = screenPoints[3]; lines[3].To = screenPoints[4]
            lines[4].From = screenPoints[4]; lines[4].To = screenPoints[1]
            -- Bottom face
            lines[5].From = screenPoints[5]; lines[5].To = screenPoints[6]
            lines[6].From = screenPoints[6]; lines[6].To = screenPoints[7]
            lines[7].From = screenPoints[7]; lines[7].To = screenPoints[8]
            lines[8].From = screenPoints[8]; lines[8].To = screenPoints[5]
            -- Vertical edges
            lines[9].From = screenPoints[1]; lines[9].To = screenPoints[5]
            lines[10].From = screenPoints[2]; lines[10].To = screenPoints[6]
            lines[11].From = screenPoints[3]; lines[11].To = screenPoints[7]
            lines[12].From = screenPoints[4]; lines[12].To = screenPoints[8]

            for _, line in ipairs(lines) do line.Visible = true end
            data.billboard.Enabled = true

            -- Tracker Line
            local rootPos = cam:WorldToViewportPoint(data.root.Position)
            if data.tracerLine then
                data.tracerLine.From = bottom
                data.tracerLine.To = Vector2.new(rootPos.X, rootPos.Y)
                data.tracerLine.Visible = true
            end
        else
            for _, line in ipairs(data.boxLines) do line.Visible = false end
            data.billboard.Enabled = false
            if data.tracerLine then data.tracerLine.Visible = false end
        end
    end
end)

Players.PlayerRemoving:Connect(function(plr)
    local data = ESP_DATA[plr]
    if data then
        for _, line in ipairs(data.boxLines) do line:Remove() end
        if data.billboard then data.billboard:Destroy() end
        if data.tracerLine then data.tracerLine:Remove() end
        ESP_DATA[plr] = nil
    end
end)

script.Destroying:Connect(function()
    connection:Disconnect()
    for _, data in pairs(ESP_DATA) do
        for _, line in ipairs(data.boxLines) do line:Remove() end
        if data.billboard then data.billboard:Destroy() end
        if data.tracerLine then data.tracerLine:Remove() end
    end
    if ScreenGui then ScreenGui:Destroy() end
end)
