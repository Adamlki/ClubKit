-- Konfigurasi aset publik. Ganti dengan aset milik pembeli jika diperlukan.
-- AnimationRegistry dan MusicModule tetap menyimpan katalog konten besar.
local AssetConfig = {
	Sounds = {
		Notification = "rbxassetid://79392333090964",
		BackpackClick = "rbxassetid://4499400560",
		SaweriaNotification = "rbxassetid://79392333090964",
		Level4Donation = "rbxassetid://122331425639589",
	},

	Images = {
		Topbar = {
			Menu = "rbxassetid://87603332567027",
			Music = "rbxassetid://123643550590893",
			Dance = "rbxassetid://113394514826547",
			Setting = "rbxassetid://116292866711662",
			FreeCam = "rbxassetid://134750039859396",
			Broadcast = "rbxassetid://124033060370841",
			MyHat = "rbxassetid://120495411505696",
			GlobalEffect = "rbxassetid://84595853614117",
			Gamepass = "rbxassetid://140276937557646",
		},

		AdminNotification = "rbxassetid://7733992901",
		DonationIcon = "rbxassetid://11560341824",
		SaweriaIcon = "rbxassetid://15040641378",
		LikeHeart = "rbxassetid://6034638780",
		BackpackEyeOpen = "rbxassetid://125603824847579",
		BackpackEyeClosed = "rbxassetid://70802654569830",
		ProfileEyeOpen = "rbxassetid://6031075931",
		ProfileEyeClosed = "rbxassetid://6031075929",
		AdminPanelIcon = "rbxassetid://87144040887420",
		PremiumBadge = "rbxassetid://10885647358",
		VerifiedBadge = "rbxassetid://11478378840",
		DefaultCommunityId = 100615948228188,

		GlitchBanners = {
			"rbxassetid://85415938671065",
			"rbxassetid://89819761494578",
			"rbxassetid://107557873401344",
		},
	},

	Animations = {
		Floating = "rbxassetid://112082806790047",
		Fly = "rbxassetid://81229486815853",
		Top3 = {
			Top1 = "rbxassetid://109979406375718",
			Top2 = "rbxassetid://109979406375718",
			Top3 = "rbxassetid://109979406375718",
		},
	},

	Music = {
		DefaultCover = "rbxassetid://88574818940840",
	},
}

return AssetConfig
