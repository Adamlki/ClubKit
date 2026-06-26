local Players = game:GetService("Players")
local player = Players.LocalPlayer

-- Mengarahkan path ke part WANTEDPOSTER di Workspace
-- Pastikan nama part di Workspace benar-benar "WANTEDPOSTER"
local wantedPoster = workspace:WaitForChild("WANTEDPOSTER", math.huge)
local surfaceGui = wantedPoster:WaitForChild("SurfaceGui")

-- Mencari UI element sesuai dengan struktur di foto
local imageFrame = surfaceGui:WaitForChild("ImageFrame")
local imageLabel = imageFrame:WaitForChild("ImageLabel")

local nameFrame = surfaceGui:WaitForChild("NameFrame")
local textLabel = nameFrame:WaitForChild("TextLabel")

-- 1. Set nama menjadi Nickname (Display Name), bukan Username
textLabel.Text = player.DisplayName

-- 2. Ambil foto avatar player (Tipe HeadShot)
local userId = player.UserId
local thumbType = Enum.ThumbnailType.HeadShot
local thumbSize = Enum.ThumbnailSize.Size420x420 -- Resolusi gambar, bisa diubah jika perlu

-- Proses fetch gambar dari server Roblox dengan pcall untuk mencegah script error jika request gagal
local success, content, isReady = pcall(function()
	return Players:GetUserThumbnailAsync(userId, thumbType, thumbSize)
end)

-- 3. Set gambar ke ImageLabel jika fetch sukses dan gambar siap
if success and isReady then
	imageLabel.Image = content
elseif not success then
	warn("Gagal mengambil foto profil untuk player: " .. player.Name .. ". Error: " .. tostring(content))
end
