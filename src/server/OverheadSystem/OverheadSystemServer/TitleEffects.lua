local TitleEffects = {}

-- Fungsi Utama: Membersihkan segala jenis animasi/gradient dan menerapkan warna biasa
function TitleEffects:ApplySolidColor(titleLabel, baseColor)
	-- 1. Hapus efek warna-warni Gradient (Jika ada)
	local gradient = titleLabel:FindFirstChildOfClass("UIGradient")
	if gradient then gradient:Destroy() end

	-- 2. Hapus script animasi lama (Jika masih menyangkut)
	local oldAnimator = titleLabel:FindFirstChild("GradientAnimator")
	if oldAnimator then oldAnimator:Destroy() end

	-- 3. Terapkan Warna Solid!
	titleLabel.TextColor3 = baseColor or Color3.fromRGB(255, 255, 255)
end

-- ==========================================================
-- JARING PENGAMAN (Agar TitleManager lama tidak Error)
-- Semua panggilan efek lama akan otomatis dialihkan ke Warna Solid
-- ==========================================================
function TitleEffects:StopAnimation() end
function TitleEffects:CreateNoneEffect(label, color) self:ApplySolidColor(label, color) end
function TitleEffects:CreateWaveEffect(label, color) self:ApplySolidColor(label, color) end
function TitleEffects:CreatePulseEffect(label, color) self:ApplySolidColor(label, color) end
function TitleEffects:CreateRainbowEffect(label, color) self:ApplySolidColor(label, color) end
function TitleEffects:CreateShimmerEffect(label, color) self:ApplySolidColor(label, color) end
function TitleEffects:CreatePaletteEffect(label, color) self:ApplySolidColor(label, color) end
function TitleEffects:CreateSunsetEffect(label, color) self:ApplySolidColor(label, color) end
function TitleEffects:CreateOceanEffect(label, color) self:ApplySolidColor(label, color) end
function TitleEffects:CreateGalaxyEffect(label, color) self:ApplySolidColor(label, color) end
function TitleEffects:CreateEmeraldEffect(label, color) self:ApplySolidColor(label, color) end
function TitleEffects:CreatePinkWhiteEffect(label, color) self:ApplySolidColor(label, color) end

return TitleEffects