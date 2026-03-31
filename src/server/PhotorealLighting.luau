--!strict
-- Tuned global look: Lighting.Technology + atmosphere + post-FX. Roblox has no custom surface shaders;
-- “photorealistic” here means Future renderer, balanced PBR env scales, and subtle post-processing.

local Lighting = game:GetService("Lighting")

local EFFECT_NAMES = {
	Bloom = "ReadyOrKnotBloom",
	ColorCorrect = "ReadyOrKnotColorCorrect",
	SunRays = "ReadyOrKnotSunRays",
}

local function destroyNamedEffects()
	for _, name in EFFECT_NAMES do
		local old = Lighting:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
end

local function applyPostEffects()
	destroyNamedEffects()

	local bloom = Instance.new("BloomEffect")
	bloom.Name = EFFECT_NAMES.Bloom
	bloom.Intensity = 0.32
	bloom.Size = 22
	bloom.Threshold = 0.88
	bloom.Parent = Lighting

	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = EFFECT_NAMES.ColorCorrect
	cc.Brightness = 0.03
	cc.Contrast = 0.1
	cc.Saturation = 0.05
	cc.TintColor = Color3.fromRGB(255, 252, 248)
	cc.Parent = Lighting

	local rays = Instance.new("SunRaysEffect")
	rays.Name = EFFECT_NAMES.SunRays
	rays.Intensity = 0.14
	rays.Spread = 0.14
	rays.Parent = Lighting
end

function applyPhotorealLighting()
	-- Future: modern lighting model (closest to “realistic” materials + shadows in Roblox).
	pcall(function()
		Lighting.Technology = Enum.LightingTechnology.Future
	end)

	Lighting.GlobalShadows = true
	pcall(function()
		Lighting.ShadowSoftness = 0.14
	end)

	-- Midday lake reference: bright sun, blue sky bias, readable water + treeline.
	Lighting.ClockTime = 13.1
	Lighting.GeographicLatitude = 44
	Lighting.Ambient = Color3.fromRGB(118, 128, 138)
	Lighting.OutdoorAmbient = Color3.fromRGB(138, 148, 158)
	Lighting.Brightness = 2.05
	Lighting.ExposureCompensation = 0.08

	pcall(function()
		Lighting.ColorShift_Top = Color3.fromRGB(205, 225, 248)
		Lighting.ColorShift_Bottom = Color3.fromRGB(92, 100, 108)
	end)

	-- PBR environment response (materials read more “real” than flat defaults).
	Lighting.EnvironmentDiffuseScale = 0.74
	Lighting.EnvironmentSpecularScale = 0.82

	pcall(function()
		local ib = (Lighting :: any).IndirectBrightness
		if typeof(ib) == "number" then
			(Lighting :: any).IndirectBrightness = 1.05
		end
	end)

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmosphere then
		atmosphere = Instance.new("Atmosphere")
		atmosphere.Parent = Lighting
	end
	-- Clear air, slightly lighter horizon (open water + distant trees).
	atmosphere.Density = 0.245
	atmosphere.Offset = 0.04
	atmosphere.Color = Color3.fromRGB(195, 218, 238)
	atmosphere.Decay = Color3.fromRGB(148, 175, 200)
	atmosphere.Glare = 0.1
	atmosphere.Haze = 0.38

	pcall(function()
		local clouds = Lighting:FindFirstChildOfClass("Clouds")
		if not clouds then
			clouds = Instance.new("Clouds")
			clouds.Parent = Lighting
		end
		local c = clouds :: any
		if c.Cover ~= nil then
			c.Cover = 0.42
		end
		if c.Density ~= nil then
			c.Density = 0.55
		end
	end)

	applyPostEffects()
end

return {
	apply = applyPhotorealLighting,
}
