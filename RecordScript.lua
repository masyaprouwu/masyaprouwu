local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera

-- Settings
local MAX_RECORD_TIME = 999999999
local RECORD_INTERVAL = 0.033 -- recording interval (~30 FPS)
local MAX_PLAYBACK_SPEED = 1000 -- maximum playback speed
local DEFAULT_WALK_SPEED = 16 -- default walk speed after respawn

-- State
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

local recording = false
local playingBack = false
local playbackPaused = false
local recordedFrames = {}
local recordStartTime = 0
local currentPlaybackSpeed = 1.0
local playbackConnection = nil
local playbackStartTime = 0
local pausedPlaybackTime = 0

-- Create main GUI with draggable functionality
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AdvancedRewinderGUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

-- Main draggable frame
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 350, 0, 40) -- Starts collapsed
mainFrame.Position = UDim2.new(0.5, -175, 0, 10)
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
mainFrame.BackgroundTransparency = 0.3
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true
mainFrame.Parent = screenGui

-- Add rounded corners
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = mainFrame

-- Title bar with drag functionality
local titleBar = Instance.new("Frame")
titleBar.Name = "TitleBar"
titleBar.Size = UDim2.new(1, 0, 0, 40)
titleBar.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
titleBar.BackgroundTransparency = 0.2
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame

-- Title bar corner (only top corners)
local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 8)
titleCorner.Parent = titleBar

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "TitleLabel"
titleLabel.Size = UDim2.new(1, -40, 1, 0)
titleLabel.Position = UDim2.new(0, 10, 0, 0)
titleLabel.Text = "Advanced Rewinder ▼"
titleLabel.TextColor3 = Color3.new(1, 1, 1)
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 16
titleLabel.BackgroundTransparency = 1
titleLabel.Parent = titleBar

local toggleButton = Instance.new("TextButton")
toggleButton.Name = "ToggleButton"
toggleButton.Size = UDim2.new(0, 30, 0, 30)
toggleButton.Position = UDim2.new(1, -35, 0.5, -15)
toggleButton.Text = "▼"
toggleButton.TextColor3 = Color3.new(1, 1, 1)
toggleButton.Font = Enum.Font.GothamBold
toggleButton.TextSize = 16
toggleButton.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
toggleButton.BackgroundTransparency = 0.5
toggleButton.BorderSizePixel = 0
toggleButton.Parent = titleBar

-- Add corner to toggle button
local toggleCorner = Instance.new("UICorner")
toggleCorner.CornerRadius = UDim.new(0, 6)
toggleCorner.Parent = toggleButton

-- Content frame (collapsible)
local contentFrame = Instance.new("Frame")
contentFrame.Name = "ContentFrame"
contentFrame.Size = UDim2.new(1, 0, 0, 0) -- Starts collapsed
contentFrame.Position = UDim2.new(0, 0, 0, 40)
contentFrame.BackgroundTransparency = 1
contentFrame.ClipsDescendants = true
contentFrame.Parent = mainFrame

-- Control elements container with padding
local controlFrame = Instance.new("Frame")
controlFrame.Name = "ControlFrame"
controlFrame.Size = UDim2.new(1, -20, 0, 380)
controlFrame.Position = UDim2.new(0, 10, 0, 10)
controlFrame.BackgroundTransparency = 1
controlFrame.Parent = contentFrame

-- Function to create styled buttons with consistent sizing
local function createButton(name, text, color, sizeX, sizeY, parent)
    local button = Instance.new("TextButton")
    button.Name = name
    button.Size = UDim2.new(sizeX or 0.32, -5, 0, sizeY or 40)
    button.Text = text
    button.TextScaled = true
    button.Font = Enum.Font.GothamBold
    button.TextColor3 = Color3.new(1, 1, 1)
    button.BackgroundColor3 = color
    button.BackgroundTransparency = 0.3
    button.BorderSizePixel = 0
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = button
    
    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0, 5)
    padding.PaddingRight = UDim.new(0, 5)
    padding.Parent = button
    
    button.Parent = parent
    
    return button
end

-- Create button groups with proper spacing
local function createButtonGroup(parent, count)
    local group = Instance.new("Frame")
    group.Name = "ButtonGroup"
    group.Size = UDim2.new(1, 0, 0, 50)
    group.BackgroundTransparency = 1
    group.LayoutOrder = parent.LayoutOrder
    group.Parent = parent
    
    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.Padding = UDim.new(0, 10)
    layout.Parent = group
    
    return group
end

-- First row of buttons (Record, Continue, Reset)
local firstRow = createButtonGroup(controlFrame, 1)
firstRow.LayoutOrder = 1

-- Second row of buttons (Play, Rewind, Generate Code)
local secondRow = createButtonGroup(controlFrame, 2)
secondRow.LayoutOrder = 2

-- Third row of buttons (Pause, Stop, Enter Code)
local thirdRow = createButtonGroup(controlFrame, 3)
thirdRow.LayoutOrder = 3

-- Main record button
local recordButton = createButton("RecordButton", "⏺ RECORD", Color3.fromRGB(0, 180, 0), 0.32, 40, firstRow)

-- Continue recording button
local continueButton = createButton("ContinueButton", "⏩ CONTINUE", Color3.fromRGB(0, 150, 150), 0.32, 40, firstRow)
continueButton.Visible = false

-- Reset button
local resetButton = createButton("ResetButton", "🗑️ RESET", Color3.fromRGB(100, 100, 100), 0.32, 40, firstRow)
resetButton.Visible = false

-- Play button
local playButton = createButton("PlayButton", "⏵ PLAY", Color3.fromRGB(0, 100, 255), 0.32, 40, secondRow)
playButton.Visible = false

-- Rewind button
local rewindButton = createButton("RewindButton", "⏴ REWIND", Color3.fromRGB(255, 150, 0), 0.32, 40, secondRow)
rewindButton.Visible = false

-- Generate Code button
local generateCodeButton = createButton("GenerateCodeButton", "🔑 GEN CODE", Color3.fromRGB(150, 0, 150), 0.32, 40, secondRow)
generateCodeButton.Visible = false

-- Pause button
local pauseButton = createButton("PauseButton", "⏸ PAUSE", Color3.fromRGB(255, 255, 0), 0.32, 40, thirdRow)
pauseButton.Visible = false

-- Stop button
local stopButton = createButton("StopButton", "⏹ STOP", Color3.fromRGB(255, 50, 50), 0.32, 40, thirdRow)
stopButton.Visible = false

-- Enter Code button
local enterCodeButton = createButton("EnterCodeButton", "⌨️ ENTER CODE", Color3.fromRGB(0, 150, 150), 0.32, 40, thirdRow)

-- Time and speed controls
local bottomControls = Instance.new("Frame")
bottomControls.Name = "BottomControls"
bottomControls.Size = UDim2.new(1, 0, 0, 80)
bottomControls.BackgroundTransparency = 1
bottomControls.LayoutOrder = 4
bottomControls.Parent = controlFrame

-- Speed control frame
local speedControlFrame = Instance.new("Frame")
speedControlFrame.Name = "SpeedControlFrame"
speedControlFrame.Size = UDim2.new(1, 0, 0, 30)
speedControlFrame.BackgroundTransparency = 1
speedControlFrame.Parent = bottomControls

local speedLabel = Instance.new("TextLabel")
speedLabel.Name = "SpeedLabel"
speedLabel.Size = UDim2.new(0.3, 0, 1, 0)
speedLabel.Text = "Speed:"
speedLabel.TextColor3 = Color3.new(1, 1, 1)
speedLabel.TextXAlignment = Enum.TextXAlignment.Left
speedLabel.Font = Enum.Font.GothamMedium
speedLabel.TextSize = 14
speedLabel.BackgroundTransparency = 1
speedLabel.Parent = speedControlFrame

local speedTextBox = Instance.new("TextBox")
speedTextBox.Name = "SpeedTextBox"
speedTextBox.Size = UDim2.new(0.7, -10, 1, 0)
speedTextBox.Position = UDim2.new(0.3, 0, 0, 0)
speedTextBox.Text = "1.0"
speedTextBox.PlaceholderText = "Speed (1-1000)"
speedTextBox.TextScaled = true
speedTextBox.Font = Enum.Font.GothamMedium
speedTextBox.TextColor3 = Color3.new(0, 0, 0)
speedTextBox.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
speedTextBox.BackgroundTransparency = 0.5
speedTextBox.Parent = speedControlFrame

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 6)
corner.Parent = speedTextBox

local padding = Instance.new("UIPadding")
padding.PaddingLeft = UDim.new(0, 5)
padding.PaddingRight = UDim.new(0, 5)
padding.Parent = speedTextBox

-- Time label
local timeLabel = Instance.new("TextLabel")
timeLabel.Name = "TimeLabel"
timeLabel.Size = UDim2.new(1, 0, 0, 25)
timeLabel.Position = UDim2.new(0, 0, 0, 35)
timeLabel.Text = "Ready to record"
timeLabel.TextColor3 = Color3.new(1, 1, 1)
timeLabel.TextXAlignment = Enum.TextXAlignment.Left
timeLabel.Font = Enum.Font.GothamMedium
timeLabel.TextSize = 14
timeLabel.BackgroundTransparency = 1
timeLabel.Parent = bottomControls

-- Status label
local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "StatusLabel"
statusLabel.Size = UDim2.new(1, 0, 0, 20)
statusLabel.Position = UDim2.new(0, 0, 0, 60)
statusLabel.Text = "Status: Idle"
statusLabel.TextColor3 = Color3.new(1, 1, 1)
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 12
statusLabel.BackgroundTransparency = 1
statusLabel.Parent = bottomControls

-- UIListLayout for control frame to organize elements vertically
local listLayout = Instance.new("UIListLayout")
listLayout.Name = "ListLayout"
listLayout.Padding = UDim.new(0, 10)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = controlFrame

-- Code storage
local recordingCodes = {}

-- Dragging functionality
local dragging = false
local dragStartPos = Vector2.new(0, 0)
local frameStartPos = Vector2.new(0, 0)

titleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStartPos = Vector2.new(input.Position.X, input.Position.Y)
        frameStartPos = Vector2.new(mainFrame.Position.X.Offset, mainFrame.Position.Y.Offset)
    end
end)

titleBar.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = Vector2.new(input.Position.X, input.Position.Y) - dragStartPos
        mainFrame.Position = UDim2.new(0, frameStartPos.X + delta.X, 0, frameStartPos.Y + delta.Y)
    end
end)

-- Toggle collapse/expand
local expanded = false
local targetSize = UDim2.new(0, 350, 0, 450) -- Expanded size
local collapsedSize = UDim2.new(0, 350, 0, 40) -- Collapsed size

toggleButton.MouseButton1Click:Connect(function()
    expanded = not expanded
    
    if expanded then
        mainFrame.Size = targetSize
        contentFrame.Size = UDim2.new(1, 0, 0, 410)
        titleLabel.Text = "Advanced Rewinder ▲"
        toggleButton.Text = "▲"
    else
        mainFrame.Size = collapsedSize
        contentFrame.Size = UDim2.new(1, 0, 0, 0)
        titleLabel.Text = "Advanced Rewinder ▼"
        toggleButton.Text = "▼"
    end
end)

-- Utility functions (keep all existing functions the same)
local function generateUniqueCode()
    local letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    local codeLength = 8
    local code
    
    repeat
        code = ""
        for i = 1, codeLength do
            local randomIndex = math.random(1, #letters)
            code = code .. string.sub(letters, randomIndex, randomIndex)
        end
    until not recordingCodes[code]
    
    return code
end

local function formatTime(seconds)
    local minutes = math.floor(seconds / 60)
    local secs = math.floor(seconds % 60)
    return string.format("%d:%02d", minutes, secs)
end

local function validateSpeed(input)
    local speed = tonumber(input)
    if not speed then return 1.0 end
    return math.clamp(speed, 0.1, MAX_PLAYBACK_SPEED)
end

local function cleanupPlayback()
    if playbackConnection then
        playbackConnection:Disconnect()
        playbackConnection = nil
    end
    
    playingBack = false
    playbackPaused = false
    pausedPlaybackTime = 0
    
    if humanoid and humanoid:IsDescendantOf(game) then
        humanoid.WalkSpeed = DEFAULT_WALK_SPEED
    end
    
    pauseButton.Visible = false
    stopButton.Visible = false
    
    playButton.Text = "⏵ PLAY"
    playButton.BackgroundColor3 = Color3.fromRGB(0, 100, 255)
    rewindButton.Text = "⏴ REWIND"
    rewindButton.BackgroundColor3 = Color3.fromRGB(255, 150, 0)
    
    resetButton.Visible = true
    generateCodeButton.Visible = true
    
    statusLabel.Text = "Status: Playback stopped"
end

local function recordFrame()
    if not rootPart or not humanoid or not rootPart:IsDescendantOf(game) or not humanoid:IsDescendantOf(game) then return end
    
    local currentTime = os.clock() - recordStartTime
    if currentTime >= MAX_RECORD_TIME then
        stopRecording()
        return
    end
    
    table.insert(recordedFrames, {
        timestamp = os.clock(),
        position = rootPart.Position,
        cframe = rootPart.CFrame,
        cameraCF = camera.CFrame,
        humanoidState = humanoid:GetState().Value,
        velocity = rootPart.Velocity,
        walkSpeed = humanoid.WalkSpeed
    })
    
    timeLabel.Text = "Recording: "..formatTime(currentTime)
    statusLabel.Text = "Status: Recording ("..#recordedFrames.." frames)"
end

local function stopRecording()
    recording = false
    recordButton.Text = "⏺ RECORD"
    recordButton.BackgroundColor3 = Color3.fromRGB(0, 180, 0)
    
    if #recordedFrames > 1 then
        playButton.Visible = true
        rewindButton.Visible = true
        continueButton.Visible = true
        resetButton.Visible = true
        generateCodeButton.Visible = true
        timeLabel.Text = "Done: "..formatTime(recordedFrames[#recordedFrames].timestamp - recordedFrames[1].timestamp)
        statusLabel.Text = "Status: Recorded ("..#recordedFrames.." frames)"
    else
        timeLabel.Text = "Recording canceled"
        statusLabel.Text = "Status: Recording canceled"
    end
end

local function continueRecording()
    if #recordedFrames == 0 or recording or playingBack then return end
    
    local lastFrame = recordedFrames[#recordedFrames]
    if rootPart then
        rootPart.CFrame = lastFrame.cframe
        rootPart.Velocity = Vector3.new(0, 0, 0)
    end
    camera.CFrame = lastFrame.cameraCF
    
    recording = true
    recordStartTime = os.clock() - (lastFrame.timestamp - recordedFrames[1].timestamp)
    recordButton.Text = "⏹ STOP"
    recordButton.BackgroundColor3 = Color3.fromRGB(180, 0, 0)
    playButton.Visible = false
    rewindButton.Visible = false
    continueButton.Visible = false
    resetButton.Visible = false
    generateCodeButton.Visible = false
    pauseButton.Visible = false
    stopButton.Visible = false
    
    statusLabel.Text = "Status: Continuing recording..."
    
    while recording do
        recordFrame()
        task.wait(RECORD_INTERVAL)
    end
end

local function playForward()
    if #recordedFrames < 2 or playingBack then return end
    
    playingBack = true
    playbackPaused = false
    currentPlaybackSpeed = validateSpeed(speedTextBox.Text)
    
    playButton.Text = "⏵ "..currentPlaybackSpeed.."x"
    playButton.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
    pauseButton.Visible = true
    stopButton.Visible = true
    resetButton.Visible = false
    generateCodeButton.Visible = false
    
    local originalWalkSpeed = humanoid.WalkSpeed
    humanoid.WalkSpeed = 0
    
    local startTime = recordedFrames[1].timestamp
    local endTime = recordedFrames[#recordedFrames].timestamp
    
    playbackStartTime = playbackPaused and (os.clock() - pausedPlaybackTime) or os.clock()
    pausedPlaybackTime = 0
    
    statusLabel.Text = "Status: Playing forward ("..currentPlaybackSpeed.."x)"
    
    playbackConnection = RunService.RenderStepped:Connect(function()
        if not playingBack then return end
        if playbackPaused then
            if rootPart and rootPart:IsDescendantOf(game) then
                rootPart.Velocity = Vector3.new(0, 0, 0)
                rootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                rootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
            end
            return 
        end
        
        local currentPlaybackTime = (os.clock() - playbackStartTime) * currentPlaybackSpeed + startTime
        if currentPlaybackTime >= endTime then
            cleanupPlayback()
            return
        end
        
        local prevFrame, nextFrame
        for i = 1, #recordedFrames - 1 do
            if recordedFrames[i].timestamp <= currentPlaybackTime and recordedFrames[i+1].timestamp >= currentPlaybackTime then
                prevFrame = recordedFrames[i]
                nextFrame = recordedFrames[i+1]
                break
            end
        end
        
        if prevFrame and nextFrame then
            local alpha = (currentPlaybackTime - prevFrame.timestamp) / (nextFrame.timestamp - prevFrame.timestamp)
            
            if rootPart and rootPart:IsDescendantOf(game) then
                rootPart.CFrame = prevFrame.cframe:Lerp(nextFrame.cframe, alpha)
                rootPart.Velocity = prevFrame.velocity:Lerp(nextFrame.velocity, alpha)
            end
            camera.CFrame = prevFrame.cameraCF:Lerp(nextFrame.cameraCF, alpha)
            if humanoid and humanoid:IsDescendantOf(game) then
                humanoid.WalkSpeed = prevFrame.walkSpeed * currentPlaybackSpeed
            end
            
            timeLabel.Text = formatTime(currentPlaybackTime - startTime).." / "..formatTime(endTime - startTime)
        end
    end)
end

local function playBackward()
    if #recordedFrames < 2 or playingBack then return end
    
    playingBack = true
    playbackPaused = false
    currentPlaybackSpeed = validateSpeed(speedTextBox.Text)
    
    rewindButton.Text = "⏴ "..currentPlaybackSpeed.."x"
    rewindButton.BackgroundColor3 = Color3.fromRGB(255, 100, 0)
    pauseButton.Visible = true
    stopButton.Visible = true
    resetButton.Visible = false
    generateCodeButton.Visible = false
    
    local originalWalkSpeed = humanoid.WalkSpeed
    humanoid.WalkSpeed = 0
    
    local startTime = recordedFrames[#recordedFrames].timestamp
    local endTime = recordedFrames[1].timestamp
    playbackStartTime = os.clock()
    local totalDuration = (startTime - endTime) / currentPlaybackSpeed
    
    statusLabel.Text = "Status: Playing backward ("..currentPlaybackSpeed.."x)"
    
    playbackConnection = RunService.RenderStepped:Connect(function()
        if not playingBack then return end
        if playbackPaused then
            if rootPart and rootPart:IsDescendantOf(game) then
                rootPart.Velocity = Vector3.new(0, 0, 0)
                rootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                rootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
            end
            return 
        end
        
        local reversedProgress = (os.clock() - playbackStartTime) / totalDuration
        if reversedProgress >= 1 then
            cleanupPlayback()
            return
        end
        
        local targetTime = startTime - (reversedProgress * (startTime - endTime))
        
        local prevFrame, nextFrame
        for i = #recordedFrames, 2, -1 do
            if recordedFrames[i].timestamp >= targetTime and recordedFrames[i-1].timestamp <= targetTime then
                prevFrame = recordedFrames[i]
                nextFrame = recordedFrames[i-1]
                break
            end
        end
        
        if prevFrame and nextFrame then
            local alpha = (targetTime - prevFrame.timestamp) / (nextFrame.timestamp - prevFrame.timestamp)
            
            if rootPart and rootPart:IsDescendantOf(game) then
                rootPart.CFrame = prevFrame.cframe:Lerp(nextFrame.cframe, alpha)
                
                local frameDelta = prevFrame.timestamp - nextFrame.timestamp
                if frameDelta > 0 then
                    local direction = (nextFrame.position - prevFrame.position).Unit
                    local distance = (nextFrame.position - prevFrame.position).Magnitude
                    rootPart.Velocity = direction * (distance / frameDelta) * -1 * currentPlaybackSpeed
                end
            end
            
            camera.CFrame = prevFrame.cameraCF:Lerp(nextFrame.cameraCF, alpha)
            
            timeLabel.Text = formatTime(startTime - targetTime).." / "..formatTime(startTime - endTime)
        end
    end)
end

local function togglePause()
    if not playingBack then return end
    
    if playbackPaused then
        playbackPaused = false
        pauseButton.Text = "⏸ PAUSE"
        pauseButton.BackgroundColor3 = Color3.fromRGB(255, 255, 0)
        
        playbackStartTime = os.clock() - pausedPlaybackTime
        pausedPlaybackTime = 0
        
        statusLabel.Text = "Status: Resumed playback"
    else
        playbackPaused = true
        pauseButton.Text = "⏵ RESUME"
        pauseButton.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
        
        pausedPlaybackTime = os.clock() - playbackStartTime
        
        if rootPart and rootPart:IsDescendantOf(game) then
            rootPart.Velocity = Vector3.new(0, 0, 0)
            rootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            rootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        end
        if humanoid and humanoid:IsDescendantOf(game) then
            humanoid.WalkSpeed = 0
        end
        
        statusLabel.Text = "Status: Playback paused"
    end
end

local function stopPlayback()
    cleanupPlayback()
    timeLabel.Text = "Playback stopped"
    statusLabel.Text = "Status: Playback stopped"
end

local function resetRecording()
    recordedFrames = {}
    playButton.Visible = false
    rewindButton.Visible = false
    continueButton.Visible = false
    generateCodeButton.Visible = false
    pauseButton.Visible = false
    stopButton.Visible = false
    resetButton.Visible = false
    timeLabel.Text = "Ready to record"
    statusLabel.Text = "Status: Idle"
end

local function copyToClipboard(text)
    pcall(function()
        if setclipboard then
            setclipboard(text)
            return
        end
        
        local clipboard = Instance.new("Clipboard")
        clipboard.Text = text
        clipboard.Parent = game:GetService("CoreGui")
        clipboard:Destroy()
    end)
end

local function generateCode()
    if #recordedFrames < 2 then
        timeLabel.Text = "No recording to generate code"
        statusLabel.Text = "Status: No recording to generate code"
        return
    end
    
    local serializedData = {
        version = 1,
        frames = {}
    }
    
    for _, frame in ipairs(recordedFrames) do
        table.insert(serializedData.frames, {
            timestamp = frame.timestamp,
            position = {frame.position.X, frame.position.Y, frame.position.Z},
            cframe = {frame.cframe:GetComponents()},
            cameraCF = {frame.cameraCF:GetComponents()},
            humanoidState = frame.humanoidState,
            velocity = {frame.velocity.X, frame.velocity.Y, frame.velocity.Z},
            walkSpeed = frame.walkSpeed
        })
    end
    
    local code = generateUniqueCode()
    recordingCodes[code] = serializedData
    
    local message = string.format("Your recording code: %s\n\nCopy this code to share your recording!", code)
    
    local codePopup = Instance.new("Frame")
    codePopup.Name = "CodePopup"
    codePopup.Size = UDim2.new(0, 350, 0, 180)
    codePopup.Position = UDim2.new(0.5, -175, 0.5, -90)
    codePopup.AnchorPoint = Vector2.new(0, 0)
    codePopup.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    codePopup.BackgroundTransparency = 0.1
    codePopup.BorderSizePixel = 0
    codePopup.Parent = screenGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = codePopup
    
    local codeLabel = Instance.new("TextLabel")
    codeLabel.Name = "CodeLabel"
    codeLabel.Size = UDim2.new(0, 330, 0, 100)
    codeLabel.Position = UDim2.new(0, 10, 0, 10)
    codeLabel.Text = message
    codeLabel.TextScaled = true
    codeLabel.Font = Enum.Font.GothamBold
    codeLabel.TextColor3 = Color3.new(1, 1, 1)
    codeLabel.BackgroundTransparency = 1
    codeLabel.TextWrapped = true
    codeLabel.Parent = codePopup
    
    local copyButton = createButton("CopyButton", "📋 COPY", Color3.fromRGB(0, 100, 255), 0.45, 40, codePopup)
    copyButton.Position = UDim2.new(0.025, 0, 0, 120)
    
    local closeButton = createButton("CloseButton", "CLOSE", Color3.fromRGB(100, 100, 255), 0.45, 40, codePopup)
    closeButton.Position = UDim2.new(0.525, 0, 0, 120)
    
    copyButton.MouseButton1Click:Connect(function()
        copyToClipboard(code)
        copyButton.Text = "✅ COPIED!"
        task.wait(1)
        copyButton.Text = "📋 COPY"
    end)
    
    closeButton.MouseButton1Click:Connect(function()
        codePopup:Destroy()
    end)
end

local function enterCode()
    local enterCodePopup = Instance.new("Frame")
    enterCodePopup.Name = "EnterCodePopup"
    enterCodePopup.Size = UDim2.new(0, 350, 0, 180)
    enterCodePopup.Position = UDim2.new(0.5, -175, 0.5, -90)
    enterCodePopup.AnchorPoint = Vector2.new(0, 0)
    enterCodePopup.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    enterCodePopup.BackgroundTransparency = 0.1
    enterCodePopup.BorderSizePixel = 0
    enterCodePopup.Parent = screenGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = enterCodePopup
    
    local instructionLabel = Instance.new("TextLabel")
    instructionLabel.Name = "InstructionLabel"
    instructionLabel.Size = UDim2.new(0, 330, 0, 40)
    instructionLabel.Position = UDim2.new(0, 10, 0, 10)
    instructionLabel.Text = "Enter a recording code:"
    instructionLabel.TextScaled = true
    instructionLabel.Font = Enum.Font.GothamBold
    instructionLabel.TextColor3 = Color3.new(1, 1, 1)
    instructionLabel.BackgroundTransparency = 1
    instructionLabel.Parent = enterCodePopup
    
    local codeTextBox = Instance.new("TextBox")
    codeTextBox.Name = "CodeTextBox"
    codeTextBox.Size = UDim2.new(0, 330, 0, 40)
    codeTextBox.Position = UDim2.new(0, 10, 0, 60)
    codeTextBox.Text = ""
    codeTextBox.PlaceholderText = "Paste code here"
    codeTextBox.TextScaled = true
    codeTextBox.Font = Enum.Font.GothamMedium
    codeTextBox.TextColor3 = Color3.new(0, 0, 0)
    codeTextBox.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    codeTextBox.BackgroundTransparency = 0.5
    codeTextBox.Parent = enterCodePopup
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = codeTextBox
    
    local loadButton = createButton("LoadButton", "LOAD", Color3.fromRGB(0, 150, 0), 0.45, 40, enterCodePopup)
    loadButton.Position = UDim2.new(0.025, 0, 0, 120)
    
    local cancelButton = createButton("CancelButton", "CANCEL", Color3.fromRGB(150, 0, 0), 0.45, 40, enterCodePopup)
    cancelButton.Position = UDim2.new(0.525, 0, 0, 120)
    
    cancelButton.MouseButton1Click:Connect(function()
        enterCodePopup:Destroy()
    end)
    
    loadButton.MouseButton1Click:Connect(function()
        local code = codeTextBox.Text
        if recordingCodes[code] then
            recordedFrames = {}
            local serializedData = recordingCodes[code]
            
            for _, frameData in ipairs(serializedData.frames) do
                table.insert(recordedFrames, {
                    timestamp = frameData.timestamp,
                    position = Vector3.new(unpack(frameData.position)),
                    cframe = CFrame.new(unpack(frameData.cframe)),
                    cameraCF = CFrame.new(unpack(frameData.cameraCF)),
                    humanoidState = frameData.humanoidState,
                    velocity = Vector3.new(unpack(frameData.velocity)),
                    walkSpeed = frameData.walkSpeed
                })
            end
            
            enterCodePopup:Destroy()
            
            playButton.Visible = true
            rewindButton.Visible = true
            continueButton.Visible = true
            resetButton.Visible = true
            generateCodeButton.Visible = true
            timeLabel.Text = "Loaded: "..formatTime(recordedFrames[#recordedFrames].timestamp - recordedFrames[1].timestamp)
            statusLabel.Text = "Status: Loaded recording ("..#recordedFrames.." frames)"
        else
            codeTextBox.Text = ""
            codeTextBox.PlaceholderText = "Invalid code, try again"
        end
    end)
end

-- Button handlers
recordButton.MouseButton1Click:Connect(function()
    if not recording and not playingBack then
        recordedFrames = {}
        recording = true
        recordStartTime = os.clock()
        recordButton.Text = "⏹ STOP"
        recordButton.BackgroundColor3 = Color3.fromRGB(180, 0, 0)
        playButton.Visible = false
        rewindButton.Visible = false
        continueButton.Visible = false
        resetButton.Visible = false
        generateCodeButton.Visible = false
        pauseButton.Visible = false
        stopButton.Visible = false
        
        statusLabel.Text = "Status: Starting recording..."
        
        while recording do
            recordFrame()
            task.wait(RECORD_INTERVAL)
        end
    else
        stopRecording()
    end
end)

playButton.MouseButton1Click:Connect(function()
    if not recording and not playingBack then
        task.spawn(playForward)
    end
end)

rewindButton.MouseButton1Click:Connect(function()
    if not recording and not playingBack then
        task.spawn(playBackward)
    end
end)

continueButton.MouseButton1Click:Connect(function()
    if not recording and not playingBack then
        continueRecording()
    end
end)

pauseButton.MouseButton1Click:Connect(togglePause)

stopButton.MouseButton1Click:Connect(stopPlayback)

resetButton.MouseButton1Click:Connect(function()
    if not recording and not playingBack then
        resetRecording()
    end
end)

generateCodeButton.MouseButton1Click:Connect(generateCode)
enterCodeButton.MouseButton1Click:Connect(enterCode)

-- Character death handler
local function onCharacterDeath()
    if recording then
        stopRecording()
    end
end

-- Update when character changes
local function onCharacterAdded(newCharacter)
    character = newCharacter
    
    humanoid = newCharacter:WaitForChild("Humanoid")
    humanoid.Died:Connect(onCharacterDeath)
    
    rootPart = newCharacter:WaitForChild("HumanoidRootPart")
    humanoid.WalkSpeed = DEFAULT_WALK_SPEED
    
    recording = false
    cleanupPlayback()
    
    if #recordedFrames == 0 then
        resetRecording()
    else
        continueButton.Visible = true
    end
end

player.CharacterAdded:Connect(onCharacterAdded)

if humanoid then
    humanoid.Died:Connect(onCharacterDeath)
end

resetRecording()

-- Получаем сервисы
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

-- Создаем GUI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "FreezeGUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = player.PlayerGui

-- Кнопка Freeze
local freezeButton = Instance.new("TextButton")
freezeButton.Name = "FreezeButton"
freezeButton.Size = UDim2.new(0, 120, 0, 50)
freezeButton.Position = UDim2.new(1, -130, 0, 20)
freezeButton.Text = "❄ FREEZE"
freezeButton.Font = Enum.Font.GothamBold
freezeButton.TextSize = 18
freezeButton.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
freezeButton.TextColor3 = Color3.new(1, 1, 1)
freezeButton.Draggable = true
freezeButton.Active = true
freezeButton.Parent = screenGui

-- Кнопка Auto Freeze
local autoFreezeButton = Instance.new("TextButton")
autoFreezeButton.Name = "AutoFreezeButton"
autoFreezeButton.Size = UDim2.new(0, 120, 0, 50)
autoFreezeButton.Position = UDim2.new(1, -130, 0, 80)
autoFreezeButton.Text = "AUTO: OFF"
autoFreezeButton.Font = Enum.Font.GothamBold
autoFreezeButton.TextSize = 18
autoFreezeButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
autoFreezeButton.TextColor3 = Color3.new(1, 1, 1)
autoFreezeButton.Draggable = true
autoFreezeButton.Active = true
autoFreezeButton.Parent = screenGui

-- Состояния
local isFrozen = false
local isAuto = false
local originalWalkSpeed = humanoid.WalkSpeed
local originalJumpPower = humanoid.JumpPower
local originalAnchoredState = {}

-- Функции фриза
local function freezeCharacter()
	originalWalkSpeed = humanoid.WalkSpeed
	originalJumpPower = humanoid.JumpPower
	originalAnchoredState = {}

	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			originalAnchoredState[part] = part.Anchored
			part.Anchored = true
			part.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
			part.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
		end
	end
	freezeButton.Text = "☀ UNFREEZE"
	freezeButton.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
	isFrozen = true
end

local function unfreezeCharacter()
	for part, anchored in pairs(originalAnchoredState) do
		if part and part.Parent then
			part.Anchored = anchored
		end
	end
	humanoid.WalkSpeed = originalWalkSpeed
	humanoid.JumpPower = originalJumpPower
	freezeButton.Text = "❄ FREEZE"
	freezeButton.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
	isFrozen = false
end

-- Переключение ручное
freezeButton.MouseButton1Click:Connect(function()
	if isFrozen then
		unfreezeCharacter()
	else
		freezeCharacter()
	end
end)

-- Клавиша Z
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if not gameProcessed and input.KeyCode == Enum.KeyCode.Z then
		if isFrozen then
			unfreezeCharacter()
		else
			freezeCharacter()
		end
	end
end)

-- Перетаскивание
local dragging = false
local dragStartPos, buttonStartPos

freezeButton.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = true
		dragStartPos = Vector2.new(input.Position.X, input.Position.Y)
		buttonStartPos = freezeButton.Position
	end
end)

freezeButton.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = false
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
		local delta = Vector2.new(input.Position.X, input.Position.Y) - dragStartPos
		freezeButton.Position = UDim2.new(
			buttonStartPos.X.Scale,
			buttonStartPos.X.Offset + delta.X,
			buttonStartPos.Y.Scale,
			buttonStartPos.Y.Offset + delta.Y
		)
	end
end)

-- Обновление персонажа при респавне
player.CharacterAdded:Connect(function(newCharacter)
	character = newCharacter
	humanoid = character:WaitForChild("Humanoid")
	rootPart = character:WaitForChild("HumanoidRootPart")
	if isFrozen then
		task.wait(0.5)
		freezeCharacter()
	end
end)

-- Автофриз логика
local autoFreezeThread

local function toggleAutoFreeze()
	isAuto = not isAuto
	autoFreezeButton.Text = isAuto and "AUTO: ON" or "AUTO: OFF"
	autoFreezeButton.BackgroundColor3 = isAuto and Color3.fromRGB(0, 200, 100) or Color3.fromRGB(100, 100, 100)

	if isAuto then
		autoFreezeThread = task.spawn(function()
			while isAuto do
				if isFrozen then
					unfreezeCharacter()
				else
					freezeCharacter()
				end
				task.wait(0.050) -- 100 мс
			end
		end)
	else
		if autoFreezeThread then
			task.cancel(autoFreezeThread)
			autoFreezeThread = nil
		end
		-- Обязательно размораживаем игрока после остановки автофриза
		if isFrozen then
			unfreezeCharacter()
		end
	end
end

autoFreezeButton.MouseButton1Click:Connect(toggleAutoFreeze)
