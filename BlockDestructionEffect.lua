--[[ 
	BLOCK DESTRUCTION EFFECT - Jujutsu Shenanigans Style
	Script untuk hancurkan blok/part di sekitar skill dengan efek keren
	Tempat: ServerScriptService atau dalam skill script
]]

local DestructionEffect = {}
DestructionEffect.__index = DestructionEffect

-- ===================== KONFIGURASI =====================
local CONFIG = {
	-- Area hancuran
	radius = 50, -- Jarak hancur dari center
	maxBlocks = 30, -- Max blok yang hancur sekaligus
	
	-- Physics pecahan
	speed = {min = 50, max = 150}, -- Kecepatan pecahan berhamburan
	spinSpeed = {min = 10, max = 30}, -- Kecepatan rotasi
	gravity = 196.2, -- Gravitasi normal
	
	-- Ukuran pecahan
	minFragmentSize = 0.5,
	maxFragmentSize = 3,
	
	-- Lifetime
	fragmentLife = {min = 3, max = 8}, -- Berapa lama pecahan bertahan (detik)
	fadeDuration = 0.5, -- Durasi fade out
	
	-- Visual
	sparkColor = Color3.fromRGB(255, 200, 0), -- Warna percikan
	dustColor = Color3.fromRGB(150, 150, 150), -- Warna debu
	enableSparks = true,
	enableDust = true,
}

-- ===================== FUNGSI HANCUR BLOK =====================

function DestructionEffect:CreateExplosion(center, radius, config)
	config = config or CONFIG
	local workspace = game:GetService("Workspace")
	local blocksToDestroy = {}
	
	-- Cari semua part dalam radius
	local region = Region3.new(center - Vector3.new(radius, radius, radius), center + Vector3.new(radius, radius, radius))
	region = region:ExpandToGrid(4)
	
	for _, part in pairs(workspace:FindPartsInRegion3(region, nil, 100)) do
		-- Filter: jangan hancurin character, script, atau part tertentu
		if part.Parent and part.Parent:FindFirstChild("Humanoid") == nil and 
		   part.CanCollide and not part.Parent:IsDescendantOf(game:GetService("Players")) then
			if #blocksToDestroy < config.maxBlocks then
				table.insert(blocksToDestroy, part)
			end
		end
	end
	
	-- Hancurkan blok-blok tersebut
	for _, block in pairs(blocksToDestroy) do
		self:DestroyBlock(block, center, config)
	end
	
	-- Buat efek visual di center
	if config.enableDust then
		self:CreateDustCloud(center, radius * 0.6)
	end
	if config.enableSparks then
		self:CreateSparks(center, radius * 0.8)
	end
end

function DestructionEffect:DestroyBlock(block, center, config)
	config = config or CONFIG
	
	-- Clone block buat jadi pecahan
	local fragment = block:Clone()
	fragment.Parent = workspace
	
	-- Pisahin dari groupnya (kalau ada)
	pcall(function()
		block.Parent:Destroy()
	end)
	
	-- Ubah ukuran jadi random (pecahan yang lebih kecil)
	local fragmentSize = math.random(config.minFragmentSize * 10, config.maxFragmentSize * 10) / 10
	local originalSize = fragment.Size
	fragment.Size = Vector3.new(
		originalSize.X * fragmentSize,
		originalSize.Y * fragmentSize,
		originalSize.Z * fragmentSize
	)
	
	-- Position random di sekitar original
	local offset = Vector3.new(
		math.random(-50, 50) / 10,
		math.random(-30, 30) / 10,
		math.random(-50, 50) / 10
	)
	fragment.Position = block.Position + offset
	
	-- Beri kecepatan (ke luar dari center)
	local direction = (fragment.Position - center).Unit
	local speed = math.random(config.speed.min, config.speed.max)
	
	if fragment:FindFirstChild("BodyVelocity") then
		fragment.BodyVelocity:Destroy()
	end
	
	local bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.Velocity = direction * speed + Vector3.new(0, math.random(20, 40), 0) -- Arah + bounce up
	bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
	bodyVelocity.Parent = fragment
	
	-- Beri rotasi yang random
	if fragment:FindFirstChild("BodyAngularVelocity") then
		fragment.BodyAngularVelocity:Destroy()
	end
	
	local bodyAngularVelocity = Instance.new("BodyAngularVelocity")
	local spin = math.random(config.spinSpeed.min, config.spinSpeed.max)
	bodyAngularVelocity.AngularVelocity = Vector3.new(
		math.random(-spin, spin),
		math.random(-spin, spin),
		math.random(-spin, spin)
	)
	bodyAngularVelocity.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
	bodyAngularVelocity.Parent = fragment
	
	-- Warna berubah jadi terang (impact effect)
	if fragment:IsA("BasePart") then
		fragment.Color = Color3.fromRGB(
			math.min(255, fragment.Color.R * 255 + 100),
			math.min(255, fragment.Color.G * 255 + 100),
			math.min(255, fragment.Color.B * 255 + 100)
		)
	end
	
	-- Hilang setelah beberapa detik dengan fade
	local lifetime = math.random(config.fragmentLife.min * 10, config.fragmentLife.max * 10) / 10
	
	task.delay(lifetime - config.fadeDuration, function()
		if fragment and fragment.Parent then
			self:FadeOutPart(fragment, config.fadeDuration)
		end
	end)
end

function DestructionEffect:FadeOutPart(part, duration)
	local startTransparency = part.Transparency
	local startTime = tick()
	
	while part and part.Parent and (tick() - startTime) < duration do
		local elapsed = tick() - startTime
		local progress = elapsed / duration
		part.Transparency = startTransparency + (1 - startTransparency) * progress
		task.wait(0.05)
	end
	
	if part and part.Parent then
		part:Destroy()
	end
end

function DestructionEffect:CreateDustCloud(position, size)
	local dust = Instance.new("Part")
	dust.Name = "DustCloud"
	dust.Shape = Enum.PartType.Ball
	dust.Size = Vector3.new(size * 0.5, size * 0.5, size * 0.5)
	dust.Color = CONFIG.dustColor
	dust.CanCollide = false
	dust.CFrame = CFrame.new(position)
	dust.TopSurface = Enum.SurfaceType.Smooth
	dust.BottomSurface = Enum.SurfaceType.Smooth
	dust.Parent = workspace
	
	-- Fade out
	task.spawn(function()
		self:FadeOutPart(dust, 1)
	end)
end

function DestructionEffect:CreateSparks(position, size)
	for i = 1, math.random(10, 20) do
		local spark = Instance.new("Part")
		spark.Name = "Spark"
		spark.Shape = Enum.PartType.Ball
		spark.Size = Vector3.new(0.2, 0.2, 0.2)
		spark.Color = CONFIG.sparkColor
		spark.CanCollide = false
		spark.CFrame = CFrame.new(position)
		spark.TopSurface = Enum.SurfaceType.Smooth
		spark.BottomSurface = Enum.SurfaceType.Smooth
		spark.Parent = workspace
		
		-- Physics
		local direction = (Vector3.new(math.random(-100, 100), math.random(50, 150), math.random(-100, 100))).Unit
		local velocity = direction * math.random(80, 200)
		
		local bv = Instance.new("BodyVelocity")
		bv.Velocity = velocity
		bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
		bv.Parent = spark
		
		-- Hilang cepat
		task.spawn(function()
			self:FadeOutPart(spark, 0.5)
		end)
	end
end

-- ===================== EXPORT =====================
return DestructionEffect
