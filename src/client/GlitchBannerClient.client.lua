-- ==============================================================================
-- GLITCH BANNER CLIENT (CYBERPUNK TV SLIDESHOW)
-- Menampilkan slideshow gambar di ModelTV (GlitchFoto) dengan efek glitch transisi.
-- ==============================================================================
-- 💡 PETUNJUK PENGGUNA:
-- Untuk menambah atau mengurangi foto, cukup edit daftar ID di bawah ini (IMAGE_LIST).
-- Anda bisa memasukkan format "rbxassetid://123456" atau hanya angka saja "123456".
-- Tidak perlu mengubah kode apapun di bawahnya!
-- ==============================================================================

local IMAGE_LIST = {
	"rbxassetid://85415938671065",  -- Foto 1: Valor House Banner
	"rbxassetid://89819761494578", -- Foto 2: Poster
	"rbxassetid://107557873401344", -- Foto 3: Floor Set Artwork
	-- Tambahkan foto Anda berikutnya di sini, contoh:
	-- "rbxassetid://ID_FOTO_BARU",
}

-- Durasi tiap foto tampil sebelum berganti (dalam detik)
local DISPLAY_DURATION = 6

-- Durasi efek glitch saat pergantian gambar (dalam detik)
local GLITCH_DURATION = 0.35

-- ==============================================================================
-- LOGIKA INTERNAL & SINKRONISASI
-- ==============================================================================
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ContentProvider = game:GetService("ContentProvider")

-- Format ID gambar otomatis jika pengguna hanya mengetik angka
local function normalizeAssetId(raw)
	if not raw then return "" end
	local s = tostring(raw):gsub("%s+", "")
	if s:find("rbxassetid://") or s:find("http") or s:find("rbxthumb://") then
		return s
	end
	local nums = s:match("%d+")
	if nums then
		return "rbxassetid://" .. nums
	end
	return s
end

-- Preload gambar agar saat transisi tidak blank / loading
task.spawn(function()
	local preloadInstances = {}
	for _, id in ipairs(IMAGE_LIST) do
		local fakeImg = Instance.new("ImageLabel")
		fakeImg.Image = normalizeAssetId(id)
		table.insert(preloadInstances, fakeImg)
	end
	pcall(function()
		ContentProvider:PreloadAsync(preloadInstances)
	end)
	for _, fake in ipairs(preloadInstances) do
		fake:Destroy()
	end
end)

-- Mencari instance target di Workspace
local function findBannerElements()
	local glitchModel = workspace:FindFirstChild("GlitchFoto", true)
	if not glitchModel then return nil end
	local screenDisplay = glitchModel:FindFirstChild("ScreenDisplay", true)
	if not screenDisplay then return nil end
	local surfaceGui = screenDisplay:FindFirstChild("BannerSurfaceGui", true)
	if not surfaceGui then return nil end
	local root = surfaceGui:FindFirstChild("BannerRoot", true)
	local mainImage = root and root:FindFirstChild("ImageLabel", true)
	return root, mainImage
end

-- Menyiapkan Layer Efek Glitch di dalam BannerRoot
local function setupGlitchLayers(root, mainImage)
	local container = root:FindFirstChild("GlitchFXContainer")
	if container then return container end

	container = Instance.new("Frame")
	container.Name = "GlitchFXContainer"
	container.Size = UDim2.new(1, 0, 1, 0)
	container.Position = UDim2.new(0, 0, 0, 0)
	container.BackgroundTransparency = 1
	container.ClipsDescendants = true
	container.ZIndex = 5
	container.Parent = root

	-- 1. Layer Red / Magenta (Chromatic Aberration)
	local redLayer = Instance.new("ImageLabel")
	redLayer.Name = "GlitchRed"
	redLayer.Size = UDim2.new(1, 0, 1, 0)
	redLayer.AnchorPoint = Vector2.new(0.5, 0.5)
	redLayer.Position = UDim2.new(0.5, 0, 0.5, 0)
	redLayer.BackgroundTransparency = 1
	redLayer.ImageColor3 = Color3.fromRGB(255, 30, 90)
	redLayer.ImageTransparency = 1
	redLayer.ScaleType = mainImage.ScaleType
	redLayer.ZIndex = 6
	redLayer.Parent = container

	-- 2. Layer Cyan / Blue (Chromatic Aberration)
	local cyanLayer = Instance.new("ImageLabel")
	cyanLayer.Name = "GlitchCyan"
	cyanLayer.Size = UDim2.new(1, 0, 1, 0)
	cyanLayer.AnchorPoint = Vector2.new(0.5, 0.5)
	cyanLayer.Position = UDim2.new(0.5, 0, 0.5, 0)
	cyanLayer.BackgroundTransparency = 1
	cyanLayer.ImageColor3 = Color3.fromRGB(0, 220, 255)
	cyanLayer.ImageTransparency = 1
	cyanLayer.ScaleType = mainImage.ScaleType
	cyanLayer.ZIndex = 7
	cyanLayer.Parent = container

	-- 3. White Flash Overlay
	local flash = Instance.new("Frame")
	flash.Name = "GlitchFlash"
	flash.Size = UDim2.new(1, 0, 1, 0)
	flash.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	flash.BackgroundTransparency = 1
	flash.ZIndex = 8
	flash.Parent = container

	-- 4. Horizontal Slices / Tear Bars (Cyberpunk Scanline Jitter)
	local slices = {}
	for i = 1, 4 do
		local slice = Instance.new("Frame")
		slice.Name = "GlitchSlice_" .. i
		slice.Size = UDim2.new(1, 0, 0, math.random(12, 35))
		slice.Position = UDim2.new(0, 0, 0, 0)
		slice.BackgroundColor3 = (i % 2 == 0) and Color3.fromRGB(0, 220, 255) or Color3.fromRGB(255, 30, 90)
		slice.BackgroundTransparency = 1
		slice.ZIndex = 9
		slice.Parent = container
		table.insert(slices, slice)
	end

	return container
end

-- Fungsi Animasi Glitch saat berpindah ke gambar baru
local isGlitching = false
local function playGlitchTransition(root, mainImage, nextImageId)
	if isGlitching then return end
	isGlitching = true

	local container = setupGlitchLayers(root, mainImage)
	local redLayer = container:FindFirstChild("GlitchRed")
	local cyanLayer = container:FindFirstChild("GlitchCyan")
	local flash = container:FindFirstChild("GlitchFlash")

	local slices = {}
	for i = 1, 4 do
		local s = container:FindFirstChild("GlitchSlice_" .. i)
		if s then table.insert(slices, s) end
	end

	local startTime = os.clock()
	local halfDuration = GLITCH_DURATION * 0.45
	local swapped = false

	-- Persiapkan gambar layer aberasi
	if redLayer then redLayer.Image = mainImage.Image end
	if cyanLayer then cyanLayer.Image = mainImage.Image end

	while true do
		local elapsed = os.clock() - startTime
		local progress = math.clamp(elapsed / GLITCH_DURATION, 0, 1)

		if elapsed >= halfDuration and not swapped then
			swapped = true
			mainImage.Image = nextImageId
			if redLayer then redLayer.Image = nextImageId end
			if cyanLayer then cyanLayer.Image = nextImageId end
		end

		-- Hitung intensitas getar (peak di tengah, memudar di akhir)
		local intensity = 1 - math.abs(progress - 0.5) * 2
		local maxOffset = 28 * intensity

		-- Jitter posisi gambar utama
		mainImage.Position = UDim2.new(
			0.5, math.random(-maxOffset, maxOffset),
			0.5, math.random(-maxOffset * 0.4, maxOffset * 0.4)
		)

		-- Jitter layer aberasi warna merah & cyan
		if redLayer then
			redLayer.Position = UDim2.new(
				0.5, math.random(-maxOffset * 1.4, maxOffset * 1.4),
				0.5, math.random(-maxOffset * 0.5, maxOffset * 0.5)
			)
			redLayer.ImageTransparency = math.clamp(1 - (intensity * 0.65), 0.35, 1)
		end

		if cyanLayer then
			cyanLayer.Position = UDim2.new(
				0.5, math.random(-maxOffset * 1.4, maxOffset * 1.4),
				0.5, math.random(-maxOffset * 0.5, maxOffset * 0.5)
			)
			cyanLayer.ImageTransparency = math.clamp(1 - (intensity * 0.65), 0.35, 1)
		end

		-- Flash putih samar acak
		if flash then
			if math.random() > 0.65 and intensity > 0.3 then
				flash.BackgroundTransparency = math.random(85, 95) / 100
			else
				flash.BackgroundTransparency = 1
			end
		end

		-- Garis slice / tearing acak
		for _, slice in ipairs(slices) do
			if math.random() > 0.4 and intensity > 0.25 then
				slice.Position = UDim2.new(
					0, math.random(-30, 30),
					math.random(5, 90) / 100, 0
				)
				slice.Size = UDim2.new(1, math.random(20, 60), 0, math.random(10, 30))
				slice.BackgroundTransparency = math.random(40, 75) / 100
			else
				slice.BackgroundTransparency = 1
			end
		end

		if progress >= 1 then break end
		RunService.RenderStepped:Wait()
	end

	-- Reset & stabilkan tampilan kembali ke normal
	mainImage.Position = UDim2.new(0.5, 0, 0.5, 0)
	mainImage.Image = nextImageId
	mainImage.ImageTransparency = 0
	mainImage.ImageColor3 = Color3.fromRGB(255, 255, 255)

	if redLayer then redLayer.ImageTransparency = 1 end
	if cyanLayer then cyanLayer.ImageTransparency = 1 end
	if flash then flash.BackgroundTransparency = 1 end
	for _, slice in ipairs(slices) do
		slice.BackgroundTransparency = 1
	end

	isGlitching = false
end

-- ==============================================================================
-- MAIN LOOP (Tersinkronisasi Antar Semua Pemain via GetServerTimeNow)
-- ==============================================================================
task.spawn(function()
	-- Tunggu hingga instance ModelTV & ImageLabel ter-load di workspace
	local root, mainImage
	while not mainImage do
		root, mainImage = findBannerElements()
		if not mainImage then task.wait(1) end
	end

	if #IMAGE_LIST == 0 then return end

	local lastCycleIndex = -1

	while true do
		task.wait(0.2)

		-- Pastikan target masih valid
		if not mainImage or not mainImage.Parent then
			root, mainImage = findBannerElements()
		end

		if mainImage and #IMAGE_LIST > 0 then
			-- Waktu global server yang seragam untuk semua pemain
			local serverTime = workspace:GetServerTimeNow()
			local currentCycle = math.floor(serverTime / DISPLAY_DURATION)
			local imageIndex = (currentCycle % #IMAGE_LIST) + 1
			local targetImage = normalizeAssetId(IMAGE_LIST[imageIndex])

			if lastCycleIndex == -1 then
				-- Pertama kali pemain bergabung: langsung set gambar saat ini tanpa glitch
				lastCycleIndex = currentCycle
				mainImage.Image = targetImage
			elseif lastCycleIndex ~= currentCycle then
				-- Waktu berganti: picu efek glitch transisi!
				lastCycleIndex = currentCycle
				if #IMAGE_LIST > 1 then
					playGlitchTransition(root, mainImage, targetImage)
				else
					mainImage.Image = targetImage
				end
			end
		end
	end
end)

print("[GLITCH BANNER] Client slideshow running with " .. #IMAGE_LIST .. " images synced!")
