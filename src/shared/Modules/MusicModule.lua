-- ==============================================================================
-- MUSIC MODULE - RASA NADA
-- ==============================================================================
-- Modul konfigurasi & database musik.
-- 
-- 💡 CARA MENAMBAH / MENGUBAH LAGU:
-- 1. Buka kategori playlist di bawah (PLAYLIST 1, PLAYLIST 2, BREAKBEAT, dll).
-- 2. Tambahkan satu baris baru, contoh:
--    { id = "1234567890", judul = "Nama Artis - Judul Lagu" },
--    atau jika lagunya dipercepat / diperlambat:
--    { id = "1234567890", judul = "Nama Artis - Judul Lagu", speed = 0.9 },
--    atau jika ada pitch khusus:
--    { id = "1234567890", judul = "Nama Artis - Judul Lagu", speed = 0.7, pitch = 1.1 },
-- 
-- 🎨 FITUR OTOMATIS:
-- * Gambar cover (sampul) otomatis mengikuti gambar cover playlist masing-masing.
-- * Album otomatis terisi sesuai kategori tempat lagu diletakkan.
-- * Durasi lagu otomatis dideteksi saat diputar.
-- ==============================================================================

local MusicModule = {}

-- ==============================================================================
-- 1. ALBUM / PLAYLIST COVER CONFIGURATION
-- Gambar cover ini otomatis dipakai di menu Playlist, Album, dan popup NowPlaying.
-- Ubah rbxassetid di bawah ini jika ingin mengganti gambar cover playlist tertentu.
-- ==============================================================================
MusicModule.ALBUM_COVERS = {
	["All Songs"]      = "rbxassetid://100674441262590", -- Cover RASA NADA Utama
	["My Favorites"]   = "rbxassetid://113553647698301", -- Icon Hati / Love
	["PLAYLIST 1"]     = "rbxassetid://75519739809680",  -- Music Note Icon
	-- ["THAILAND STYLE"] = "rbxassetid://92853116803097",  -- DJ / Thailand Style Cover
	-- ["BREAKBEAT"]      = "rbxassetid://106900580552131", -- Breakbeat Headphones Badge
	-- ["FUNKOT STYLE"]   = "rbxassetid://99989680726270",  -- Party / Dance Icon
	-- ["PLAYLIST 2"]     = "rbxassetid://114910483744172", -- DJ Global Effect Icon
}

-- ==============================================================================
-- 2. PLAYLIST DATABASE
-- Semua lagu dikelompokkan per playlist agar rapi dan mudah dicari/diedit.
-- ==============================================================================
MusicModule.PLAYLISTS = {
	-- ==========================================================
	-- PLAYLIST 1 (175 Lagu)
	-- ==========================================================
	["PLAYLIST 1"] = {
		{ id = "125646898891578", judul = "I Want It That Way - Backstreet Boys", speed = 0.43 },
		{ id = "100783222387599", judul = "Merry Christmas, i miss you", speed = 0.43 },
		{ id = "121283683428723", judul = "Nan Ko Paham", speed = 0.43 },
		{ id = "95651541418090", judul = "Mama Muda", speed = 0.43 },
		{ id = "76523374268869", judul = "Craig David - Insomnia", speed = 0.43 },
		{ id = "135033298059465", judul = "XXXTENTACION - MOONLIGHT", speed = 0.43 },
		{ id = "86764436136518", judul = "Silentó - Watch Me", speed = 0.43 },
		{ id = "78290476023961", judul = "XXXTENTACION - Hope Lyrics", speed = 0.43 },
		{ id = "121824746909544", judul = "Playboi Carti - Popular", speed = 0.43 },
		{ id = "131927192196618", judul = "Marshmello -Tayna - Si Ai", speed = 0.43 },
		{ id = "136510425601395", judul = "SZA - Nobody Gets Me", speed = 0.43 },
		{ id = "84032558464404", judul = "SZA - Cry Baby", speed = 0.43 },
		{ id = "114617443993246", judul = "SZA - BMF (Lyrics)", speed = 0.43 },
		{ id = "116585869468965", judul = "The Weeknd - Starboy", speed = 0.43 },
		{ id = "93125541591656", judul = "Side To Side - Ariana Grande", speed = 0.43 },
		{ id = "100524075819088", judul = "She's From London - George Kipa", speed = 0.43 },
		{ id = "110051252513221", judul = "RapHype -Sean Kingston - Take You There", speed = 0.43 },
		{ id = "105667292561893", judul = "Sean Kingston - Beat It", speed = 0.43 },
		{ id = "81188260204701", judul = "Rihanna - Where Have You Been", speed = 0.43 },
		{ id = "130271229908700", judul = "Roddy Ricch - The Box", speed = 0.43 },
		{ id = "81243224827966", judul = "Rae Sremmurd, Gucci Mane - Black Beatles", speed = 0.43 },
		{ id = "127228856109711", judul = "RAYE - Escapism", speed = 0.43 },
		{ id = "108994506903867", judul = "Pedro Capó, Farruko - Calma Remix", speed = 0.43 },
		{ id = "137221267065691", judul = "Post Malone - Sunflower", speed = 0.43 },
		{ id = "76130485266229", judul = "Ariana Grande - Past Life", speed = 0.43 },
		{ id = "99101241804660", judul = "Ariana Grande - One Last Time", speed = 0.43 },
		{ id = "135820276960341", judul = "Migos - Walk It Talk It ft. Drake", speed = 0.43 },
		{ id = "108110183691123", judul = "Ra The Lotus of Life, V2", speed = 0.43 },
		{ id = "90483802970214", judul = "Lil Uzi Vert - XO Tour Llif3", speed = 0.43 },
		{ id = "105960191493572", judul = "Oh Wonder - The Way Life Goes", speed = 0.43 },
		{ id = "105860938361598", judul = "Lil Uzi Vert - 20 Min", speed = 0.43 },
		{ id = "74003136527388", judul = "Liam Payne - Strip That Down", speed = 0.43 },
		{ id = "79885578635912", judul = "Kid Ink - That's On You", speed = 0.43 },
		{ id = "102450256726643", judul = "Khalid - Young Dumb & Broke", speed = 0.43 },
		{ id = "87036855530388", judul = "Kendrick Lamar - Love. ft. Zacari", speed = 0.43 },
		{ id = "95559767499582", judul = "Kendrick Lamar, SZA - All The Stars", speed = 0.43 },
		{ id = "74014725372468", judul = "Kehlani - Folded", speed = 0.43 },
		{ id = "122960409092499", judul = "Kehlani - After Hours", speed = 0.43 },
		{ id = "114956510881544", judul = "Katy Perry - Roar", speed = 0.43 },
		{ id = "108339005764549", judul = "Katy Perry - The One That Got Away", speed = 0.43 },
		{ id = "100370148445715", judul = "Katy Perry - Dark Horse", speed = 0.43 },
		{ id = "71809343268051", judul = "Katy Perry - Firework", speed = 0.43 },
		{ id = "99556748374659", judul = "Justine Skye - Collide", speed = 0.43 },
		{ id = "106934200680923", judul = "Justin Bieber - What Do You Mean", speed = 0.43 },
		{ id = "93640916640275", judul = "Justin Bieber - Yummy", speed = 0.43 },
		{ id = "137415503065145", judul = "Justin Bieber - Stay", speed = 0.43 },
		{ id = "95712089626475", judul = "Justin Bieber - Sorry", speed = 0.43 },
		{ id = "72708382299000", judul = "Justin Bieber - Holy", speed = 0.43 },
		{ id = "88409750869371", judul = "Justin Bieber - One Time", speed = 0.43 },
		{ id = "124685841807246", judul = "Justin Bieber - Peaches", speed = 0.43 },
		{ id = "74443340462189", judul = "Justin Bieber - Never Say Never", speed = 0.43 },
		{ id = "103657160514946", judul = "Justin Bieber - Love Me", speed = 0.43 },
		{ id = "120877563084818", judul = "Justin Bieber - Intentions", speed = 0.43 },
		{ id = "78490216357817", judul = "Justin Bieber -Justin Bieber - Ghost", speed = 0.43 },
		{ id = "94215987701261", judul = "Despacito ft. Justin Bieber", speed = 0.43 },
		{ id = "96676193407958", judul = "Justin Bieber - Confident", speed = 0.43 },
		{ id = "85460247692154", judul = "Justin Bieber - Company", speed = 0.43 },
		{ id = "79132478561106", judul = "Justin Bieber Beauty And A Beat", speed = 0.43 },
		{ id = "131491415816584", judul = "Justin Bieber - Anyone", speed = 0.43 },
		{ id = "104490201265759", judul = "Justin Bieber - Baby", speed = 0.43 },
		{ id = "108984025481209", judul = "JAY-Z - Empire State Of Mind", speed = 0.43 },
		{ id = "80542642607547", judul = "Jessie J - Price Tag", speed = 0.43 },
		{ id = "136517764415094", judul = "Bee Gees - How Deep Is Your Love", speed = 0.43 },
		{ id = "129089738643502", judul = "Jae.T - Holiday", speed = 0.43 },
		{ id = "88627512695946", judul = "French Montana - Unforgettable", speed = 0.43 },
		{ id = "73024591643775", judul = "Skepta x PlaqueBoyMax - Victory Lap", speed = 0.43 },
		{ id = "92717486049398", judul = "El Perdon - Nicky Jam x Enrique Iglesias", speed = 0.43 },
		{ id = "139625955772707", judul = "Travis Scott - FE!N", speed = 0.43 },
		{ id = "88799870242729", judul = "Ed Sheeran & Justin Bieber - I Don't Care", speed = 0.43 },
		{ id = "117129563183536", judul = "Dua Lipa - Levitating", speed = 0.43 },
		{ id = "77211025272826", judul = "Drake - Laugh Now Cry Later", speed = 0.43 },
		{ id = "120581465228223", judul = "Drake - Toosie Slide", speed = 0.43 },
		{ id = "115614588746720", judul = "DJ Khaled - No Brainer", speed = 0.43 },
		{ id = "79674329295247", judul = "DJ Snake - Let Me Love You", speed = 0.43 },
		{ id = "127224590374841", judul = "Drake - God's Plan", speed = 0.43 },
		{ id = "74357307957028", judul = "DJ Snake - Middle", speed = 0.43 },
		{ id = "130157502011227", judul = "DJ Khaled - Hold You Down", speed = 0.43 },
		{ id = "71918094359602", judul = "DJ Khaled - I'm the One ft. Justin Bieber", speed = 0.43 },
		{ id = "95899091546091", judul = "DJ Khaled - Wild Thoughts", speed = 0.43 },
		{ id = "125044154267503", judul = "Tinashe & Disco Lines - No Broke Boys", speed = 0.43 },
		{ id = "83178422549582", judul = "Dave - Raindance", speed = 0.43 },
		{ id = "106388448910275", judul = "Dawin - Dessert", speed = 0.43 },
		{ id = "128212396435358", judul = "Dawin - Jumpshot", speed = 0.43 },
		{ id = "89326276015497", judul = "Fejoint - Come Closer", speed = 0.43 },
		{ id = "127798308524907", judul = "Clean Bandit - Rockabye", speed = 0.43 },
		{ id = "132154851698530", judul = "CKay - Love Nwantiti Remix", speed = 0.43 },
		{ id = "128114409956730", judul = "Chris Brown - Loyal ft. Lil Wayne, Tyga", speed = 0.43 },
		{ id = "126868172992102", judul = "Chris Brown - No Guidance ft. Drake", speed = 0.43 },
		{ id = "124972575375303", judul = "Chris Brown - Under The Influence", speed = 0.43 },
		{ id = "79144721605016", judul = "Rap City -Chris Brown - Heat ft. Gunna", speed = 0.43 },
		{ id = "130208195959472", judul = "Chris Brown & Young Thug - City Girls", speed = 0.43 },
		{ id = "129117780585364", judul = "Lil Dicky - Freaky Friday ft. Chris Brown", speed = 0.43 },
		{ id = "96390169191847", judul = "Chris Brown - Angel Numbers Ten Toes", speed = 0.43 },
		{ id = "136990003292977", judul = "Chris Brown, Tyga - Ayo", speed = 0.43 },
		{ id = "113247081091338", judul = "Chase Atlantic - Consume", speed = 0.43 },
		{ id = "70840659941450", judul = "Chase Atlantic - HEAVEN AND BACK", speed = 0.43 },
		{ id = "95037703999837", judul = "Charlie Puth - Cheating on You", speed = 0.43 },
		{ id = "140639642725045", judul = "CENTRAL CEE - TRUTH IN THE LIES", speed = 0.43 },
		{ id = "108099326453620", judul = "Cash Cash - Hero", speed = 0.43 },
		{ id = "76202957623606", judul = "Bruno Mars - The Lazy Song", speed = 0.43 },
		{ id = "116457204192670", judul = "BTS (방탄소년단) '2.0'", speed = 0.43 },
		{ id = "78297798901557", judul = "Camila Cabello - Havana", speed = 0.43 },
		{ id = "80894670917995", judul = "Calvin Harris - Outside", speed = 0.43 },
		{ id = "73513045426835", judul = "Bruno Mars - Locked Out Of Heaven", speed = 0.43 },
		{ id = "128525247453077", judul = "Bruno Mars - 24K Magic", speed = 0.43 },
		{ id = "114024924190079", judul = "Bruno Mars - I Just Might", speed = 0.43 },
		{ id = "86064698828449", judul = "Bruno Mars - That’s What I Like", speed = 0.43 },
		{ id = "102773175740032", judul = "Ariana Grande - bloodline", speed = 0.43 },
		{ id = "83130725950744", judul = "Black Eyed Peas - Shake Ya Boom Boom", speed = 0.43 },
		{ id = "82505041889387", judul = "Ayo & Teo -Ayo & Teo - Rolex", speed = 0.43 },
		{ id = "73717730162947", judul = "Måneskin - Beggin'", speed = 0.43 },
		{ id = "97374379426875", judul = "Backstreet Boys - Shape Of My Heart", speed = 0.43 },
		{ id = "108922249110328", judul = "Naufal Syachreza, Jemsii - SUPER EKSIS", speed = 0.43 },
		{ id = "88487124893279", judul = "Ariana Grande ft. Nicki Minaj - Side To Side", speed = 0.43 },
		{ id = "113972830050639", judul = "Ariana Grande - thank u, next", speed = 0.43 },
		{ id = "102939254394354", judul = "Ariana Grande - supernatural", speed = 0.43 },
		{ id = "113496668690446", judul = "Ariana Grande - bye", speed = 0.43 },
		{ id = "79561138755538", judul = "ROSÉ & Bruno Mars - APT", speed = 0.43 },
		{ id = "104138822671256", judul = "Altégo - Give It to Me X Promiscuous", speed = 0.43 },
		{ id = "112388196710834", judul = "Krewella - Alive", speed = 0.43 },
		{ id = "100867168014080", judul = "Alesso, Tove Lo - Heroes", speed = 0.43 },
		{ id = "133218105824971", judul = "Akon - Be With You", speed = 0.43 },
		{ id = "73104245469261", judul = "Alan Walker - On My Way", speed = 0.43 },
		{ id = "120495997923892", judul = "Chase Atlantic - RICOCHET", speed = 0.43 },
		{ id = "119129478425402", judul = "Kendrick Lamar - Not Like Us", speed = 0.43 },
		{ id = "83837824669656", judul = "UMBRELLA x WHERE HAVE YOU BEEN", speed = 0.43 },
		{ id = "110471714361919", judul = "RVFV - MIRANDOTE", speed = 0.43 },
		{ id = "91084400010322", judul = "SIX SEVEN", speed = 0.43 },
		{ id = "83973761850763", judul = "Post Malone, Quavo - Congratulations", speed = 0.43 },
		{ id = "138409954267026", judul = "California Gurls X We Found Love", speed = 0.43 },
		{ id = "112128470432658", judul = "Central Cee - Let Go", speed = 0.43 },
		{ id = "87638828260975", judul = "Show Me Love X Take My Mind", speed = 0.43 },
		{ id = "95377868597301", judul = "Alma Zarza - Tutu", speed = 0.43 },
		{ id = "108101550419022", judul = "Flo Rida - Whistle", speed = 0.43 },
		{ id = "96028727083845", judul = "Michel Teló - Ai Se Eu Te Pego", speed = 0.43 },
		{ id = "137734554270632", judul = "The Chainsmokers - Closer", speed = 0.43 },
		{ id = "76335802965171", judul = "The Chainsmokers - Roses", speed = 0.43 },
		{ id = "106178087245804", judul = "Chris Brown - No One Else", speed = 0.43 },
		{ id = "90353469727354", judul = "UBUR UBUR IKAN LEL [DIGLO] EDIT", speed = 0.43 },
		{ id = "128073185583932", judul = "she goes by. (KayArchon Remix)", speed = 0.43 },
		{ id = "101929159095173", judul = "Gucci Mane - Wake Up in The Sky", speed = 0.43 },
		{ id = "104041710819986", judul = "Mamacita", speed = 0.43 },
		{ id = "134129218205267", judul = "Un Verano en Nueva York BASSLINE BOUNCE", speed = 0.43 },
		{ id = "82976388906585", judul = "Drake - One Dance", speed = 0.43 },
		{ id = "71336019940440", judul = "Teteg Ati - Asha ft Tiara Linggar", speed = 0.43 },
		{ id = "134149710529937", judul = "Mbak Billie", speed = 0.43 },
		{ id = "104073273528409", judul = "Taylor Swift - Enchanted", speed = 0.43 },
		{ id = "96539754983073", judul = "Tong Hua", speed = 0.43 },
		{ id = "77802265498600", judul = "Tulus - Teh Hijau koplo", speed = 0.43 },
		{ id = "124152370841970", judul = "Tek Palat - Tompel", speed = 0.43 },
		{ id = "125185772768594", judul = "Sean Paul, Dua Lipa -No Lie", speed = 0.43 },
		{ id = "85825104478025", judul = "MMG (My Mine Gueh)", speed = 0.43 },
		{ id = "82139749574208", judul = "Ricky Rich, ARAM Mafia -Habibi", speed = 0.43 },
		{ id = "93957709951312", judul = "Nemzzz -Evicted", speed = 0.43 },
		{ id = "114916270972294", judul = "Peterpan -Di Atas Normal", speed = 0.43 },
		{ id = "100744414590958", judul = "Hosier Lane 2016", speed = 0.43 },
		{ id = "71152991038195", judul = "KISSES BACK", speed = 0.43 },
		{ id = "88529078767550", judul = "Dua Lipa -Training Season", speed = 0.43 },
		{ id = "134381976618489", judul = "K3bi -Doa", speed = 0.43 },
		{ id = "88242298881361", judul = "Loading - Central Cee", speed = 0.43 },
		{ id = "104635868170967", judul = "Manda Fvnky -Kutukan Mantan", speed = 0.43 },
		{ id = "130021779886726", judul = "G-Eazy X Bebe Rexha - Me, Myself & I", speed = 0.43 },
		{ id = "116610458012434", judul = "where.t.at - she goes by", speed = 0.43 },
		{ id = "132539337524396", judul = "Vitinho Ferrari - Sou Favela", speed = 0.43 },
		{ id = "124536535197115", judul = "Rihanna - Work ft. Drake", speed = 0.43 },
		{ id = "81606729466477", judul = "Central Cee - Doja", speed = 0.43 },
		{ id = "90488719137315", judul = "David Guetta & Bebe Rexha - I'm Good", speed = 0.43 },
		{ id = "126664114772284", judul = "RABIG Emangnya Situ Siapa", speed = 0.43 },
		{ id = "101399416708162", judul = "ROSES - TRIUM NOCTIS, SHEILINE ZEINA", speed = 0.43 },
		{ id = "111103766140474", judul = "Kemal Palevi - Anjayyyyyy ft. YoungLex", speed = 0.43 },
		{ id = "80413083079906", judul = "Natti Natasha x Becky G - Ram Pam Pam", speed = 0.43 },
		{ id = "120238749329558", judul = "50 Cent - Baby By Me", speed = 0.43 },
		{ id = "72402313707716", judul = "Calvin Harris - 5 AM ft. Tinashe", speed = 0.43 },
		{ id = "109120785081796", judul = "Arizona Zervas - ROXANNE", speed = 0.43 },
		{ id = "101133558179718", judul = "Aya Nakamura - Copines", speed = 0.43 },
	},

	-- ["PLAYLIST 2"] = {},
	-- ["BREAKBEAT"] = {},
	-- ["THAILAND STYLE"] = {},
	-- ["FUNKOT STYLE"] = {},
}

-- ==============================================================================
-- 3. ALBUM COVER RESOLVER
-- ==============================================================================
function MusicModule:GetAlbumCover(albumName)
	if albumName and self.ALBUM_COVERS and self.ALBUM_COVERS[albumName] then
		return self.ALBUM_COVERS[albumName]
	end
	return self.ALBUM_COVERS["All Songs"] or "rbxassetid://100874885625675"
end

-- ==============================================================================
-- 4. DATABASE COMPILER & O(1) LOOKUP CACHE
-- Otomatis menyusun MusicDatabase flat array & index O(1) untuk performa server & client.
-- ==============================================================================
local MusicDatabase = {}
local MusicById     = {}

-- Helper pengurutan alfabetis A-Z berdasarkan judul lagu (case-insensitive)
local function sortSongsAlphabetically(list)
	if not list or #list <= 1 then return list end

	table.sort(list, function(a, b)
		local titleA = tostring((a and a.judul) or ""):lower():match("^%s*(.-)%s*$") or ""
		local titleB = tostring((b and b.judul) or ""):lower():match("^%s*(.-)%s*$") or ""

		-- Abaikan tanda baca/simbol pembuka agar urutan abjad A-Z tetap presisi
		local cleanA = titleA:match("^[%p%s]*(.-)$")
		local cleanB = titleB:match("^[%p%s]*(.-)$")
		if not cleanA or cleanA == "" then cleanA = titleA end
		if not cleanB or cleanB == "" then cleanB = titleB end

		if cleanA == cleanB then
			return tostring((a and a.id) or "") < tostring((b and b.id) or "")
		end
		return cleanA < cleanB
	end)

	return list
end

local function rebuildDatabase()
	table.clear(MusicDatabase)
	table.clear(MusicById)

	local playlistOrder = {
		"PLAYLIST 1",
		"PLAYLIST 2",
		"BREAKBEAT",
		"THAILAND STYLE",
		"FUNKOT STYLE",
	}

	local processed = {}
	local function processAlbum(albumName, list)
		if not list or processed[albumName] then return end
		processed[albumName] = true
		local cover = MusicModule:GetAlbumCover(albumName)

		-- Urutkan list playlist sumber secara alfabetis A-Z
		sortSongsAlphabetically(list)

		for _, item in ipairs(list) do
			local idStr = tostring(item.id)
			local song = {
				id            = idStr,
				judul         = tostring(item.judul),
				album         = albumName,
				sampul        = item.sampul or cover,
				Duration      = item.Duration,
				PlaybackSpeed = item.PlaybackSpeed or item.speed or item.playback or (albumName == "PLAYLIST 1" and 0.43) or 1.0,
				PitchOctave   = item.PitchOctave or item.pitch or 1.0,
			}
			table.insert(MusicDatabase, song)
			MusicById[idStr] = song
		end
	end

	for _, albumName in ipairs(playlistOrder) do
		processAlbum(albumName, MusicModule.PLAYLISTS[albumName])
	end

	for albumName, list in pairs(MusicModule.PLAYLISTS) do
		processAlbum(albumName, list)
	end

	-- Urutkan database global (All Songs) secara alfabetis A-Z
	sortSongsAlphabetically(MusicDatabase)
end

rebuildDatabase()

-- ==============================================================================
-- 5. PUBLIC API
-- ==============================================================================

-- Mengambil seluruh lagu di database
function MusicModule:GetAllMusic()
	return MusicDatabase
end

-- Mencari lagu berdasarkan SoundId secara instan O(1)
function MusicModule:GetMusicById(id)
	if not id then return nil end
	local idStr = tostring(id)
	return MusicById[idStr]
end

-- Menambahkan lagu baru secara dinamis via script (opsional)
function MusicModule:AddSong(albumName, songData)
	if not albumName or not songData or not songData.id then return false end
	if not self.PLAYLISTS[albumName] then
		self.PLAYLISTS[albumName] = {}
	end
	table.insert(self.PLAYLISTS[albumName], songData)
	rebuildDatabase()
	return true
end

-- Mengambil daftar album beserta jumlah lagu & cover
function MusicModule:GetAllAlbums(favoriteSongs)
	favoriteSongs = favoriteSongs or {}
	local albums = {}
	local albumCounts = {}

	for _, music in ipairs(MusicDatabase) do
		local albumName = music.album or "Unknown"
		albumCounts[albumName] = (albumCounts[albumName] or 0) + 1
	end

	-- "All Songs" album
	table.insert(albums, {
		name = "All Songs",
		songCount = #MusicDatabase,
		cover = self:GetAlbumCover("All Songs")
	})

	-- "My Favorites" album
	local favCount = 0
	for _, favId in ipairs(favoriteSongs) do
		if self:GetMusicById(favId) then
			favCount = favCount + 1
		end
	end
	if favCount > 0 then
		table.insert(albums, {
			name = "My Favorites",
			songCount = favCount,
			cover = self:GetAlbumCover("My Favorites")
		})
	end

	-- Urutan album yang rapi di menu
	local displayOrder = {
		"PLAYLIST 1",
		"PLAYLIST 2",
		"BREAKBEAT",
		"THAILAND STYLE",
		"FUNKOT STYLE",
	}

	local added = {}
	for _, albumName in ipairs(displayOrder) do
		if albumCounts[albumName] then
			table.insert(albums, {
				name = albumName,
				songCount = albumCounts[albumName],
				cover = self:GetAlbumCover(albumName)
			})
			added[albumName] = true
		end
	end

	for albumName, count in pairs(albumCounts) do
		if not added[albumName] then
			table.insert(albums, {
				name = albumName,
				songCount = count,
				cover = self:GetAlbumCover(albumName)
			})
		end
	end

	return albums
end

-- Mengambil lagu berdasarkan album (selalu terurut alfabetis A-Z)
function MusicModule:GetAlbumSongs(albumName, favoriteSongs)
	favoriteSongs = favoriteSongs or {}
	local songs = {}

	if albumName == "All Songs" then
		for _, music in ipairs(MusicDatabase) do
			table.insert(songs, music)
		end
	elseif albumName == "My Favorites" then
		for _, favId in ipairs(favoriteSongs) do
			local music = self:GetMusicById(favId)
			if music then
				table.insert(songs, music)
			end
		end
	else
		local targetAlbum = string.lower(tostring(albumName or ""))
		for _, music in ipairs(MusicDatabase) do
			if string.lower(tostring(music.album or "")) == targetAlbum then
				table.insert(songs, music)
			end
		end
	end

	return sortSongsAlphabetically(songs)
end

-- Pencarian lagu di dalam album
function MusicModule:SearchInAlbum(albumName, query, favoriteSongs)
	local songs = self:GetAlbumSongs(albumName, favoriteSongs)
	if not query or query == "" then
		return songs
	end

	local results = {}
	local lowerQuery = string.lower(query)

	for _, music in ipairs(songs) do
		local lowerTitle = string.lower(music.judul)
		if lowerTitle:find(lowerQuery, 1, true) then
			table.insert(results, music)
		end
	end

	return results
end

return MusicModule
