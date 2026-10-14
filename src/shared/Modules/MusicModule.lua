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
	["PLAYLIST 2"]     = "rbxassetid://114910483744172", -- DJ Global Effect Icon
	["BREAKBEAT"]      = "rbxassetid://106900580552131", -- Breakbeat Headphones Badge
	["EDM"]            = "rbxassetid://74637269436548", -- EDM Cover / DJ Global Effect Icon
	["AMAPIANO"]       = "rbxassetid://136994553919740",  -- Amapiano / Afrobeat Cover
	["DJ"]             = "rbxassetid://73561867265020",  -- DJ Cover
	["KOPLO & JAWA"]   = "rbxassetid://103698710073129",  -- Koplo & Jawa Cover
	-- ["THAILAND STYLE"] = "rbxassetid://92853116803097",  -- DJ / Thailand Style Cover
	-- ["FUNKOT STYLE"]   = "rbxassetid://99989680726270",  -- Party / Dance Icon
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
	},

	-- ==========================================================
	-- PLAYLIST 2 (102 Lagu - Split Seimbang & Lagu Baru)
	-- ==========================================================
	["PLAYLIST 2"] = {
		-- Lagu Baru
		{ id = "118329838572289", judul = "MOJANG PRIANGAN", speed = 0.43 },
		{ id = "134339619153625", judul = "ALWAYS LOVING YOU STADIUM BREAKBEAT", speed = 0.43 },
		{ id = "116834928520132", judul = "KAKA MAIN SALAH X GIVE IT TO ME X TERUNTUK MIA", speed = 0.43 },
		{ id = "121559079387058", judul = "DRIVE BKB", speed = 0.43 },
		{ id = "118386896815357", judul = "SAVE ME X YOU DON'T EVEN KNOW ME BKB", speed = 0.43 },
		{ id = "129701607361280", judul = "I NEED A DOCTOR X STILL THE SAME BKB", speed = 0.43 },
		{ id = "80445767674115", judul = "SET FIRE TO THE RAIN BKB", speed = 0.43 },
		{ id = "97968015009901", judul = "ORA URUS", speed = 0.43 },
		{ id = "126990865835117", judul = "PERFECT STRANGERS BKB (REMIX OnOffJD)", speed = 0.43 },
		{ id = "105030520465759", judul = "PERFECT STRANGERS BKB (Fikri Breaksynth)", speed = 0.43 },
		{ id = "123184799570958", judul = "HOLD ON X THAT SHOULD BE ME BKB", speed = 0.43 },
		{ id = "125072463728946", judul = "ONE TIME - JUSTIN BIEBER BKB", speed = 0.43 },
		{ id = "133808214667091", judul = "BEAUTY AND A BEAT BKB NEW", speed = 0.43 },
		{ id = "114581661335070", judul = "SAY NO BKB", speed = 0.43 },
		{ id = "83277433157629", judul = "ADÉLA - AIN'T IN LA", speed = 0.43 },
		{ id = "105431570014180", judul = "AKON - TROUBLEMAKER", speed = 0.43 },
		{ id = "84315286091849", judul = "WASAP MAMEN", speed = 0.43 },
		{ id = "91540095214641", judul = "DJ HEY IM LOCO X BOMAYE BOOTLEG", speed = 0.43 },
		{ id = "104636488680057", judul = "THAILAND REMIX - BOOK REMIX", speed = 0.43 },
		{ id = "127468903807724", judul = "CÉLINE DION - IMMORTALITY", speed = 0.43 },
		{ id = "115286452845235", judul = "AMAPIANO BODY PATA PATA X STECU STECU", speed = 0.43 },
		{ id = "77471591914076", judul = "DJ PACHANGA", speed = 0.43 },
		{ id = "83949314162857", judul = "Chris Brown - Loyal", speed = 0.43 },
		{ id = "85542641317115", judul = "X Remix - Nicky Jam x J Balvin x Ozuna x Maluma", speed = 0.43 },
		{ id = "115030341209435", judul = "Becky G, Natti Natasha - Sin Pijama", speed = 0.43 },
		{ id = "139420553280244", judul = "Redfoo - New Thang", speed = 0.43 },
		{ id = "113959859524529", judul = "LMFAO - Party Rock Anthem", speed = 0.43 },
		{ id = "122581282138639", judul = "SENAM GEMU FA MI RE", speed = 0.43 },

		-- Bagian Kedua dari PLAYLIST 1 agar Seimbang
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

		-- Tambahan Lagu PLAYLIST 2 (Digabung agar tidak menimpa 102 lagu di atas)
		{ id = "130506595568178", judul = "Love Me Not - Ravyn Lenae", speed = 0.43 },
		{ id = "123427427221176", judul = "Beretta (Brazilian Funk) - Cvplis", speed = 0.43 },
		{ id = "135679855800052", judul = "Bazovyy Minimum - SABI, MIA BOYKA", speed = 0.43 },
		{ id = "80205383720864", judul = "Beretta - Cvplis", speed = 0.43 },
		{ id = "77642846510503", judul = "Mode Pesawat - DJ Remix", speed = 0.43 },
		{ id = "122925523137883", judul = "Negoro Angin - Nayla Fardila", speed = 0.43 },
		{ id = "108328696428101", judul = "We Don't Talk Anymore - Charlie Puth", speed = 0.43 },
		{ id = "119501124155860", judul = "Cinderella - Mac Miller", speed = 0.43 },
		{ id = "116675794112254", judul = "Sakadung Sakading - Maman Fvndy", speed = 0.43 },
		{ id = "102292986307858", judul = "Anak Kampung - Maman Fvndy", speed = 0.43 },
		{ id = "90143484663142", judul = "Beautiful - Akon", speed = 0.43 },
		{ id = "74467001511185", judul = "Close To Me - Ellie Goulding", speed = 0.43 },
		{ id = "74026808327740", judul = "Love Me Not - Ravyn Lenae", speed = 0.43 },
		{ id = "126712688453518", judul = "Cindai - Siti Nurhaliza", speed = 0.43 },
		{ id = "130174372075973", judul = "Great Expectation - Sienna Spiro", speed = 0.43 },
		{ id = "94467246580644", judul = "Pure - Sienna Spiro", speed = 0.43 },
		{ id = "103017978960699", judul = "Ada Gajah Dibalik Batu - Wali", speed = 0.43 },
		{ id = "77893031596418", judul = "Rude - MAGIC!", speed = 0.43 },
		{ id = "71762935839203", judul = "Sure Thing - Miguel", speed = 0.43 },
		{ id = "70504775168449", judul = "100% Cintaku - Bagindas", speed = 0.43 },
		{ id = "95885769645894", judul = "100% Cintaku (JJ) - DJ Trexa", speed = 0.43 },
		{ id = "107377448017486", judul = "Cinderella - Mac Miller", speed = 0.43 },
		{ id = "80978865771393", judul = "Want U - Clara La San", speed = 0.43 },
		{ id = "126480303898868", judul = "Love - Keyshia Cole", speed = 0.43 },
		{ id = "107657269906241", judul = "Kita Lewati Berdua - Overnight", speed = 0.43 },
		{ id = "127024077517453", judul = "The One That Got Away - DNY", speed = 0.43 },
		{ id = "98484147147496", judul = "Party 4 You - IanMusick", speed = 0.43 },
		{ id = "88797604364320", judul = "We Wanna Party - Momski", speed = 0.43 },
		{ id = "100812418235009", judul = "Seberapa Pantas - Sheila On 7", speed = 0.43 },
		{ id = "85070762257482", judul = "Bila Kau Tak Disampingku - Sheila On 7", speed = 0.43 },
		{ id = "101998438510095", judul = "Film Favorit - Sheila On 7", speed = 0.43 },
		{ id = "80428298006815", judul = "Karna Ada Ko - DJ Remix", speed = 0.43 },
		{ id = "101376390912490", judul = "Jatuh Cinta Di Jalan", speed = 0.43 },
		{ id = "70882327880546", judul = "Last Christmas - Wham!", speed = 0.43 },
	},

	-- ==========================================================
	-- BREAKBEAT (115 Lagu)
	-- ==========================================================
	["BREAKBEAT"] = {
		{ id = "72668014512344", judul = "GOD IS A GIRL BKB", speed = 0.43 },
		{ id = "93322287577293", judul = "IN AND OUT OF LOVE BKB", speed = 0.43 },
		{ id = "136444019583919", judul = "DORA DORA", speed = 0.43 },
		{ id = "105730791288873", judul = "BABY", speed = 0.43 },
		{ id = "100807777397995", judul = "BRAND NEW DAY", speed = 0.43 },
		{ id = "103278431584301", judul = "CANT STOP LOVING YOU", speed = 0.43 },
		{ id = "116061203746723", judul = "CHICA LOCA", speed = 0.43 },
		{ id = "140208132372846", judul = "DRUNK TEXT", speed = 0.43 },
		{ id = "98482200940076", judul = "FATE OF OPHELIA", speed = 0.43 },
		{ id = "126169033734679", judul = "HOW DO YOU DO", speed = 0.43 },
		{ id = "87050589086839", judul = "IS IT LOVE IS IT TRUTH", speed = 0.43 },
		{ id = "72368373533153", judul = "SOUL ON THE RUN X NOW I SEE BKB", speed = 0.43 },
		{ id = "115100216029297", judul = "NOW I SEE", speed = 0.43 },
		{ id = "136400165228195", judul = "PURE LOVE", speed = 0.43 },
		{ id = "130965728893965", judul = "STARLIGHT X ONE X SUNSHINE LOVE", speed = 0.43 },
		{ id = "103816395103252", judul = "WAITING", speed = 0.43 },
		{ id = "105690337777946", judul = "WHERE DO WE BEGIN", speed = 0.43 },
		{ id = "134157119116398", judul = "ASTAGA BERCANDA BKB", speed = 0.43 },
		{ id = "133903828870818", judul = "SAY NO BKB", speed = 0.43 },
		{ id = "113098140708161", judul = "DO BAD WELL X BEAUTIFUL LIE BKB", speed = 0.43 },
		{ id = "77095812649529", judul = "JAMAICAN BAMBAM INDB", speed = 0.43 },
		{ id = "79222937532392", judul = "I WILL SURVIVE BKB", speed = 0.43 },
		{ id = "119096261649193", judul = "BAILANDO BKB", speed = 0.43 },
		{ id = "127844345146299", judul = "NO BROKE BOYS BKB", speed = 0.43 },
		{ id = "86925763653531", judul = "PLAT KT MIKA MIKA", speed = 0.43 },
		{ id = "92797788380019", judul = "DOUBLE TAKE V2", speed = 0.43 },
		{ id = "108756839084229", judul = "BOUNCE & PA BKB (AYOJP88 Edit)", speed = 0.43 },
		{ id = "119842062631724", judul = "DJ HOLA CHIQUITITA X DALINDA X DANZA KUDURO", speed = 0.43 },
		{ id = "102270499990905", judul = "BESO BESO AY MAMÁ", speed = 0.43 },
		{ id = "101667353468169", judul = "SET ME FREE BKB", speed = 0.43 },
		{ id = "97236201904430", judul = "ATLANTIS BKB", speed = 0.43 },
		{ id = "116414723855671", judul = "THIS I VOW BKB STADIUM", speed = 0.43 },
		{ id = "103009285377235", judul = "TIMELESS BKB", speed = 0.43 },
		{ id = "110429894666400", judul = "DON'T JINX IT BREAKBEAT", speed = 0.43 },
		{ id = "134332112117975", judul = "SWEET SCAR STADIUM BKB STADIUM", speed = 0.43 },
		{ id = "121417437703072", judul = "TITANIUM STADIUM BKB STADIUM", speed = 0.43 },
		{ id = "111705751757483", judul = "HEROES STADIUM BKB STADIUM", speed = 0.43 },
		{ id = "85534004817068", judul = "TILL IT HURTS STADIUM BKB STADIUM", speed = 0.43 },
		{ id = "125877830936359", judul = "IT'S MY LIFE STADIUM BKB STADIUM", speed = 0.43 },
		{ id = "99618416812308", judul = "A SKY FULL OF STARS STADIUM BKB STADIUM", speed = 0.43 },
		{ id = "93495259971545", judul = "MACARENA STADIUM BKB STADIUM", speed = 0.43 },
		{ id = "125390863723095", judul = "FALLS BKB STADIUM", speed = 0.43 },
		{ id = "119696882247768", judul = "MAGIC - RUDE BKB", speed = 0.43 },
		{ id = "100757549928302", judul = "MAGIC - RUDE BKB (Koplo Version)", speed = 0.43 },
		{ id = "89996444990512", judul = "MAGIC - RUDE BKB (Yoga BeatMap X OPET K)", speed = 0.43 },
		{ id = "132519595901154", judul = "ALL I ASK BKB (Nuel Ante Remix)", speed = 0.43 },
		{ id = "129207473620113", judul = "ALL I ASK BKB", speed = 0.43 },
		{ id = "128068123751225", judul = "ALL I NEED BKB", speed = 0.43 },
		{ id = "116723395878455", judul = "ALL OF ME BKB", speed = 0.43 },
		{ id = "103100774133951", judul = "ANGEL LOVE BKB", speed = 0.43 },
		{ id = "96007367323784", judul = "ANGEL LOVE X GOODBYE BKB", speed = 0.43 },
		{ id = "79324641892160", judul = "ATLANTIS X EN DEN DINO BKB", speed = 0.43 },
		{ id = "87659923451457", judul = "BE AS ONE BKB STADIUM", speed = 0.43 },
		{ id = "109706651754380", judul = "CHICA LOCA X PARADISE BKB", speed = 0.43 },
		{ id = "120090124104010", judul = "BEAUTY AND THE BEAT BKB", speed = 0.43 },
		{ id = "125372981910254", judul = "BLACKHOLE BKB", speed = 0.43 },
		{ id = "123088298612953", judul = "BODY MOVE BKBXINDB", speed = 0.43 },
		{ id = "83084405184887", judul = "BOUNCE & PA", speed = 0.43 },
		{ id = "126960912003865", judul = "BRAND NEW DAY BKB", speed = 0.43 },
		{ id = "76342548065160", judul = "BROKEN ANGEL BKB STADIUM", speed = 0.43 },
		{ id = "71065082305633", judul = "BROKEN ANGEL X ONE DAY X PURE LOVE BKB", speed = 0.43 },
		{ id = "85050809173781", judul = "CALLING BKB", speed = 0.43 },
		{ id = "136072519966561", judul = "CLOSE YOUR EYES BKB", speed = 0.43 },
		{ id = "135178640630673", judul = "CONCRETE ANGEL BKB", speed = 0.43 },
		{ id = "92876140543672", judul = "DAI DAI BKB", speed = 0.43 },
		{ id = "81221794247923", judul = "DANZA KONDURO BKB", speed = 0.43 },
		{ id = "131894089752644", judul = "DYNASTY BKB STADIUM", speed = 0.43 },
		{ id = "87629196419332", judul = "EASY ON ME BKB (Ronald 3D X Ewik)", speed = 0.43 },
		{ id = "72814074725434", judul = "EASY ON ME BKB", speed = 0.43 },
		{ id = "123145268291133", judul = "EMERGENCY BKB", speed = 0.43 },
		{ id = "108905183012324", judul = "FATE OF OPHELIA BKB", speed = 0.43 },
		{ id = "89957697072908", judul = "FEEL THIS MOMENT BKB", speed = 0.43 },
		{ id = "133388186123864", judul = "FEELS LIKE HOME BKB", speed = 0.43 },
		{ id = "114714380892967", judul = "FREAKS TIME BKB", speed = 0.43 },
		{ id = "81832013210774", judul = "GAM GAM BKB", speed = 0.43 },
		{ id = "86139569898973", judul = "HANDS BKB", speed = 0.43 },
		{ id = "129175416951984", judul = "HERO BKB", speed = 0.43 },
		{ id = "108233588653023", judul = "HEROES BKB", speed = 0.43 },
		{ id = "132930993763357", judul = "HOLY GRAIL BKB", speed = 0.43 },
		{ id = "74481558260346", judul = "IF I LOSE MYSELF BKB", speed = 0.43 },
		{ id = "135537343522170", judul = "IN AND OUT OF LOVE BKB STADIUM", speed = 0.43 },
		{ id = "98606918158792", judul = "IT WILL RAIN BKB", speed = 0.43 },
		{ id = "110180130303874", judul = "LOVE STORY BKB", speed = 0.43 },
		{ id = "81977510456584", judul = "LOVE X RUSSIAN ROULETTE BKB", speed = 0.43 },
		{ id = "77771814854788", judul = "LOVE YOU LIKE A LOVE SONG BKB", speed = 0.43 },
		{ id = "75015688760051", judul = "MEJIKUHIBINIU BKB", speed = 0.43 },
		{ id = "123414994702098", judul = "MIDDLE BKB", speed = 0.43 },
		{ id = "111698981638870", judul = "MILLION STARS BKB STADIUM", speed = 0.43 },
		{ id = "87045255562488", judul = "MINEFIELDS BKB", speed = 0.43 },
		{ id = "116508181741304", judul = "MIRACLES BKB", speed = 0.43 },
		{ id = "73824274353536", judul = "MODE PESAWAT BKB", speed = 0.43 },
		{ id = "76996276874948", judul = "MORENA BKB", speed = 0.43 },
		{ id = "85014302793938", judul = "MY REFLECTION BKB", speed = 0.43 },
		{ id = "122217351435659", judul = "NGAPAIN REPOT BKB", speed = 0.43 },
		{ id = "115246069993640", judul = "NU BKB STADIUM", speed = 0.43 },
		{ id = "91478553780161", judul = "NU X RAPTURE BKB", speed = 0.43 },
		{ id = "90983227945580", judul = "ONE TIME X WATCH ME BKB", speed = 0.43 },
		{ id = "70633651022450", judul = "PARADISE BKB STADIUM", speed = 0.43 },
		{ id = "124939479721494", judul = "PICA PICA BKB", speed = 0.43 },
		{ id = "117889742743326", judul = "PIKI PIKI BKB", speed = 0.43 },
		{ id = "108517360513229", judul = "PRICE TAG BKB", speed = 0.43 },
		{ id = "76152451955340", judul = "RISK IT ALL BKB", speed = 0.43 },
		{ id = "111558898352409", judul = "RUSSIAN R BKB", speed = 0.43 },
		{ id = "84974127803226", judul = "SHADOW BKB STADIUM", speed = 0.43 },
		{ id = "137473240135634", judul = "SHELTER BKB STADIUM", speed = 0.43 },
		{ id = "117951481275924", judul = "SO EASY BKB", speed = 0.43 },
		{ id = "100695352466928", judul = "SOMEONE LIKE YOU BKB", speed = 0.43 },
		{ id = "127516220644681", judul = "SOMEWHERE X MAN ON THE RUN BKB", speed = 0.43 },
		{ id = "93015350004883", judul = "STEPHANIE BKB", speed = 0.43 },
		{ id = "124918290513048", judul = "THE NIGHTS BKB", speed = 0.43 },
		{ id = "121786838939215", judul = "THIS I VOW BKB", speed = 0.43 },
		{ id = "133644310322264", judul = "WILD FLOWER BKB", speed = 0.43 },
		{ id = "90608237023142", judul = "YALLA HABIBI BKB", speed = 0.43 },
		{ id = "121300801857970", judul = "YOU DON'T EVEN KNOW BKB", speed = 0.43 },
		{ id = "139178389984286", judul = "ZUMI ZA BKB", speed = 0.43 },
	},

	-- ==========================================================
	-- EDM (48 Lagu)
	-- ==========================================================
	["EDM"] = {
		{ id = "136414098503960", judul = "Turn The Lights Off - KATO", speed = 0.43 },
		{ id = "129805097312205", judul = "Save My Love (Remix) - Kygo", speed = 0.43 },
		{ id = "130764002013912", judul = "Save My Love (BKB) - DJ Ocyn", speed = 0.43 },
		{ id = "139797314098495", judul = "Vois Sur Ton Chemin - Whisnu Santika", speed = 0.43 },
		{ id = "93891661443063", judul = "Prada - cassö", speed = 0.43 },
		{ id = "130763363249021", judul = "Just The Way You Are - Bruno Mars", speed = 0.43 },
		{ id = "125661681350845", judul = "The Days - NOTION", speed = 0.43 },
		{ id = "100892486762911", judul = "No Broke Boys - Disco Lines", speed = 0.43 },
		{ id = "91945771850328", judul = "Self Aware - LUM!X", speed = 0.43 },
		{ id = "96504817866224", judul = "Poker Face - Kratos", speed = 0.43 },
		{ id = "102209399261234", judul = "Bad Angel - Anyma", speed = 0.43 },
		{ id = "109952902461604", judul = "New Religion - Bebe Rexha", speed = 0.43 },
		{ id = "90063268583466", judul = "Show Me Love - WizTheMc", speed = 0.43 },
		{ id = "113651887622742", judul = "I'm Good (Blue) - David Guetta", speed = 0.43 },
		{ id = "75118262856834", judul = "Alibi - Ella Henderson", speed = 0.43 },
		{ id = "129800966112666", judul = "Move - Adam Port", speed = 0.43 },
		{ id = "105030890443325", judul = "Wait So Long - Swedish House Mafia", speed = 0.43 },
		{ id = "83160026470343", judul = "Just The Way You Are - Milky", speed = 0.43 },
		{ id = "99124181433415", judul = "All That Really Matters - ILLENIUM", speed = 0.43 },
		{ id = "95416353762295", judul = "In My Mind - Dynoro", speed = 0.43 },
		{ id = "79651947189177", judul = "Give It To Me - Matt Sassari", speed = 0.43 },
		{ id = "117759544571900", judul = "I Don't Wanna Wait - David Guetta", speed = 0.43 },
		{ id = "98908562456525", judul = "Chasing Cars - Chris Burke", speed = 0.43 },
		{ id = "101828717497997", judul = "Mockingbird - Tiësto", speed = 0.43 },
		{ id = "117106156444708", judul = "All The Things She Said - Robin Schulz", speed = 0.43 },
		{ id = "92867597617663", judul = "It Feels So Good - Matt Sassari", speed = 0.43 },
		{ id = "95725021983254", judul = "Borderline - Ely Oaks", speed = 0.43 },
		{ id = "138295496798170", judul = "Whatever - Kygo", speed = 0.43 },
		{ id = "80973432724227", judul = "Somebody - FISHER", speed = 0.43 },
		{ id = "94303025179679", judul = "I Adore You - HUGEL", speed = 0.43 },
		{ id = "98693030636563", judul = "10:35 - Tiësto", speed = 0.43 },
		{ id = "127878087642284", judul = "Like A G6 - Timmy Trumpet", speed = 0.43 },
		{ id = "81344782025358", judul = "Flashback - Cartoon", speed = 0.43 },
		{ id = "112896063682687", judul = "Prada (V2) - cassö", speed = 0.43 },
		{ id = "84479037935504", judul = "Dancin - Aaron Smith", speed = 0.43 },
		{ id = "111259660916464", judul = "Baby Don't Hurt Me - David Guetta", speed = 0.43 },
		{ id = "77059290871399", judul = "Overdrive - Ofenbach", speed = 0.43 },
		{ id = "140127420643215", judul = "I Like The Way You Kiss Me - Bombs Away", speed = 0.43 },
		{ id = "131221116202749", judul = "Overdrive (V2) - Ofenbach", speed = 0.43 },
		{ id = "71786159990263", judul = "Thunder - Gabry Ponte", speed = 0.43 },
		{ id = "106082306280509", judul = "Deep Down - Alok", speed = 0.43 },
		{ id = "134740224196571", judul = "All Around The World - R3HAB", speed = 0.43 },
		{ id = "114899389121162", judul = "Rasputin - Majestic", speed = 0.43 },
		{ id = "84496481102587", judul = "Say My Name - Morgan Seatree", speed = 0.43 },
		{ id = "105136517909309", judul = "Summer - Calvin Harris", speed = 0.43 },
		{ id = "138031021583203", judul = "Stereo Love - Edward Maya", speed = 0.43 },
		{ id = "85655212466441", judul = "Better Off - Alan Walker", speed = 0.43 },
		{ id = "120524521249674", judul = "Makeba - Jain", speed = 0.43 },
	},

	-- ==========================================================
	-- AMAPIANO (103 Lagu)
	-- ==========================================================
	["AMAPIANO"] = {
		{ id = "95448356878813", judul = "Pilé - Mauvais Djo", speed = 0.43 },
		{ id = "87980444422764", judul = "Fire Fire - Unknown", speed = 0.43 },
		{ id = "134166895273775", judul = "Toca Toca - Fly Project", speed = 0.43 },
		{ id = "83517034309560", judul = "Yamore X Move - Jana Nova", speed = 0.43 },
		{ id = "127958033558793", judul = "Yamore - MoBlack, Salif Keita", speed = 0.43 },	
		{ id = "137243165877284", judul = "Monalisa - Lojay, Sarz, Chris Brown", speed = 0.43 },
		{ id = "132871010977401", judul = "Bloody Samaritan - Ayra Starr", speed = 0.43 },
		{ id = "104680926652257", judul = "Paris - King Promise", speed = 0.43 },
		{ id = "93886422155561", judul = "Ama Hem Hem - Unknown", speed = 0.43 },
		{ id = "80799957901391", judul = "People x Calm Down - Dippie", speed = 0.43 },
		{ id = "127087962481130", judul = "Under The Influence (Remix) - Chris Brown", speed = 0.43 },
		{ id = "125203011911974", judul = "Greedy (Amapiano) - Tate McRae", speed = 0.43 },
		{ id = "134955913384726", judul = "Kiss It Better (Amapiano) - Rihanna", speed = 0.43 },
		{ id = "118979631300257", judul = "Sial (Remix V1) - Mahalini", speed = 0.43 },
		{ id = "87867735037020", judul = "Asmalibrasi (Amapiano) - Soegi Bornean", speed = 0.43 },
		{ id = "90063559875312", judul = "Aku Masih Memikirkanmu - Miciko", speed = 0.43 },
		{ id = "119285086769598", judul = "Firasat - Raisa", speed = 0.43 },
		{ id = "72672096897734", judul = "Bertaut 2.0 (V1) - Nadin Amizah", speed = 0.43 },
		{ id = "82268572962297", judul = "Apa Mungkin (V1) - Bernadya", speed = 0.43 },
		{ id = "138037578864349", judul = "Starboy (Amapiano) - The Weeknd", speed = 0.43 },
		{ id = "98583089879282", judul = "Na Na Na - Julius Aji ft. Judo", speed = 0.43 },
		{ id = "70790607075902", judul = "Love Me (Edit) - Azhariel", speed = 0.43 },
		{ id = "125674969681274", judul = "The Shade (Amapiano) - Rex Orange County", speed = 0.43 },
		{ id = "70469844122899", judul = "Anything You Want (Amapiano) - Reality Club", speed = 0.43 },
		{ id = "105761383367059", judul = "Terminator (Afro Baile) - King Promise", speed = 0.43 },
		{ id = "87511083654914", judul = "Habits (Stay High) - Tove Lo", speed = 0.43 },
		{ id = "92470354521101", judul = "Die For You (BOYDROOTS) - The Weeknd", speed = 0.43 },
		{ id = "87570389662657", judul = "Terminator (Amapiano) - King Promise", speed = 0.43 },
		{ id = "88953038984266", judul = "Cupid (Amapiano) - FIFTY FIFTY", speed = 0.43 },
		{ id = "86843347582766", judul = "Closer (Amapiano) - The Chainsmokers", speed = 0.43 },
		{ id = "106893431727607", judul = "Baby (Amapiano) - Justin Bieber", speed = 0.43 },
		{ id = "115934833710885", judul = "Payphone - Maroon 5", speed = 0.43 },
		{ id = "124816814137562", judul = "Love Story (Amapiano) - 1. Greg", speed = 0.43 },
		{ id = "93304484118980", judul = "Berharap Tak Berpisah (Amapiano) - Reza Artamevia", speed = 0.43 },
		{ id = "133460342025775", judul = "Kill Bill (Edit) - SZA", speed = 0.43 },
		{ id = "100930588607471", judul = "Simmer X Collide - Justine Skye", speed = 0.43 },
		{ id = "137264813424724", judul = "L.O.V.E (Edit V1) - Kendrick Lamar", speed = 0.43 },
		{ id = "88744929865553", judul = "L.O.V.E (Edit V2) - Kendrick Lamar", speed = 0.43 },
		{ id = "137574851460189", judul = "Holy (Amapiano) - Justin Bieber", speed = 0.43 },
		{ id = "107706546041894", judul = "People (Amapiano) - Libianca", speed = 0.43 },
		{ id = "104756233579286", judul = "Shirt (Amapiano) - SZA", speed = 0.43 },
		{ id = "111179929332185", judul = "High School In Jakarta (Amapiano) - NIKI", speed = 0.43 },
		{ id = "107750269055391", judul = "Love Song (Amapiano) - Kaash Paige", speed = 0.43 },
		{ id = "73841594828533", judul = "FE!N (Amapiano) - Travis Scott", speed = 0.43 },
		{ id = "107419206605221", judul = "The Boy Is Mine (Amapiano) - Ariana Grande", speed = 0.43 },
		{ id = "116958143960359", judul = "One Dance (Amapiano) - Drake", speed = 0.43 },
		{ id = "109389935065859", judul = "Water (Amapiano Remix) - Tyla", speed = 0.43 },
		{ id = "100616134674463", judul = "Sesaat Kau Hadir (Afrobeat) - Gery Gany", speed = 0.43 },
		{ id = "114085938827619", judul = "Sialan (Afrobeat) - Juicy Luicy", speed = 0.43 },
		{ id = "121611815374773", judul = "Rayuan Perempuan Gila - Nadin Amizah", speed = 0.43 },
		{ id = "92882523161212", judul = "Sio Nona - Naken & Batikboy", speed = 0.43 },
		{ id = "91938870234895", judul = "Don't Stop The Music (Amapiano) - Rihanna", speed = 0.43 },
		{ id = "74522701762287", judul = "What It Is Riddim - Marco Pedro", speed = 0.43 },
		{ id = "139359453968807", judul = "Maria Maria (Amapiano) - Santana", speed = 0.43 },
		{ id = "134137334873569", judul = "Just The Way You Are (Blend) - Bruno Mars", speed = 0.43 },
		{ id = "130165531329072", judul = "Stereo Love (Amapiano) - Edward Maya", speed = 0.43 },
		{ id = "114738134955522", judul = "No Idea (Amapiano) - Don Toliver", speed = 0.43 },
		{ id = "97151209586468", judul = "2 Bulan Madu - Bad Influence", speed = 0.43 },
		{ id = "97278823739625", judul = "Rude Boy (Afrobeats) - Rihanna", speed = 0.43 },
		{ id = "137155870474311", judul = "We Can't Be Friends - Ariana Grande", speed = 0.43 },
		{ id = "105906016182583", judul = "Cintaku (Edit) - Chrisye", speed = 0.43 },
		{ id = "106712624222223", judul = "Tattoo (Amapiano) - Loreen", speed = 0.43 },
		{ id = "97944482824774", judul = "Die With A Smile (Amapiano) - Bruno Mars, Lady Gaga", speed = 0.43 },
		{ id = "128797732915885", judul = "One Of The Girls - The Weeknd", speed = 0.43 },
		{ id = "110581042439336", judul = "Midsummer Madness - 88rising", speed = 0.43 },
		{ id = "107579110698540", judul = "Escapism - RAYE", speed = 0.43 },
		{ id = "72985659813429", judul = "Nasty (Amapiano) - Tinashe", speed = 0.43 },
		{ id = "99580768889575", judul = "Looking For Bae - Solumboii", speed = 0.43 },
		{ id = "83125609428074", judul = "Madan (Amapiano) - Salif Keita", speed = 0.43 },
		{ id = "117620511444719", judul = "Birds Of A Feather - Billie Eilish", speed = 0.43 },
		{ id = "71282592271770", judul = "Angel Numbers (Amapiano) - Chris Brown", speed = 0.43 },
		{ id = "137194362244147", judul = "Inikah Cinta - Dancefloor Project ft. Dira", speed = 0.43 },
		{ id = "104352562594208", judul = "Garam & Madu (Amapiano) - Tenxi, Naykilla", speed = 0.43 },
		{ id = "91923842497658", judul = "Kiss Me More (Amapiano) - Doja Cat", speed = 0.43 },
		{ id = "78878350416796", judul = "Love You Like A Love Song (Amapiano) - Selena Gomez", speed = 0.43 },
		{ id = "99016552429520", judul = "Active Role Modelz - Decemberkid", speed = 0.43 },
		{ id = "95093692452639", judul = "Saturn (Remix) - SZA", speed = 0.43 },
		{ id = "84321129011890", judul = "You Know How We Do It - Ice Cube", speed = 0.43 },
		{ id = "132763989492225", judul = "Karna Su Sayang (Amapiaplo) - Near", speed = 0.43 },
		{ id = "81915569874989", judul = "You'll Be In My Heart (Koplo) - DJ", speed = 0.43 },
		{ id = "134381427297804", judul = "Tega (Amapiano) - Tiara Andini", speed = 0.43 },
		{ id = "88378450931644", judul = "Sempurna - DiRGGA", speed = 0.43 },
		{ id = "125638127346619", judul = "Apa Mungkin (V2) - Bernadya", speed = 0.43 },
		{ id = "95458992760934", judul = "Bertaut 2.0 (V2) - Nadin Amizah", speed = 0.43 },
		{ id = "103061507850272", judul = "I Just Couldn’t Save You Tonight - Ardhito Pramono", speed = 0.43 },
		{ id = "93560031833151", judul = "Untungnya, Hidup Harus Tetap Berjalan - Bernadya", speed = 0.43 },
		{ id = "121029031956941", judul = "Secukupnya - Hindia", speed = 0.43 },
		{ id = "103055006508446", judul = "Kala Cinta Menggoda - Chrisye", speed = 0.43 },
		{ id = "100802877834946", judul = "Satu Satu - Idgitaf", speed = 0.43 },
		{ id = "105752191944050", judul = "Sial (Remix V2) - Mahalini", speed = 0.43 },
		{ id = "108247959647408", judul = "Rumah Ke Rumah - Hindia", speed = 0.43 },
		{ id = "72101995484473", judul = "Cincin (DnB) - Hindia", speed = 0.43 },
		{ id = "76121588046769", judul = "Gala Bunga Matahari (Amapiano) - Sal Priadi", speed = 0.43 },
		{ id = "140482741520790", judul = "Terlintas (Amapiano) - Bernadya", speed = 0.43 },
		{ id = "89988968100438", judul = "HAHAHA - Juicy Luicy", speed = 0.43 },
		{ id = "74496413227383", judul = "Kata Mereka Ini Berlebihan (DnB) - Bernadya", speed = 0.43 },
		{ id = "82924520496621", judul = "Bukan Orangnya - Juicy Luicy", speed = 0.43 },
		{ id = "109611035694782", judul = "Lampu Kuning - Juicy Luicy", speed = 0.43 },
		{ id = "112255712643078", judul = "Terlintas (Edit) - Bernadya", speed = 0.43 },
		{ id = "111850113533465", judul = "Lupa Nama Ingat Rasa (Amapiano) - OKAAY", speed = 0.43 },
	},

	-- ==========================================================
	-- DJ (2 Lagu)
	-- ==========================================================
	["DJ"] = {
		{ id = "132376300924608", judul = "My Mine Gue - DJ Remix", speed = 0.43 },
		{ id = "110762245924608", judul = "Apa Artinya Cinta - DJ Remix", speed = 0.43 },
	},

	-- ==========================================================
	-- KOPLO & JAWA (32 Lagu)
	-- ==========================================================
	["KOPLO & JAWA"] = {
		{ id = "99566872218628", judul = "Sayang 2 - Nella Kharisma", speed = 0.43 },
		{ id = "98786527040927", judul = "Mangku Purel - Om Adella", speed = 0.43 },
		{ id = "112639032717799", judul = "Tia Monika - Ajeng Febria", speed = 0.43 },
		{ id = "128271021406619", judul = "Old Town Road (Koplo) - Lil Nas X", speed = 0.43 },
		{ id = "123663042291910", judul = "Ekspektasi (Koplo) - Ocan Siagian, Okin", speed = 0.43 },
		{ id = "125903227203217", judul = "If You Know That I'm Lonely (Koplo) - FUR", speed = 0.43 },
		{ id = "80063215030137", judul = "Minimix Diva - Koplo", speed = 0.43 },
		{ id = "100274840903644", judul = "Celengan Rindu (Koplo) - Fiersa Besari", speed = 0.43 },
		{ id = "96639116055246", judul = "I Heart You (Koplo) - SM*SH", speed = 0.43 },
		{ id = "111303573269899", judul = "Tetap Dalam Jiwa (Koplo) - Isyana Sarasvati", speed = 0.43 },
		{ id = "89800637222076", judul = "Takut (Koplo) - Idgitaf", speed = 0.43 },
		{ id = "126084076919917", judul = "Rude (Koplo) - MAGIC!", speed = 0.43 },
		{ id = "128540349913727", judul = "Cinta Luar Biasa (Koplo) - Andmesh", speed = 0.43 },
		{ id = "115173773208704", judul = "Yang Terdalam (Koplo) - NOAH", speed = 0.43 },
		{ id = "81367577253503", judul = "Rasa Ini (Koplo) - Vierra", speed = 0.43 },
		{ id = "115425010779675", judul = "Angel Baby (Koplo) - Troye Sivan", speed = 0.43 },
		{ id = "128255835289465", judul = "Fortune Cookie (Koplo) - JKT48", speed = 0.43 },
		{ id = "113648470349164", judul = "Perfect (Koplo) - Simple Plan", speed = 0.43 },
		{ id = "116834651447740", judul = "Ketahuan (Koplo) - Matta Band", speed = 0.43 },
		{ id = "103211279291469", judul = "Come Inside of My Heart (Koplo) - IVOS", speed = 0.43 },
		{ id = "86247479779070", judul = "Play Date (Koplo) - Melanie Martinez", speed = 0.43 },
		{ id = "81364234928605", judul = "Berita Kehilangan (Koplo) - .Feast", speed = 0.43 },
		{ id = "88104108028973", judul = "Ku Tak Bisa (Koplo) - Slank", speed = 0.43 },
		{ id = "115900927111580", judul = "Evaluasi (Koplo) - Hindia", speed = 0.43 },
		{ id = "124453838321664", judul = "Benci Untuk Mencinta (Koplo) - Naif", speed = 0.43 },
		{ id = "129045916882745", judul = "Duka (Koplo) - Last Child", speed = 0.43 },
		{ id = "71345813449570", judul = "Titeni Lan Enteni (Koplo) - Ajeng Febria", speed = 0.43 },
		{ id = "123478835282099", judul = "Suara (Koplo) - Ajeng Febria", speed = 0.43 },
		{ id = "102898499397594", judul = "Kenangan Manis (Koplo) - Pamungkas", speed = 0.43 },
		{ id = "130738710420450", judul = "Terlatih Patah Hati (Koplo) - The Rain", speed = 0.43 },
		{ id = "108160132938537", judul = "December (Koplo) - Neck Deep", speed = 0.43 },
		{ id = "95573189869248", judul = "Jadikan Aku Yang Kedua (Koplo) - Astrid", speed = 0.43 },
	},

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
		"EDM",
		"AMAPIANO",
		"DJ",
		"KOPLO & JAWA",
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
			local idStr = tostring(item.id):match("%d+") or tostring(item.id)
			local song = {
				id            = idStr,
				judul         = tostring(item.judul),
				album         = albumName,
				sampul        = item.sampul or cover,
				Duration      = item.Duration,
				PlaybackSpeed = item.PlaybackSpeed or item.speed or item.playback or ((albumName == "PLAYLIST 1" or albumName == "PLAYLIST 2" or albumName == "BREAKBEAT" or albumName == "EDM" or albumName == "AMAPIANO" or albumName == "DJ" or albumName == "KOPLO & JAWA") and 0.43) or 1.0,
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
		"EDM",
		"AMAPIANO",
		"DJ",
		"KOPLO & JAWA",
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
