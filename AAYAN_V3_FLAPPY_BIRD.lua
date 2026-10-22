--==================================================
-- AAYAN V3 | FLAPPY BIRD
-- Premium self-contained 2D Flappy Bird inside a draggable GUI
-- Everything is drawn with Frames (no external assets)
-- Tap / click the game area or press SPACE to flap
--==================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CAS = game:GetService("ContextActionService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

--==================================================
-- CLEAN OLD COPY
--==================================================

if _G.AAYAN_FLAPPY_CLEANUP then
	pcall(_G.AAYAN_FLAPPY_CLEANUP)
end

do
	local old = playerGui:FindFirstChild("AAYAN_V3_FLAPPY")
	if old then old:Destroy() end
end

--==================================================
-- CONSTANTS
--==================================================

local CYAN = Color3.fromRGB(0, 220, 255)
local BLUE = Color3.fromRGB(40, 120, 255)
local PURPLE = Color3.fromRGB(170, 70, 255)
local NAVY = Color3.fromRGB(8, 10, 24)
local NAVY2 = Color3.fromRGB(16, 20, 44)

local GW, GH = 300, 400          -- game area (logical pixels)
local GROUND = 56                -- ground height
local PH = GH - GROUND           -- playable height
local TITLE = 34                 -- title bar height

local GRAVITY = 1300
local FLAP = -390
local MAXFALL = 520
local SPEED = 125                -- pipe speed px/s
local SPACING = 175              -- distance between pipes
local GAP = 120
local PW = 52                    -- pipe width
local CAPH = 22
local CAPW = PW + 8
local BX = 90                    -- bird x
local BR = 10                    -- bird hit radius

local conns = {}
local function bind(signal, fn)
	local c = signal:Connect(fn)
	conns[#conns + 1] = c
	return c
end

local function tween(obj, t, props, style, dir)
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do o[k] = v end
	if parent then o.Parent = parent end
	return o
end

local function corner(parent, r)
	return new("UICorner", { CornerRadius = UDim.new(0, r) }, parent)
end

local function round(parent)
	return new("UICorner", { CornerRadius = UDim.new(1, 0) }, parent)
end

local function grad(parent, c0, c1, rot)
	return new("UIGradient", { Color = ColorSequence.new(c0, c1), Rotation = rot or 0 }, parent)
end

local function stroke(parent, color, th, tr)
	local mode = parent:IsA("TextLabel") and Enum.ApplyStrokeMode.Contextual or Enum.ApplyStrokeMode.Border
	return new("UIStroke", {
		Color = color, Thickness = th or 1, Transparency = tr or 0,
		ApplyStrokeMode = mode,
	}, parent)
end

local function label(parent, text, size, color, font, z)
	return new("TextLabel", {
		BackgroundTransparency = 1,
		Text = text,
		TextSize = size,
		TextColor3 = color or Color3.new(1, 1, 1),
		Font = font or Enum.Font.GothamBold,
		ZIndex = z or 1,
	}, parent)
end

--==================================================
-- SOUNDS (built-in Roblox sounds only, mute-able)
--==================================================

local sg = new("ScreenGui", {
	Name = "AAYAN_V3_FLAPPY",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)

local muted = false
local sounds = {}

local function makeSound(name, id, vol)
	sounds[name] = new("Sound", { Name = name, SoundId = id, Volume = vol }, sg)
end
makeSound("flap", "rbxasset://sounds/action_jump.mp3", 0.25)
makeSound("score", "rbxasset://sounds/electronicpingshort.wav", 0.5)
makeSound("hit", "rbxasset://sounds/uuhhh.mp3", 0.35)

local function play(name)
	if muted then return end
	local s = sounds[name]
	if s then
		pcall(function()
			s.TimePosition = 0
			s:Play()
		end)
	end
end

--==================================================
-- WINDOW (holder = draggable, win = animated CanvasGroup)
--==================================================

local holder = new("Frame", {
	Name = "Holder",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0.5, 0),
	Size = UDim2.fromOffset(GW, GH + TITLE),
	BackgroundTransparency = 1,
	Visible = false,
}, sg)

local holderScale = new("UIScale", {}, holder)

local function fitScale()
	local cam = workspace.CurrentCamera
	if not cam then return end
	local v = cam.ViewportSize
	holderScale.Scale = math.clamp(math.min(v.X / 330, v.Y / 500), 0.55, 1.25)
end
fitScale()
if workspace.CurrentCamera then
	bind(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"), fitScale)
end

local win = new("CanvasGroup", {
	Name = "Win",
	Size = UDim2.new(1, 0, 1, 0),
	BackgroundColor3 = NAVY,
	BorderSizePixel = 0,
	GroupTransparency = 1,
}, holder)
corner(win, 16)

local winStroke = stroke(win, Color3.new(1, 1, 1), 2.4, 0)
local winGrad = grad(winStroke, CYAN, PURPLE, 0)

-- title bar --------------------------------------------------------------------

local titleBar = new("Frame", {
	Size = UDim2.new(1, 0, 0, TITLE),
	BackgroundColor3 = NAVY2,
	BorderSizePixel = 0,
	ZIndex = 30,
}, win)
grad(titleBar, Color3.fromRGB(22, 28, 64), Color3.fromRGB(12, 14, 34), 90)

local titleText = label(titleBar, "AAYAN V3 | FLAPPY BIRD", 12, Color3.new(1, 1, 1), Enum.Font.GothamBlack, 31)
titleText.Position = UDim2.fromOffset(12, 0)
titleText.Size = UDim2.new(1, -118, 1, 0)
titleText.TextXAlignment = Enum.TextXAlignment.Left
titleText.TextTruncate = Enum.TextTruncate.AtEnd
local titleGrad = grad(titleText, CYAN, PURPLE, 0)

new("Frame", {
	Position = UDim2.new(0, 0, 1, -1),
	Size = UDim2.new(1, 0, 0, 1),
	BackgroundColor3 = CYAN,
	BackgroundTransparency = 0.5,
	BorderSizePixel = 0,
	ZIndex = 31,
}, titleBar)

local function titleButton(text, order, color)
	local b = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -6 - (order - 1) * 27, 0.5, 0),
		Size = UDim2.fromOffset(24, 24),
		BackgroundColor3 = Color3.fromRGB(28, 34, 74),
		Text = text,
		TextColor3 = color or Color3.new(1, 1, 1),
		TextSize = 14,
		Font = Enum.Font.GothamBlack,
		AutoButtonColor = false,
		ZIndex = 32,
	}, titleBar)
	corner(b, 8)
	stroke(b, color or CYAN, 1, 0.45)
	bind(b.MouseEnter, function() tween(b, 0.15, { BackgroundColor3 = Color3.fromRGB(46, 56, 118) }) end)
	bind(b.MouseLeave, function() tween(b, 0.15, { BackgroundColor3 = Color3.fromRGB(28, 34, 74) }) end)
	return b
end

local closeBtn = titleButton("X", 1, Color3.fromRGB(255, 90, 110))
local miniBtn = titleButton("-", 2, Color3.fromRGB(255, 210, 90))
local restartBtn = titleButton("R", 3, CYAN)
local muteBtn = titleButton("S", 4, Color3.fromRGB(150, 255, 170))

--==================================================
-- GAME AREA
--==================================================

local area = new("Frame", {
	Name = "Area",
	Position = UDim2.fromOffset(0, TITLE),
	Size = UDim2.fromOffset(GW, GH),
	BackgroundColor3 = Color3.fromRGB(110, 190, 245),
	BorderSizePixel = 0,
	ClipsDescendants = true,
}, win)

-- sky -----------------------------------------------------------------------------

local sky = new("Frame", { Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 1 }, area)
new("UIGradient", {
	Rotation = 90,
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(34, 104, 214)),
		ColorSequenceKeypoint.new(0.55, Color3.fromRGB(110, 184, 244)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(214, 238, 252)),
	}),
}, sky)

-- sun
do
	local function disc(size, x, y, color, tr, z)
		local d = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(size, size),
			BackgroundColor3 = color,
			BackgroundTransparency = tr,
			BorderSizePixel = 0,
			ZIndex = z,
		}, area)
		round(d)
		return d
	end
	disc(120, 232, 72, Color3.fromRGB(255, 244, 200), 0.82, 2)
	disc(78, 232, 72, Color3.fromRGB(255, 240, 180), 0.6, 2)
	disc(44, 232, 72, Color3.fromRGB(255, 250, 225), 0, 2)
end

-- clouds (individually moving) -------------------------------------------------------

local clouds = {}
do
	local specs = {
		{ x = 20, y = 52, s = 1.0, v = 10 },
		{ x = 150, y = 100, s = 0.7, v = 6 },
		{ x = 250, y = 36, s = 0.8, v = 8 },
		{ x = 80, y = 150, s = 0.55, v = 5 },
		{ x = 210, y = 175, s = 0.6, v = 7 },
	}
	for _, sp in ipairs(specs) do
		local f = new("Frame", {
			Position = UDim2.fromOffset(sp.x, sp.y),
			Size = UDim2.fromOffset(78 * sp.s, 30 * sp.s),
			BackgroundTransparency = 1,
			ZIndex = 3,
		}, area)
		for _, c in ipairs({
			{ 0.00, 0.35, 0.55, 0.65 }, { 0.22, 0.00, 0.50, 0.85 },
			{ 0.46, 0.20, 0.50, 0.75 }, { 0.62, 0.45, 0.38, 0.55 },
		}) do
			local p = new("Frame", {
				Position = UDim2.fromScale(c[1], c[2]),
				Size = UDim2.fromScale(c[3], c[4]),
				BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = 0.08,
				BorderSizePixel = 0,
			}, f)
			round(p)
		end
		clouds[#clouds + 1] = { f = f, x = sp.x, w = 78 * sp.s, v = sp.v }
	end
end

-- parallax hills ----------------------------------------------------------------------

local function hillLayer(color, z, spec)
	local c = new("Frame", {
		Size = UDim2.fromOffset(GW * 2, GH),
		BackgroundTransparency = 1,
		ZIndex = z,
	}, area)
	for rep = 0, 1 do
		for _, h in ipairs(spec) do
			local d = new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.fromOffset(rep * GW + h[1], PH - h[2]),
				Size = UDim2.fromOffset(h[3], h[3]),
				BackgroundColor3 = color,
				BorderSizePixel = 0,
			}, c)
			round(d)
		end
	end
	return c
end

local farHills = hillLayer(Color3.fromRGB(150, 205, 215), 4, {
	{ 40, 70, 150 }, { 150, 56, 120 }, { 255, 80, 170 },
})
local nearHills = hillLayer(Color3.fromRGB(96, 178, 120), 5, {
	{ 0, 38, 110 }, { 110, 30, 90 }, { 210, 44, 120 },
})
local farX, nearX = 0, 0

-- ground ----------------------------------------------------------------------------------

local groundF = new("Frame", {
	Position = UDim2.fromOffset(0, PH),
	Size = UDim2.fromOffset(GW, GROUND),
	BackgroundColor3 = Color3.fromRGB(222, 200, 140),
	BorderSizePixel = 0,
	ZIndex = 10,
	ClipsDescendants = true,
}, area)
grad(groundF, Color3.fromRGB(232, 212, 150), Color3.fromRGB(190, 158, 98), 90)

new("Frame", {
	Size = UDim2.new(1, 0, 0, 12),
	BackgroundColor3 = Color3.fromRGB(94, 200, 70),
	BorderSizePixel = 0,
	ZIndex = 11,
}, groundF)
new("Frame", {
	Position = UDim2.fromOffset(0, 12),
	Size = UDim2.new(1, 0, 0, 3),
	BackgroundColor3 = Color3.fromRGB(60, 140, 50),
	BorderSizePixel = 0,
	ZIndex = 11,
}, groundF)

local stripes = {}
for i = 0, 12 do
	local s = new("Frame", {
		Position = UDim2.fromOffset(i * 28, 15),
		Size = UDim2.fromOffset(14, 5),
		BackgroundColor3 = Color3.fromRGB(110, 210, 80),
		BorderSizePixel = 0,
		Rotation = -20,
		ZIndex = 11,
	}, groundF)
	stripes[i + 1] = s
end
local groundX = 0

--==================================================
-- PIPES (pooled)
--==================================================

local function pipeBody(parent, z)
	local f = new("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = z,
	}, parent)
	new("UIGradient", {
		Rotation = 0,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(46, 128, 38)),
			ColorSequenceKeypoint.new(0.3, Color3.fromRGB(140, 220, 80)),
			ColorSequenceKeypoint.new(0.7, Color3.fromRGB(88, 180, 56)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(38, 108, 32)),
		}),
	}, f)
	stroke(f, Color3.fromRGB(28, 80, 26), 2, 0)
	return f
end

local pipes = {}
for i = 1, 4 do
	pipes[i] = {
		topBody = pipeBody(area, 8),
		topCap = pipeBody(area, 9),
		botBody = pipeBody(area, 8),
		botCap = pipeBody(area, 9),
		x = 0, gapY = 0, scored = false, active = false,
	}
	corner(pipes[i].topCap, 4)
	corner(pipes[i].botCap, 4)
end

local function placePipe(p)
	local top = p.gapY - GAP / 2
	local bot = p.gapY + GAP / 2

	p.topBody.Position = UDim2.fromOffset(p.x, -4)
	p.topBody.Size = UDim2.fromOffset(PW, math.max(0, top - CAPH + 4))
	p.topCap.Position = UDim2.fromOffset(p.x - 4, top - CAPH)
	p.topCap.Size = UDim2.fromOffset(CAPW, CAPH)

	p.botCap.Position = UDim2.fromOffset(p.x - 4, bot)
	p.botCap.Size = UDim2.fromOffset(CAPW, CAPH)
	p.botBody.Position = UDim2.fromOffset(p.x, bot + CAPH)
	p.botBody.Size = UDim2.fromOffset(PW, math.max(0, PH - bot - CAPH + 4))

	local v = p.active
	p.topBody.Visible = v
	p.topCap.Visible = v
	p.botBody.Visible = v
	p.botCap.Visible = v
end

--==================================================
-- REALISTIC BIRD (drawn with frames)
--==================================================

local bird = new("Frame", {
	Name = "Bird",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Size = UDim2.fromOffset(52, 40),
	Position = UDim2.fromOffset(BX, PH * 0.45),
	BackgroundTransparency = 1,
	ZIndex = 12,
}, area)

local function part(parent, x, y, w, h, color, z, rot, circleShape)
	local f = new("Frame", {
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Rotation = rot or 0,
		ZIndex = z,
	}, parent)
	if circleShape then round(f) else corner(f, math.min(w, h) / 2) end
	return f
end

-- soft ground shadow follows the bird
local shadow = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromOffset(BX, PH - 4),
	Size = UDim2.fromOffset(30, 7),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.7,
	BorderSizePixel = 0,
	ZIndex = 11,
}, area)
round(shadow)

-- tail feathers
for _, t in ipairs({ { 0, 13, -22 }, { -1, 18, 0 }, { 0, 23, 22 } }) do
	local tf = part(bird, t[1], t[2], 17, 6, Color3.fromRGB(150, 74, 30), 11, t[3])
	grad(tf, Color3.fromRGB(120, 54, 22), Color3.fromRGB(196, 110, 44), 0)
end

-- body
local body = part(bird, 8, 5, 35, 29, Color3.new(1, 1, 1), 12, 0, true)
grad(body, Color3.fromRGB(255, 232, 92), Color3.fromRGB(255, 150, 28), 90)
stroke(body, Color3.fromRGB(118, 58, 10), 1.6, 0)

-- belly
local belly = part(bird, 14, 20, 24, 11, Color3.fromRGB(255, 246, 206), 13, 0)
belly.BackgroundTransparency = 0.1

-- head feather tuft
part(bird, 24, 1, 5, 8, Color3.fromRGB(255, 170, 40), 12, -25)
part(bird, 28, 2, 4, 7, Color3.fromRGB(255, 120, 30), 12, 12)

-- wing (animated)
local wing = new("Frame", {
	AnchorPoint = Vector2.new(0.2, 0.5),
	Position = UDim2.fromOffset(17, 21),
	Size = UDim2.fromOffset(21, 13),
	BackgroundColor3 = Color3.new(1, 1, 1),
	BorderSizePixel = 0,
	ZIndex = 14,
}, bird)
corner(wing, 7)
grad(wing, Color3.fromRGB(255, 150, 30), Color3.fromRGB(196, 82, 14), 90)
stroke(wing, Color3.fromRGB(120, 54, 10), 1.3, 0)
for i = 0, 2 do
	new("Frame", {
		Position = UDim2.fromOffset(5 + i * 5, 3),
		Size = UDim2.fromOffset(1, 7),
		BackgroundColor3 = Color3.fromRGB(130, 56, 10),
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		ZIndex = 15,
	}, wing)
end

-- eye
local eye = part(bird, 29, 8, 12, 12, Color3.new(1, 1, 1), 15, 0, true)
stroke(eye, Color3.fromRGB(40, 24, 10), 1.2, 0)
local pupil = part(eye, 5, 3, 6, 7, Color3.fromRGB(14, 10, 8), 16, 0, true)
part(pupil, 3, 1, 2, 2, Color3.new(1, 1, 1), 17, 0, true)
-- brow
part(bird, 28, 5, 13, 3, Color3.fromRGB(150, 70, 14), 16, 14)

-- cheek
local cheek = part(bird, 27, 21, 7, 5, Color3.fromRGB(255, 110, 100), 15, 0, true)
cheek.BackgroundTransparency = 0.45

-- beak
local beakTop = part(bird, 40, 17, 13, 6, Color3.fromRGB(255, 124, 28), 15, 0)
local beakBot = part(bird, 40, 22, 11, 5, Color3.fromRGB(222, 88, 18), 14, 0)
stroke(beakTop, Color3.fromRGB(150, 60, 10), 1, 0.2)

--==================================================
-- FLAP PARTICLES (pooled)
--==================================================

local particles = {}
for i = 1, 14 do
	local f = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(6, 6),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 11,
	}, area)
	round(f)
	particles[i] = { f = f, life = 0, max = 0.5, vx = 0, vy = 0, x = 0, y = 0 }
end
local pIndex = 0

local function emit(n, x, y, color)
	for _ = 1, n do
		pIndex = pIndex % #particles + 1
		local p = particles[pIndex]
		p.x = x + math.random(-4, 4)
		p.y = y + math.random(-4, 4)
		p.vx = -math.random(40, 100)
		p.vy = math.random(-40, 40)
		p.life = 0
		p.max = 0.35 + math.random() * 0.3
		p.f.BackgroundColor3 = color or Color3.fromRGB(190, 240, 255)
		p.f.Visible = true
	end
end

--==================================================
-- SCORE LABEL
--==================================================

local scoreLbl = label(area, "0", 46, Color3.new(1, 1, 1), Enum.Font.GothamBlack, 14)
scoreLbl.AnchorPoint = Vector2.new(0.5, 0)
scoreLbl.Position = UDim2.new(0.5, 0, 0, 22)
scoreLbl.Size = UDim2.fromOffset(120, 54)
scoreLbl.Visible = false
stroke(scoreLbl, CYAN, 3, 0.1)
local scoreScale = new("UIScale", {}, scoreLbl)

local flash = new("Frame", {
	Size = UDim2.new(1, 0, 1, 0),
	BackgroundColor3 = Color3.new(1, 1, 1),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ZIndex = 40,
}, area)

local hint = label(area, "TAP TO FLY", 15, Color3.new(1, 1, 1), Enum.Font.GothamBlack, 14)
hint.AnchorPoint = Vector2.new(0.5, 0.5)
hint.Position = UDim2.new(0.5, 0, 0, 175)
hint.Size = UDim2.fromOffset(200, 24)
hint.Visible = false
stroke(hint, Color3.fromRGB(20, 50, 120), 2.5, 0)

-- click catcher
local tapArea = new("TextButton", {
	Size = UDim2.new(1, 0, 1, 0),
	BackgroundTransparency = 1,
	Text = "",
	AutoButtonColor = false,
	ZIndex = 15,
}, area)

--==================================================
-- OVERLAYS (CanvasGroups, fade in / out)
--==================================================

local function makeButton(parent, text, size, pos)
	local b = new("TextButton", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = pos,
		Size = size,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Text = text,
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = 15,
		Font = Enum.Font.GothamBlack,
		AutoButtonColor = false,
		ZIndex = 26,
	}, parent)
	corner(b, 12)
	grad(b, Color3.fromRGB(0, 190, 240), Color3.fromRGB(150, 70, 255), 20)
	stroke(b, Color3.new(1, 1, 1), 1.5, 0.55)
	local sc = new("UIScale", {}, b)
	bind(b.MouseEnter, function() tween(sc, 0.15, { Scale = 1.06 }) end)
	bind(b.MouseLeave, function() tween(sc, 0.15, { Scale = 1 }) end)
	bind(b.MouseButton1Down, function() tween(sc, 0.08, { Scale = 0.94 }) end)
	bind(b.MouseButton1Up, function() tween(sc, 0.12, { Scale = 1.06 }) end)
	return b
end

local function makeOverlay(dim)
	local o = new("CanvasGroup", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = dim,
		BorderSizePixel = 0,
		GroupTransparency = 1,
		Visible = false,
		ZIndex = 25,
	}, area)
	return o
end

local function showOverlay(o, show)
	if show then
		o.Visible = true
		o.GroupTransparency = 1
		tween(o, 0.35, { GroupTransparency = 0 })
	else
		local tw = tween(o, 0.25, { GroupTransparency = 1 })
		tw.Completed:Connect(function()
			if o.GroupTransparency >= 0.99 then o.Visible = false end
		end)
	end
end

-- start screen
local startO = makeOverlay(1)

local startTitle = label(startO, "FLAPPY BIRD", 30, Color3.new(1, 1, 1), Enum.Font.GothamBlack, 26)
startTitle.AnchorPoint = Vector2.new(0.5, 0.5)
startTitle.Position = UDim2.new(0.5, 0, 0, 70)
startTitle.Size = UDim2.fromOffset(280, 40)
stroke(startTitle, Color3.fromRGB(20, 50, 130), 3.5, 0)

local startSub = label(startO, "AAYAN V3", 13, CYAN, Enum.Font.GothamBlack, 26)
startSub.AnchorPoint = Vector2.new(0.5, 0.5)
startSub.Position = UDim2.new(0.5, 0, 0, 100)
startSub.Size = UDim2.fromOffset(200, 18)
stroke(startSub, Color3.fromRGB(10, 30, 90), 2.5, 0)

local playBtn = makeButton(startO, "PLAY", UDim2.fromOffset(140, 44), UDim2.new(0.5, 0, 0, 268))

local howTo = label(startO, "Tap to Fly! Avoid the Pipes!", 13, Color3.new(1, 1, 1), Enum.Font.GothamBold, 26)
howTo.AnchorPoint = Vector2.new(0.5, 0.5)
howTo.Position = UDim2.new(0.5, 0, 0, 318)
howTo.Size = UDim2.fromOffset(260, 20)
stroke(howTo, Color3.fromRGB(14, 40, 100), 2.5, 0)

local bestMenu = label(startO, "BEST 0", 12, Color3.fromRGB(255, 236, 150), Enum.Font.GothamBlack, 26)
bestMenu.AnchorPoint = Vector2.new(0.5, 0.5)
bestMenu.Position = UDim2.new(0.5, 0, 0, 340)
bestMenu.Size = UDim2.fromOffset(200, 18)
stroke(bestMenu, Color3.fromRGB(90, 60, 10), 2, 0)

-- game over screen
local overO = makeOverlay(0.45)

local card = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0.5, -6),
	Size = UDim2.fromOffset(236, 248),
	BackgroundColor3 = NAVY,
	BorderSizePixel = 0,
	ZIndex = 26,
}, overO)
corner(card, 16)
grad(card, Color3.fromRGB(20, 26, 60), Color3.fromRGB(9, 10, 26), 90)
local cardStroke = stroke(card, Color3.new(1, 1, 1), 2, 0)
grad(cardStroke, CYAN, PURPLE, 45)

local goTitle = label(card, "GAME OVER", 24, Color3.fromRGB(255, 80, 100), Enum.Font.GothamBlack, 27)
goTitle.Position = UDim2.fromOffset(0, 12)
goTitle.Size = UDim2.new(1, 0, 0, 30)
stroke(goTitle, Color3.fromRGB(120, 10, 40), 2, 0.2)

local medal = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, -62, 0, 54),
	Size = UDim2.fromOffset(48, 48),
	BackgroundColor3 = Color3.fromRGB(90, 96, 120),
	BorderSizePixel = 0,
	ZIndex = 27,
}, card)
round(medal)
local medalStroke = stroke(medal, Color3.fromRGB(150, 156, 180), 3, 0)
local medalText = label(medal, "-", 20, Color3.new(1, 1, 1), Enum.Font.GothamBlack, 28)
medalText.Size = UDim2.new(1, 0, 1, 0)

local scoreCap = label(card, "SCORE", 11, Color3.fromRGB(150, 160, 210), Enum.Font.GothamBold, 27)
scoreCap.Position = UDim2.fromOffset(88, 54)
scoreCap.Size = UDim2.fromOffset(120, 14)
scoreCap.TextXAlignment = Enum.TextXAlignment.Left

local finalLbl = label(card, "0", 34, Color3.new(1, 1, 1), Enum.Font.GothamBlack, 27)
finalLbl.Position = UDim2.fromOffset(88, 66)
finalLbl.Size = UDim2.fromOffset(120, 40)
finalLbl.TextXAlignment = Enum.TextXAlignment.Left
stroke(finalLbl, CYAN, 2, 0.35)

local bestLbl = label(card, "BEST 0", 14, Color3.fromRGB(255, 226, 120), Enum.Font.GothamBlack, 27)
bestLbl.Position = UDim2.fromOffset(0, 112)
bestLbl.Size = UDim2.new(1, 0, 0, 20)

local newBest = label(card, "NEW BEST!", 12, Color3.fromRGB(120, 255, 160), Enum.Font.GothamBlack, 27)
newBest.Position = UDim2.fromOffset(0, 130)
newBest.Size = UDim2.new(1, 0, 0, 16)
newBest.Visible = false

local againBtn = makeButton(card, "PLAY AGAIN", UDim2.fromOffset(180, 40), UDim2.new(0.5, 0, 0, 176))
local menuBtn = makeButton(card, "MENU", UDim2.fromOffset(180, 34), UDim2.new(0.5, 0, 0, 220))

--==================================================
-- GAME STATE
--==================================================

local state = "menu"         -- menu | ready | play | over
local birdY, birdV = PH * 0.45, 0
local score, best = 0, 0
local lastGapY = PH * 0.5
local paused = false
local grace = 0
local clock = 0
local flapAnim = 0
local deadTimer = 0
local shake = 0
local overShown = false

local function setScore(v)
	score = v
	scoreLbl.Text = tostring(v)
end

local function popScore()
	scoreScale.Scale = 1.4
	tween(scoreScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	scoreLbl.TextColor3 = Color3.fromRGB(190, 255, 255)
	tween(scoreLbl, 0.4, { TextColor3 = Color3.new(1, 1, 1) })
end

local function spawnPipe(x)
	for _, p in ipairs(pipes) do
		if not p.active then
			local lo, hi = GAP / 2 + 40, PH - GAP / 2 - 40
			local gy = math.clamp(lastGapY + math.random(-110, 110), lo, hi)
			lastGapY = gy
			p.x = x
			p.gapY = gy
			p.scored = false
			p.active = true
			placePipe(p)
			return
		end
	end
end

local function resetWorld()
	for _, p in ipairs(pipes) do
		p.active = false
		placePipe(p)
	end
	birdY, birdV = PH * 0.45, 0
	lastGapY = PH * 0.5
	setScore(0)
	flapAnim = 0
	shake = 0
	deadTimer = 0
	overShown = false
	area.Position = UDim2.fromOffset(0, TITLE)
end

local function goMenu()
	state = "menu"
	resetWorld()
	scoreLbl.Visible = false
	hint.Visible = false
	bestMenu.Text = "BEST " .. best
	showOverlay(overO, false)
	showOverlay(startO, true)
end

local function goReady()
	state = "ready"
	resetWorld()
	scoreLbl.Visible = true
	hint.Visible = true
	showOverlay(startO, false)
	showOverlay(overO, false)
end

local function flap()
	if paused then return end
	if state == "ready" then
		state = "play"
		hint.Visible = false
		spawnPipe(GW + 40)
	end
	if state == "play" then
		birdV = FLAP
		flapAnim = 0.22
		play("flap")
		emit(3, BX - 18, birdY + 6)
	end
end

local function die()
	if state ~= "play" then return end
	state = "over"
	play("hit")
	shake = 0.3
	deadTimer = 0
	flash.BackgroundTransparency = 0.25
	tween(flash, 0.4, { BackgroundTransparency = 1 })
	emit(8, BX, birdY, Color3.fromRGB(255, 200, 90))
	hint.Visible = false
end

local function showGameOver()
	overShown = true
	local isBest = score > best
	if isBest then best = score end
	finalLbl.Text = tostring(score)
	bestLbl.Text = "BEST " .. best
	newBest.Visible = isBest and score > 0

	local col, ring, txt = Color3.fromRGB(90, 96, 120), Color3.fromRGB(150, 156, 180), "-"
	if score >= 30 then col, ring, txt = Color3.fromRGB(240, 200, 60), Color3.fromRGB(255, 240, 150), "G"
	elseif score >= 15 then col, ring, txt = Color3.fromRGB(190, 200, 215), Color3.fromRGB(235, 240, 250), "S"
	elseif score >= 5 then col, ring, txt = Color3.fromRGB(196, 124, 60), Color3.fromRGB(240, 170, 100), "B" end
	medal.BackgroundColor3 = col
	medalStroke.Color = ring
	medalText.Text = txt

	scoreLbl.Visible = false
	showOverlay(overO, true)
end

--==================================================
-- MAIN UPDATE LOOP (one connection, only while the panel is open)
--==================================================

local loop

local function circleHitsRect(cx, cy, r, rx, ry, rw, rh)
	local nx = math.clamp(cx, rx, rx + rw)
	local ny = math.clamp(cy, ry, ry + rh)
	local dx, dy = cx - nx, cy - ny
	return dx * dx + dy * dy < r * r
end

local function step(dt)
	dt = math.min(dt, 1 / 30)
	clock = clock + dt

	-- glowing border
	winGrad.Rotation = (winGrad.Rotation + 70 * dt) % 360
	titleGrad.Offset = Vector2.new(math.sin(clock * 1.5) * 0.35, 0)

	if paused then return end
	if grace > 0 then
		grace = grace - dt
		return
	end

	local moving = state ~= "over"
	local worldSpeed = (state == "play") and SPEED or ((state == "over") and 0 or SPEED * 0.55)

	-- background scroll
	farX = (farX + worldSpeed * 0.12 * dt) % GW
	nearX = (nearX + worldSpeed * 0.3 * dt) % GW
	groundX = (groundX + worldSpeed * dt) % 28
	farHills.Position = UDim2.fromOffset(-farX, 0)
	nearHills.Position = UDim2.fromOffset(-nearX, 0)
	for i, s in ipairs(stripes) do
		s.Position = UDim2.fromOffset((i - 1) * 28 - groundX, 15)
	end

	for _, c in ipairs(clouds) do
		c.x = c.x - (c.v + worldSpeed * 0.04) * dt
		if c.x < -c.w - 10 then c.x = GW + 10 end
		c.f.Position = UDim2.fromOffset(c.x, c.f.Position.Y.Offset)
	end

	-- bird logic
	if state == "menu" or state == "ready" then
		birdY = PH * 0.45 + math.sin(clock * 5) * 6
		birdV = 0
		if state == "menu" then birdY = PH * 0.45 - 20 + math.sin(clock * 3) * 8 end
	elseif state == "play" then
		birdV = math.min(birdV + GRAVITY * dt, MAXFALL)
		birdY = birdY + birdV * dt

		if birdY - BR < 0 then
			birdY = BR
			if birdV < 0 then birdV = 0 end
		end

		-- pipes
		local last = nil
		for _, p in ipairs(pipes) do
			if p.active then
				p.x = p.x - SPEED * dt
				placePipe(p)
				if not last or p.x > last.x then last = p end

				if not p.scored and p.x + PW < BX - BR then
					p.scored = true
					setScore(score + 1)
					popScore()
					play("score")
				end

				if p.x + CAPW < -10 then
					p.active = false
					placePipe(p)
				else
					local top, bot = p.gapY - GAP / 2, p.gapY + GAP / 2
					if circleHitsRect(BX, birdY, BR, p.x, -10, PW, top - CAPH + 10)
					or circleHitsRect(BX, birdY, BR, p.x - 4, top - CAPH, CAPW, CAPH)
					or circleHitsRect(BX, birdY, BR, p.x - 4, bot, CAPW, CAPH)
					or circleHitsRect(BX, birdY, BR, p.x, bot + CAPH, PW, GH) then
						die()
					end
				end
			end
		end

		if last == nil or last.x < GW - SPACING then
			spawnPipe(GW + 20)
		end

		if state == "play" and birdY + BR >= PH then
			birdY = PH - BR
			die()
		end
	elseif state == "over" then
		-- fall to the ground
		deadTimer = deadTimer + dt
		if birdY + BR < PH then
			birdV = math.min(birdV + GRAVITY * dt, MAXFALL + 200)
			birdY = math.min(birdY + birdV * dt, PH - BR)
		end
		if deadTimer > 0.7 and not overShown then
			showGameOver()
		end
	end

	-- bird visuals
	local tilt
	if state == "over" then
		tilt = 80
	else
		tilt = math.clamp(birdV / 9, -24, 70)
	end
	bird.Position = UDim2.fromOffset(BX, birdY)
	bird.Rotation = bird.Rotation + (tilt - bird.Rotation) * math.min(1, dt * 12)

	-- wing animation
	if flapAnim > 0 then flapAnim = flapAnim - dt end
	if state == "over" then
		wing.Rotation = 30
	elseif flapAnim > 0 then
		wing.Rotation = -50 + (1 - flapAnim / 0.22) * 90
	else
		local rate = (state == "play" and birdV > 80) and 1.5 or 7
		wing.Rotation = math.sin(clock * rate) * 18
		if state == "play" and birdV > 80 then wing.Rotation = 24 end
	end

	-- shadow
	local sh = math.clamp(1 - (PH - birdY) / PH, 0.35, 1)
	shadow.Position = UDim2.fromOffset(BX, PH - 4)
	shadow.Size = UDim2.fromOffset(34 * sh, 7 * sh)
	shadow.BackgroundTransparency = 0.82 - 0.2 * sh

	-- particles
	for _, p in ipairs(particles) do
		if p.f.Visible then
			p.life = p.life + dt
			if p.life >= p.max then
				p.f.Visible = false
			else
				local a = p.life / p.max
				p.x = p.x + (p.vx - worldSpeed * 0.5) * dt
				p.y = p.y + p.vy * dt
				p.f.Position = UDim2.fromOffset(p.x, p.y)
				p.f.Size = UDim2.fromOffset(6 * (1 - a) + 2, 6 * (1 - a) + 2)
				p.f.BackgroundTransparency = a
			end
		end
	end

	-- screen shake
	if shake > 0 then
		shake = shake - dt
		area.Position = UDim2.fromOffset(math.random(-3, 3), TITLE + math.random(-3, 3))
		if shake <= 0 then area.Position = UDim2.fromOffset(0, TITLE) end
	end
end

local function startLoop()
	if loop then return end
	loop = RunService.RenderStepped:Connect(step)
end

local function stopLoop()
	if loop then
		loop:Disconnect()
		loop = nil
	end
end

local SPACE_ACTION = "AAYAN_FLAPPY_SPACE"

local function spaceHandler(_, inputState)
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Sink
	end
	if state == "menu" then goReady()
	elseif state == "over" then
		if overShown then goReady() end
	else flap() end
	return Enum.ContextActionResult.Sink
end

--==================================================
-- OPEN / CLOSE / MINIMIZE
--==================================================

local isOpen = false
local minimized = false
local busy = 0

local function applyMinimize(m, instant)
	minimized = m
	local h = m and TITLE or (GH + TITLE)
	if instant then
		holder.Size = UDim2.fromOffset(GW, h)
	else
		tween(holder, 0.3, { Size = UDim2.fromOffset(GW, h) }, Enum.EasingStyle.Quart)
	end
	paused = m
	if not m then grace = 0.8 end
	miniBtn.Text = m and "+" or "-"
end

local function setOpen(open)
	isOpen = open
	busy = busy + 1
	local id = busy

	if open then
		holder.Visible = true
		win.Position = UDim2.fromOffset(-50, 0)
		win.GroupTransparency = 1
		tween(win, 0.4, { Position = UDim2.fromOffset(0, 0), GroupTransparency = 0 }, Enum.EasingStyle.Back)
		if minimized then applyMinimize(false, true) end
		goMenu()
		startLoop()
		CAS:BindAction(SPACE_ACTION, spaceHandler, false, Enum.KeyCode.Space)
	else
		stopLoop()
		CAS:UnbindAction(SPACE_ACTION)
		local tw = tween(win, 0.3, { Position = UDim2.fromOffset(-50, 0), GroupTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		tw.Completed:Connect(function()
			if busy == id and not isOpen then holder.Visible = false end
		end)
	end
end

--==================================================
-- BUTTON LOGIC
--==================================================

bind(playBtn.Activated, goReady)
bind(againBtn.Activated, goReady)
bind(menuBtn.Activated, goMenu)
bind(restartBtn.Activated, function()
	if minimized then applyMinimize(false) end
	goReady()
end)
bind(closeBtn.Activated, function() setOpen(false) end)
bind(miniBtn.Activated, function() applyMinimize(not minimized) end)
bind(muteBtn.Activated, function()
	muted = not muted
	muteBtn.Text = muted and "M" or "S"
	muteBtn.TextColor3 = muted and Color3.fromRGB(255, 110, 110) or Color3.fromRGB(150, 255, 170)
end)

bind(tapArea.Activated, flap)

--==================================================
-- DRAGGING (title bar moves the window, toggle moves itself)
--==================================================

local drag = nil

local function makeDraggable(object, handle, getScale, onTap)
	bind(handle.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
			drag = {
				object = object,
				start = input.Position,
				pos = object.Position,
				scale = getScale,
				moved = false,
				onTap = onTap,
			}
		end
	end)
end

bind(UIS.InputChanged, function(input)
	local d = drag
	if not d then return end
	if input.UserInputType == Enum.UserInputType.MouseMovement
	or input.UserInputType == Enum.UserInputType.Touch then
		local delta = input.Position - d.start
		if not d.moved and delta.Magnitude > 8 then d.moved = true end
		if d.moved then
			local sc = d.scale and d.scale() or 1
			d.object.Position = UDim2.new(
				d.pos.X.Scale, d.pos.X.Offset + delta.X / sc,
				d.pos.Y.Scale, d.pos.Y.Offset + delta.Y / sc
			)
		end
	end
end)

bind(UIS.InputEnded, function(input)
	local d = drag
	if not d then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1
	or input.UserInputType == Enum.UserInputType.Touch then
		drag = nil
		if not d.moved and d.onTap then d.onTap() end
	end
end)

makeDraggable(holder, titleBar, function() return holderScale.Scale end)

--==================================================
-- LEFT TOGGLE
--==================================================

local toggle = new("TextButton", {
	Name = "Toggle",
	Size = UDim2.fromOffset(52, 52),
	Position = UDim2.new(0, 12, 0.5, 34),
	BackgroundColor3 = Color3.fromRGB(14, 12, 34),
	Text = "A",
	TextColor3 = CYAN,
	TextSize = 24,
	Font = Enum.Font.GothamBlack,
	AutoButtonColor = false,
	ZIndex = 50,
}, sg)
round(toggle)
local toggleStroke = stroke(toggle, Color3.new(1, 1, 1), 2.4, 0)
local toggleGrad = grad(toggleStroke, CYAN, PURPLE, 0)
grad(toggle, Color3.fromRGB(26, 22, 64), Color3.fromRGB(10, 8, 26), 90)

makeDraggable(toggle, toggle, nil, function()
	setOpen(not isOpen)
end)

bind(RunService.RenderStepped, function(dt)
	toggleGrad.Rotation = (toggleGrad.Rotation + 90 * dt) % 360
end)

--==================================================
-- CLEANUP
--==================================================

local function cleanup()
	stopLoop()
	pcall(function() CAS:UnbindAction(SPACE_ACTION) end)
	for _, c in ipairs(conns) do
		pcall(function() c:Disconnect() end)
	end
	conns = {}
	if sg and sg.Parent then sg:Destroy() end
	_G.AAYAN_FLAPPY_CLEANUP = nil
end

_G.AAYAN_FLAPPY_CLEANUP = cleanup

bind(sg.Destroying, function()
	stopLoop()
	pcall(function() CAS:UnbindAction(SPACE_ACTION) end)
	for _, c in ipairs(conns) do
		pcall(function() c:Disconnect() end)
	end
end)

resetWorld()
bestMenu.Text = "BEST 0"

print("====================================")
print("   AAYAN V3 | FLAPPY BIRD LOADED")
print("   Tap the A button on the left")
print("====================================")
