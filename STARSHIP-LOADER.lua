--[[
    ╔═══════════════════════════════════════════════════════════════╗
    ║              STARSHIP MOBILE LOADER                           ║
    ║              Secure Whitelist Authentication                  ║
    ║              + Event Code System                              ║
    ╚═══════════════════════════════════════════════════════════════╝
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer

-- Configuration
local SECURE_API_URL = "https://starship-core.my.id"
local MOBILE_UI_API = SECURE_API_URL .. "/api/get-mobile-ui?userId="
local MOBILE_AUTH_API = SECURE_API_URL .. "/api/mobile-load"

-- Event Code System API (Google Sheets)
local EVENT_CODE_API = "https://script.google.com/macros/s/AKfycbw3oc1fHMRpGMkr67f8UQ6jbIXvfxDgI_fZCZSOsNZmnf8htHVnLJFnraGekLitgR7Q/exec"

-- Encryption helpers
local function xorEncrypt(text, key)
    local result = {}
    for i = 1, #text do
        local charCode = string.byte(text, i)
        local keyCode = string.byte(key, ((i - 1) % #key) + 1)
        table.insert(result, string.char(bit32.bxor(charCode, keyCode)))
    end
    return table.concat(result)
end

local b64chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local function base64Decode(data)
    data = string.gsub(data, "[^" .. b64chars .. "=]", "")
    return (
        data:gsub(".", function(x)
            if x == "=" then
                return ""
            end
            local r, f = "", (b64chars:find(x) - 1)
            for i = 6, 1, -1 do
                r = r .. (f % 2 ^ i - f % 2 ^ (i - 1) > 0 and "1" or "0")
            end
            return r
        end):gsub("%d%d%d?%d?%d?%d?%d?%d?", function(x)
            if #x ~= 8 then
                return ""
            end
            local c = 0
            for i = 1, 8 do
                c = c + (x:sub(i, i) == "1" and 2 ^ (8 - i) or 0)
            end
            return string.char(c)
        end)
    )
end

-- Create Loading UI
local function createLoadingUI()
    -- Remove existing UI if any
    local existingGui = LocalPlayer:FindFirstChild("PlayerGui") and
        LocalPlayer.PlayerGui:FindFirstChild("StarshipMobileLoader")
    if existingGui then
        existingGui:Destroy()
    end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "StarshipMobileLoader"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.IgnoreGuiInset = true

    -- Try to parent to CoreGui, fallback to PlayerGui
    pcall(function()
        screenGui.Parent = game:GetService("CoreGui")
    end)
    if not screenGui.Parent then
        screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end

    -- Background
    local background = Instance.new("Frame")
    background.Name = "Background"
    background.Size = UDim2.new(1, 0, 1, 0)
    background.BackgroundColor3 = Color3.fromHex("#0a0a0f")
    background.BorderSizePixel = 0
    background.Parent = screenGui

    -- Gradient
    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromHex("#0a0a0f")),
        ColorSequenceKeypoint.new(0.5, Color3.fromHex("#1a1a2e")),
        ColorSequenceKeypoint.new(1, Color3.fromHex("#0a0a0f"))
    })
    gradient.Rotation = 45
    gradient.Parent = background

    -- Main Container
    local container = Instance.new("Frame")
    container.Name = "Container"
    container.Size = UDim2.new(0, 320, 0, 200)
    container.Position = UDim2.new(0.5, 0, 0.5, 0)
    container.AnchorPoint = Vector2.new(0.5, 0.5)
    container.BackgroundColor3 = Color3.fromHex("#16162a")
    container.BorderSizePixel = 0
    container.Parent = background

    local containerCorner = Instance.new("UICorner")
    containerCorner.CornerRadius = UDim.new(0, 16)
    containerCorner.Parent = container

    local containerStroke = Instance.new("UIStroke")
    containerStroke.Color = Color3.fromHex("#6366f1")
    containerStroke.Thickness = 2
    containerStroke.Transparency = 0.5
    containerStroke.Parent = container

    -- Logo/Title
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, -40, 0, 40)
    title.Position = UDim2.new(0.5, 0, 0, 30)
    title.AnchorPoint = Vector2.new(0.5, 0)
    title.BackgroundTransparency = 1
    title.Text = "⭐ STARSHIP MOBILE"
    title.TextColor3 = Color3.fromHex("#ffffff")
    title.TextSize = 24
    title.Font = Enum.Font.GothamBold
    title.Parent = container

    -- Status Text
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Name = "Status"
    statusLabel.Size = UDim2.new(1, -40, 0, 25)
    statusLabel.Position = UDim2.new(0.5, 0, 0, 85)
    statusLabel.AnchorPoint = Vector2.new(0.5, 0)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = "Initializing..."
    statusLabel.TextColor3 = Color3.fromHex("#a1a1aa")
    statusLabel.TextSize = 14
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.Parent = container

    -- Progress Bar Background
    local progressBg = Instance.new("Frame")
    progressBg.Name = "ProgressBg"
    progressBg.Size = UDim2.new(1, -60, 0, 8)
    progressBg.Position = UDim2.new(0.5, 0, 0, 130)
    progressBg.AnchorPoint = Vector2.new(0.5, 0)
    progressBg.BackgroundColor3 = Color3.fromHex("#2a2a3e")
    progressBg.BorderSizePixel = 0
    progressBg.Parent = container

    local progressBgCorner = Instance.new("UICorner")
    progressBgCorner.CornerRadius = UDim.new(1, 0)
    progressBgCorner.Parent = progressBg

    -- Progress Bar Fill
    local progressFill = Instance.new("Frame")
    progressFill.Name = "Fill"
    progressFill.Size = UDim2.new(0, 0, 1, 0)
    progressFill.BackgroundColor3 = Color3.fromHex("#6366f1")
    progressFill.BorderSizePixel = 0
    progressFill.Parent = progressBg

    local progressFillCorner = Instance.new("UICorner")
    progressFillCorner.CornerRadius = UDim.new(1, 0)
    progressFillCorner.Parent = progressFill

    local progressGradient = Instance.new("UIGradient")
    progressGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromHex("#6366f1")),
        ColorSequenceKeypoint.new(1, Color3.fromHex("#8b5cf6"))
    })
    progressGradient.Parent = progressFill

    -- Version label
    local versionLabel = Instance.new("TextLabel")
    versionLabel.Name = "Version"
    versionLabel.Size = UDim2.new(1, 0, 0, 20)
    versionLabel.Position = UDim2.new(0.5, 0, 1, -25)
    versionLabel.AnchorPoint = Vector2.new(0.5, 0)
    versionLabel.BackgroundTransparency = 1
    versionLabel.Text = "v1.0.0-mobile"
    versionLabel.TextColor3 = Color3.fromHex("#4a4a5e")
    versionLabel.TextSize = 11
    versionLabel.Font = Enum.Font.Gotham
    versionLabel.Parent = container

    -- Update function
    local function updateStatus(text, progress)
        statusLabel.Text = text
        TweenService:Create(progressFill, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.new(progress, 0, 1, 0)
        }):Play()
    end

    return screenGui, updateStatus
end

-- Show Error UI
local function showError(message)
    -- Remove existing loader
    pcall(function()
        game:GetService("CoreGui"):FindFirstChild("StarshipMobileLoader"):Destroy()
    end)
    pcall(function()
        LocalPlayer.PlayerGui:FindFirstChild("StarshipMobileLoader"):Destroy()
    end)

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "StarshipMobileError"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.IgnoreGuiInset = true

    pcall(function()
        screenGui.Parent = game:GetService("CoreGui")
    end)
    if not screenGui.Parent then
        screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end

    -- Background
    local background = Instance.new("Frame")
    background.Size = UDim2.new(1, 0, 1, 0)
    background.BackgroundColor3 = Color3.fromHex("#0a0a0f")
    background.BorderSizePixel = 0
    background.Parent = screenGui

    -- Container
    local container = Instance.new("Frame")
    container.Size = UDim2.new(0, 340, 0, 220)
    container.Position = UDim2.new(0.5, 0, 0.5, 0)
    container.AnchorPoint = Vector2.new(0.5, 0.5)
    container.BackgroundColor3 = Color3.fromHex("#1a1a2e")
    container.BorderSizePixel = 0
    container.Parent = background

    local containerCorner = Instance.new("UICorner")
    containerCorner.CornerRadius = UDim.new(0, 16)
    containerCorner.Parent = container

    local containerStroke = Instance.new("UIStroke")
    containerStroke.Color = Color3.fromHex("#ef4444")
    containerStroke.Thickness = 2
    containerStroke.Transparency = 0.3
    containerStroke.Parent = container

    -- Error Icon
    local errorIcon = Instance.new("TextLabel")
    errorIcon.Size = UDim2.new(1, 0, 0, 50)
    errorIcon.Position = UDim2.new(0.5, 0, 0, 25)
    errorIcon.AnchorPoint = Vector2.new(0.5, 0)
    errorIcon.BackgroundTransparency = 1
    errorIcon.Text = "❌"
    errorIcon.TextSize = 40
    errorIcon.Font = Enum.Font.GothamBold
    errorIcon.Parent = container

    -- Error Title
    local errorTitle = Instance.new("TextLabel")
    errorTitle.Size = UDim2.new(1, -40, 0, 30)
    errorTitle.Position = UDim2.new(0.5, 0, 0, 80)
    errorTitle.AnchorPoint = Vector2.new(0.5, 0)
    errorTitle.BackgroundTransparency = 1
    errorTitle.Text = "ACCESS DENIED"
    errorTitle.TextColor3 = Color3.fromHex("#ef4444")
    errorTitle.TextSize = 20
    errorTitle.Font = Enum.Font.GothamBold
    errorTitle.Parent = container

    -- Error Message
    local errorMessage = Instance.new("TextLabel")
    errorMessage.Size = UDim2.new(1, -40, 0, 50)
    errorMessage.Position = UDim2.new(0.5, 0, 0, 115)
    errorMessage.AnchorPoint = Vector2.new(0.5, 0)
    errorMessage.BackgroundTransparency = 1
    errorMessage.Text = message
    errorMessage.TextColor3 = Color3.fromHex("#a1a1aa")
    errorMessage.TextSize = 14
    errorMessage.Font = Enum.Font.Gotham
    errorMessage.TextWrapped = true
    errorMessage.Parent = container

    -- Close Button
    local closeButton = Instance.new("TextButton")
    closeButton.Size = UDim2.new(0, 100, 0, 35)
    closeButton.Position = UDim2.new(0.5, 0, 1, -50)
    closeButton.AnchorPoint = Vector2.new(0.5, 0)
    closeButton.BackgroundColor3 = Color3.fromHex("#2a2a3e")
    closeButton.BorderSizePixel = 0
    closeButton.Text = "Close"
    closeButton.TextColor3 = Color3.fromHex("#ffffff")
    closeButton.TextSize = 14
    closeButton.Font = Enum.Font.GothamBold
    closeButton.Parent = container

    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 8)
    closeCorner.Parent = closeButton

    closeButton.MouseButton1Click:Connect(function()
        screenGui:Destroy()
    end)

    -- Auto close after 10 seconds
    task.delay(10, function()
        if screenGui and screenGui.Parent then
            screenGui:Destroy()
        end
    end)
end

-- ══════════════════════════════════════════════════════════════════
-- EVENT CODE SYSTEM UI
-- ══════════════════════════════════════════════════════════════════

local function showEventCodeUI(onSuccess, onCancel)
    -- Remove existing loader
    pcall(function()
        game:GetService("CoreGui"):FindFirstChild("StarshipMobileLoader"):Destroy()
    end)
    pcall(function()
        LocalPlayer.PlayerGui:FindFirstChild("StarshipMobileLoader"):Destroy()
    end)

    local userId = tostring(LocalPlayer.UserId)
    local username = LocalPlayer.Name

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "StarshipEventCode"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.IgnoreGuiInset = true

    pcall(function()
        screenGui.Parent = game:GetService("CoreGui")
    end)
    if not screenGui.Parent then
        screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end

    -- Background
    local background = Instance.new("Frame")
    background.Name = "Background"
    background.Size = UDim2.new(1, 0, 1, 0)
    background.BackgroundColor3 = Color3.fromHex("#0a0a0f")
    background.BorderSizePixel = 0
    background.Parent = screenGui

    -- Gradient
    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromHex("#0a0a0f")),
        ColorSequenceKeypoint.new(0.5, Color3.fromHex("#1a1a2e")),
        ColorSequenceKeypoint.new(1, Color3.fromHex("#0a0a0f"))
    })
    gradient.Rotation = 45
    gradient.Parent = background

    -- Main Container
    local container = Instance.new("Frame")
    container.Name = "Container"
    container.Size = UDim2.new(0, 340, 0, 320)
    container.Position = UDim2.new(0.5, 0, 0.5, 0)
    container.AnchorPoint = Vector2.new(0.5, 0.5)
    container.BackgroundColor3 = Color3.fromHex("#16162a")
    container.BorderSizePixel = 0
    container.Parent = background

    local containerCorner = Instance.new("UICorner")
    containerCorner.CornerRadius = UDim.new(0, 16)
    containerCorner.Parent = container

    local containerStroke = Instance.new("UIStroke")
    containerStroke.Color = Color3.fromHex("#6366f1")
    containerStroke.Thickness = 2
    containerStroke.Transparency = 0.5
    containerStroke.Parent = container

    -- Icon
    local icon = Instance.new("TextLabel")
    icon.Size = UDim2.new(1, 0, 0, 50)
    icon.Position = UDim2.new(0.5, 0, 0, 20)
    icon.AnchorPoint = Vector2.new(0.5, 0)
    icon.BackgroundTransparency = 1
    icon.Text = "🎟️"
    icon.TextSize = 40
    icon.Font = Enum.Font.GothamBold
    icon.Parent = container

    -- Title
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -40, 0, 30)
    title.Position = UDim2.new(0.5, 0, 0, 70)
    title.AnchorPoint = Vector2.new(0.5, 0)
    title.BackgroundTransparency = 1
    title.Text = "EVENT CODE"
    title.TextColor3 = Color3.fromHex("#ffffff")
    title.TextSize = 22
    title.Font = Enum.Font.GothamBold
    title.Parent = container

    -- Subtitle
    local subtitle = Instance.new("TextLabel")
    subtitle.Size = UDim2.new(1, -40, 0, 20)
    subtitle.Position = UDim2.new(0.5, 0, 0, 100)
    subtitle.AnchorPoint = Vector2.new(0.5, 0)
    subtitle.BackgroundTransparency = 1
    subtitle.Text = "Masukkan kode event untuk mendapatkan akses"
    subtitle.TextColor3 = Color3.fromHex("#a1a1aa")
    subtitle.TextSize = 12
    subtitle.Font = Enum.Font.Gotham
    subtitle.Parent = container

    -- Input Box Container
    local inputContainer = Instance.new("Frame")
    inputContainer.Size = UDim2.new(1, -50, 0, 45)
    inputContainer.Position = UDim2.new(0.5, 0, 0, 135)
    inputContainer.AnchorPoint = Vector2.new(0.5, 0)
    inputContainer.BackgroundColor3 = Color3.fromHex("#1e1e3a")
    inputContainer.BorderSizePixel = 0
    inputContainer.Parent = container

    local inputCorner = Instance.new("UICorner")
    inputCorner.CornerRadius = UDim.new(0, 10)
    inputCorner.Parent = inputContainer

    local inputStroke = Instance.new("UIStroke")
    inputStroke.Color = Color3.fromHex("#3a3a5e")
    inputStroke.Thickness = 1
    inputStroke.Parent = inputContainer

    -- Text Input
    local textBox = Instance.new("TextBox")
    textBox.Size = UDim2.new(1, -20, 1, 0)
    textBox.Position = UDim2.new(0.5, 0, 0.5, 0)
    textBox.AnchorPoint = Vector2.new(0.5, 0.5)
    textBox.BackgroundTransparency = 1
    textBox.Text = ""
    textBox.PlaceholderText = "Masukkan kode..."
    textBox.PlaceholderColor3 = Color3.fromHex("#6a6a8e")
    textBox.TextColor3 = Color3.fromHex("#ffffff")
    textBox.TextSize = 16
    textBox.Font = Enum.Font.GothamBold
    textBox.ClearTextOnFocus = false
    textBox.Parent = inputContainer

    -- Status Label
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Name = "StatusLabel"
    statusLabel.Size = UDim2.new(1, -50, 0, 20)
    statusLabel.Position = UDim2.new(0.5, 0, 0, 185)
    statusLabel.AnchorPoint = Vector2.new(0.5, 0)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = ""
    statusLabel.TextColor3 = Color3.fromHex("#a1a1aa")
    statusLabel.TextSize = 12
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.Parent = container

    -- Redeem Button
    local redeemButton = Instance.new("TextButton")
    redeemButton.Size = UDim2.new(1, -50, 0, 45)
    redeemButton.Position = UDim2.new(0.5, 0, 0, 215)
    redeemButton.AnchorPoint = Vector2.new(0.5, 0)
    redeemButton.BackgroundColor3 = Color3.fromHex("#6366f1")
    redeemButton.BorderSizePixel = 0
    redeemButton.Text = "🎫 REDEEM CODE"
    redeemButton.TextColor3 = Color3.fromHex("#ffffff")
    redeemButton.TextSize = 16
    redeemButton.Font = Enum.Font.GothamBold
    redeemButton.Parent = container

    local redeemCorner = Instance.new("UICorner")
    redeemCorner.CornerRadius = UDim.new(0, 10)
    redeemCorner.Parent = redeemButton

    -- Redeem Button Gradient
    local redeemGradient = Instance.new("UIGradient")
    redeemGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromHex("#6366f1")),
        ColorSequenceKeypoint.new(1, Color3.fromHex("#8b5cf6"))
    })
    redeemGradient.Parent = redeemButton

    -- Cancel Button
    local cancelButton = Instance.new("TextButton")
    cancelButton.Size = UDim2.new(1, -50, 0, 35)
    cancelButton.Position = UDim2.new(0.5, 0, 0, 270)
    cancelButton.AnchorPoint = Vector2.new(0.5, 0)
    cancelButton.BackgroundColor3 = Color3.fromHex("#2a2a3e")
    cancelButton.BorderSizePixel = 0
    cancelButton.Text = "Tutup"
    cancelButton.TextColor3 = Color3.fromHex("#a1a1aa")
    cancelButton.TextSize = 14
    cancelButton.Font = Enum.Font.Gotham
    cancelButton.Parent = container

    local cancelCorner = Instance.new("UICorner")
    cancelCorner.CornerRadius = UDim.new(0, 8)
    cancelCorner.Parent = cancelButton

    -- Function to update status
    local function updateStatus(text, color)
        statusLabel.Text = text
        statusLabel.TextColor3 = Color3.fromHex(color or "#a1a1aa")
    end

    -- Function to set button loading state
    local function setLoading(loading)
        redeemButton.Active = not loading
        if loading then
            redeemButton.Text = "⏳ Memproses..."
            redeemButton.BackgroundColor3 = Color3.fromHex("#4a4a6e")
        else
            redeemButton.Text = "🎫 REDEEM CODE"
            redeemButton.BackgroundColor3 = Color3.fromHex("#6366f1")
        end
    end

    -- Redeem button click handler
    redeemButton.MouseButton1Click:Connect(function()
        local code = textBox.Text:gsub("%s+", ""):upper() -- Remove spaces and uppercase

        if code == "" then
            updateStatus("⚠️ Masukkan kode terlebih dahulu!", "#eab308")
            return
        end

        setLoading(true)
        updateStatus("🔍 Memeriksa kode...", "#a1a1aa")

        -- Call Google Sheets API to redeem code
        local apiUrl = EVENT_CODE_API .. "?action=redeem&code=" .. code .. "&userId=" .. userId .. "&username=" .. username

        local success, response = pcall(function()
            return game:HttpGet(apiUrl)
        end)

        if not success then
            setLoading(false)
            updateStatus("❌ Gagal terhubung ke server!", "#ef4444")
            return
        end

        -- Parse response
        local data = nil
        pcall(function()
            data = HttpService:JSONDecode(response)
        end)

        if not data then
            setLoading(false)
            updateStatus("❌ Response tidak valid!", "#ef4444")
            return
        end

        if data.success then
            updateStatus("✅ " .. data.message, "#22c55e")
            task.wait(1)

            -- Destroy this UI
            screenGui:Destroy()

            -- Call success callback with session data
            if onSuccess then
                onSuccess({
                    Role = "EVENT",
                    Duration = tostring(data.duration) .. " DAYS",
                    Expiry = data.expiresAt,
                    RemainingDays = data.duration,
                    ActivatedAt = os.date("%Y-%m-%d %H:%M:%S"),
                    Platform = "mobile",
                    CodeUsed = code,
                    IsEventAccess = true,
                })
            end
        else
            setLoading(false)
            updateStatus("❌ " .. (data.message or "Code tidak valid!"), "#ef4444")
        end
    end)

    -- Cancel button click handler
    cancelButton.MouseButton1Click:Connect(function()
        screenGui:Destroy()
        if onCancel then
            onCancel()
        end
    end)

    -- Focus text box
    task.delay(0.5, function()
        if textBox and textBox.Parent then
            textBox:CaptureFocus()
        end
    end)

    return screenGui
end

-- ══════════════════════════════════════════════════════════════════
-- CHECK USER EVENT ACCESS STATUS
-- ══════════════════════════════════════════════════════════════════

local function checkEventAccess(userId)
    local apiUrl = EVENT_CODE_API .. "?action=status&userId=" .. userId

    local success, response = pcall(function()
        return game:HttpGet(apiUrl)
    end)

    if not success then
        return nil, "Connection failed"
    end

    local data = nil
    pcall(function()
        data = HttpService:JSONDecode(response)
    end)

    if not data then
        return nil, "Invalid response"
    end

    return data, nil
end

-- ══════════════════════════════════════════════════════════════════
-- LOAD MOBILE UI FUNCTION
-- ══════════════════════════════════════════════════════════════════

local function loadMobileUI(sessionData, loaderGui, updateStatus)
    if updateStatus then
        updateStatus("Loading Starship Mobile...", 0.85)
    end
    task.wait(0.3)

    -- Load Mobile UI Script (from protected API)
    local userId = tostring(LocalPlayer.UserId)
    local mobileScriptSuccess, mobileScript = pcall(function()
        return game:HttpGet(MOBILE_UI_API .. userId)
    end)

    if not mobileScriptSuccess then
        if loaderGui then loaderGui:Destroy() end
        showError("Failed to load Mobile UI\n\nConnection Error")
        return false
    end

    if not mobileScript or mobileScript == "" then
        if loaderGui then loaderGui:Destroy() end
        showError("Failed to load Mobile UI\n\nEmpty Response")
        return false
    end

    -- Check if response is an error message
    if mobileScript:find("error%(") then
        if loaderGui then loaderGui:Destroy() end
        local errorMsg = mobileScript:match('error%("(.-)"%)')
        showError(errorMsg or "Mobile UI Access Denied")
        return false
    end

    if updateStatus then
        updateStatus("Launching...", 1.0)
    end
    task.wait(0.4)

    -- Execute Mobile Script
    local func, err = loadstring(mobileScript)
    if not func then
        if loaderGui then loaderGui:Destroy() end
        showError("Execution Error:\n" .. tostring(err))
        return false
    end

    -- Smooth exit animation
    if loaderGui then
        local MainFrame = loaderGui:FindFirstChild("Background")
        if MainFrame then
            local Container = MainFrame:FindFirstChild("Container")
            if Container then
                TweenService:Create(Container, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                    Position = UDim2.new(0.5, 0, 0.6, 0),
                    BackgroundTransparency = 1
                }):Play()
            end

            TweenService:Create(MainFrame, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                BackgroundTransparency = 1
            }):Play()
        end

        task.wait(0.5)
        loaderGui:Destroy()
    end

    -- Store session data
    getgenv().StarshipSession = sessionData

    -- Run the mobile script
    func()
    return true
end

-- ══════════════════════════════════════════════════════════════════
-- MAIN AUTHENTICATION FUNCTION
-- ══════════════════════════════════════════════════════════════════

local function main()
    local loaderGui, updateStatus = createLoadingUI()

    -- Step 1: Initialize
    updateStatus("Initializing...", 0.1)
    task.wait(0.3)

    -- Step 2: Get User ID
    updateStatus("Detecting user...", 0.2)
    local userId = tostring(LocalPlayer.UserId)
    local username = LocalPlayer.Name
    task.wait(0.2)

    -- Step 3: Check if user has active event access first
    updateStatus("Checking event access...", 0.3)
    local eventData, eventError = checkEventAccess(userId)

    if eventData and eventData.success and eventData.hasAccess then
        -- User has active event access!
        updateStatus("Event access found!", 0.5)
        task.wait(0.3)

        local sessionData = {
            Role = "EVENT",
            Duration = tostring(eventData.remainingDays) .. " DAYS",
            Expiry = eventData.expiresAt,
            RemainingDays = eventData.remainingDays,
            RemainingHours = eventData.remainingHours,
            ActivatedAt = os.date("%Y-%m-%d %H:%M:%S"),
            Platform = "mobile",
            CodeUsed = eventData.codeUsed,
            IsEventAccess = true,
            Username = username,
        }

        updateStatus("Access granted! (" .. eventData.remainingDays .. " days left)", 0.7)
        task.wait(0.3)

        loadMobileUI(sessionData, loaderGui, updateStatus)
        return
    end

    -- Step 4: Authenticate with MOBILE-SPECIFIC Server (Separate from PC)
    updateStatus("Authenticating...", 0.4)

    -- Call mobile-load API (separate whitelist from PC)
    local authUrl = MOBILE_AUTH_API .. "?userId=" .. userId
    local authSuccess, authResponse = pcall(function()
        return game:HttpGet(authUrl)
    end)

    if not authSuccess then
        if loaderGui then loaderGui:Destroy() end
        -- Show event code UI as fallback
        showEventCodeUI(function(sessionData)
            -- On success, load mobile UI
            local newLoaderGui, newUpdateStatus = createLoadingUI()
            newUpdateStatus("Access granted!", 0.7)
            task.wait(0.3)
            loadMobileUI(sessionData, newLoaderGui, newUpdateStatus)
        end, function()
            -- On cancel, show error
            showError("Connection Failed\nServer Unreachable")
        end)
        return
    end

    updateStatus("Verifying mobile license...", 0.5)
    task.wait(0.2)

    -- Parse response
    local data = nil
    pcall(function()
        data = HttpService:JSONDecode(authResponse)
    end)

    if not data then
        if loaderGui then loaderGui:Destroy() end
        showError("Server Error\nInvalid Response")
        return
    end

    -- Check status
    if data.status == "denied" then
        if loaderGui then loaderGui:Destroy() end

        -- Instead of showing error directly, show event code UI
        showEventCodeUI(function(sessionData)
            -- On success, load mobile UI
            local newLoaderGui, newUpdateStatus = createLoadingUI()
            newUpdateStatus("Access granted!", 0.7)
            task.wait(0.3)
            loadMobileUI(sessionData, newLoaderGui, newUpdateStatus)
        end, function()
            -- On cancel, show original error
            local errorMsg = data.message or "Not Whitelisted for Mobile"
            if data.hint then
                errorMsg = errorMsg .. "\n\n" .. data.hint
            end
            showError(errorMsg)
        end)
        return

    elseif data.status ~= "success" then
        if loaderGui then loaderGui:Destroy() end
        showError("Error: " .. tostring(data.error or "Unknown"))
        return
    end

    updateStatus("Access granted!", 0.7)
    task.wait(0.2)

    -- Store session data for main script
    local sessionData = {
        Role = data.role or "MOBILE VIP",
        Duration = data.duration or "LIFETIME",
        Expiry = data.expiry,
        RemainingDays = data.remainingDays,
        ActivatedAt = data.activatedAt,
        Platform = "mobile",
        DeviceCount = data.deviceCount,
        MaxDevices = data.maxDevices,
        Username = data.username,
        IsEventAccess = false,
    }

    loadMobileUI(sessionData, loaderGui, updateStatus)
end

-- Execute
main()
