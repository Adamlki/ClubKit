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
	["THAILAND STYLE"] = "rbxassetid://92853116803097",       -- DJ / Thailand Style Cover
	["BREAKBEAT"]      = "rbxassetid://106900580552131",      -- Breakbeat Headphones Badge
	["FUNKOT STYLE"]   = "rbxassetid://99989680726270", -- Party / Dance Icon
	["PLAYLIST 1"]     = "rbxassetid://75519739809680", -- Music Note Icon
	["PLAYLIST 2"]     = "rbxassetid://114910483744172",  -- DJ Global Effect Icon
}

-- ==============================================================================
-- 2. PLAYLIST DATABASE
-- Semua lagu dikelompokkan per playlist agar rapi dan mudah dicari/diedit.
-- ==============================================================================
MusicModule.PLAYLISTS = {
	-- ==========================================================
	-- PLAYLIST 1 (165 Lagu)
	-- ==========================================================
	["PLAYLIST 1"] = {
		{ id = "115176297102556", judul = "PLAY – ALAN WALKER, K-391, TUNGEVAAG, MANGOO", speed = 0.43 },
		{ id = "80645766074424", judul = "LANY - You", speed = 0.7, pitch = 1.1 },
		{ id = "81257869135562", judul = "LANY -", speed = 0.7, pitch = 1.1 },
		{ id = "125816766946068", judul = "LANY - 13", speed = 0.7, pitch = 1.1 },
		{ id = "85428778844636", judul = "LANY - Super Far", speed = 0.7, pitch = 1.1 },
		{ id = "114204415546617", judul = "LANY - XXL", speed = 0.7, pitch = 1.1 },
		{ id = "75331949790916", judul = "LANY - Thru These Tears", speed = 0.7, pitch = 1.1 },
		{ id = "108268996390872", judul = "LANY - anything 4 u", speed = 0.7, pitch = 1.1 },
		{ id = "91656074831192", judul = "LANY - Thick And Thin", speed = 0.7, pitch = 1.1 },
		{ id = "110595139107215", judul = "The Weeknd - Blinding Lights", speed = 0.7, pitch = 1.1 },
		{ id = "90343504797110", judul = "The Weeknd - Save Your Tears", speed = 0.7, pitch = 1.1 },
		{ id = "79527978829243", judul = "The Weeknd - Hardest To Love", speed = 0.7, pitch = 1.1 },
		{ id = "88854879737198", judul = "The Weeknd - Moth To A Flame", speed = 0.7, pitch = 1.1 },
		{ id = "103253348115248", judul = "DJ Obh Combi Sachet" },
		{ id = "130297969168941", judul = "8 LETTERS – WHY DON", speed = 0.43 },
		{ id = "135526164745515", judul = "A Little Piece of Heaven - Avenged Sevenfold", speed = 0.43 },
		{ id = "135836231614223", judul = "A SKY FULL OF STARS - COLDPLAY", speed = 0.43 },
		{ id = "106624023362146", judul = "A THOUSAND YEARS - CHIRSTINA PERRI", speed = 0.43 },
		{ id = "118707946823603", judul = "ABOUT YOU X MULTO X BACK TO FRIENDS X PAYPHONE X WHERE WE ARE – MASHUP", speed = 0.43 },
		{ id = "86710490431507", judul = "ALAN WALKER, SABRINA CARPENTER, FARRUKO - ON MY WAY", speed = 0.43 },
		{ id = "114867023056058", judul = "ALL OF ME REMIX – JOHN LEGEND", speed = 0.43 },
		{ id = "75155361233643", judul = "MARSHMALLOW ALONE", speed = 0.43 },
		{ id = "82412473170633", judul = "ANGEL BABY – TROYE SIVAN", speed = 0.43 },
		{ id = "120201147209026", judul = "ANGELS LIKE YOU – MILEY CYRUS", speed = 0.43 },
		{ id = "88385976833537", judul = "ANIMALS - MAROON 5", speed = 0.43 },
		{ id = "80950769201112", judul = "ANIMALS - MARTIN GARIX", speed = 0.43 },
		{ id = "117876919570667", judul = "APT - ROSE X BRUNO MARS", speed = 0.43 },
		{ id = "112129515270393", judul = "ARIANA GRANDE - WE CAN", speed = 0.43 },
		{ id = "76481523653289", judul = "BACK TO FRIENDS", speed = 0.43 },
		{ id = "76163143897061", judul = "BAD ROMANCE – LADY GAGA", speed = 0.43 },
		{ id = "134081121981319", judul = "BE KIND WITH HALSEY", speed = 0.43 },
		{ id = "108562268357287", judul = "BE WITH YOU - AKON", speed = 0.43 },
		{ id = "75772290043987", judul = "BEAUTIFUL THINGS – BENSON BOONE", speed = 0.43 },
		{ id = "110039425060700", judul = "BEAUTIFUL – AKON", speed = 0.43 },
		{ id = "115618759275696", judul = "BILLIE EILISH, KHALID - LOVELY", speed = 0.43 },
		{ id = "104767488760702", judul = "BIRDS OF A FEATHER – BILLIE EILISH", speed = 0.43 },
		{ id = "111364073728189", judul = "BLACK FRIDAY (PRETTY LIKE THE SUN) – TOM ODELL", speed = 0.43 },
		{ id = "75397349278251", judul = "BOO", speed = 0.43 },
		{ id = "103574160857676", judul = "BREAKING ME – TOPIC, A7S", speed = 0.43 },
		{ id = "100419866459447", judul = "BROKEN ANGEL – ARASH FT. HELENA", speed = 0.43 },
		{ id = "71354152693034", judul = "CALL ME MAYBE – CARLY RAE JEPSEN", speed = 0.43 },
		{ id = "76710762392097", judul = "CALM DOWN – REMA & SELENA GOMEZ", speed = 0.43 },
		{ id = "113103219499546", judul = "CASH CASH, CHRISTINA PERRI - HERO", speed = 0.43 },
		{ id = "136243393861624", judul = "CHEERLEADER - FELIX JAEHN REMIX", speed = 0.43 },
		{ id = "78868972793897", judul = "CIRCLES – POST MALONE", speed = 0.43 },
		{ id = "105685615777196", judul = "CLARITY (FEAT. FOXES) - TIËSTO REMIX", speed = 0.43 },
		{ id = "124490599120948", judul = "COLD HEART REMIX – ELTON JOHN & DUA LIPA", speed = 0.43 },
		{ id = "132580829371558", judul = "COMETHRU – JEREMY ZUCKER", speed = 0.43 },
		{ id = "77191434117702", judul = "DANCE MONKEY – TONES AND I", speed = 0.43 },
		{ id = "97295641373432", judul = "DANCIN (KRONO REMIX) – AARON SMITH", speed = 0.43 },
		{ id = "111932673797078", judul = "DEAR GOD - OVENGED SEVENFOLD", speed = 0.43 },
		{ id = "123522108128356", judul = "DIE ON THIS HILL", speed = 0.43 },
		{ id = "108347186300519", judul = "DISCO LINES, TINASHE - NO BROKE BOYS", speed = 0.43 },
		{ id = "125515758303190", judul = "DON’T WAKE ME UP – CHRIS BROWN", speed = 0.43 },
		{ id = "116008232879857", judul = "DON", speed = 0.43 },
		{ id = "104897004079874", judul = "ECHOS OF YOU", speed = 0.43 },
		{ id = "81936058100631", judul = "ELECTRIC PULSE", speed = 0.43 },
		{ id = "97163339936875", judul = "END OF BEGINNING – DJO", speed = 0.43 },
		{ id = "130052617394144", judul = "FADED X ON MY WAY – ALAN WALKER", speed = 0.43 },
		{ id = "113331925685981", judul = "FLOWERS – MILEY CYRUS", speed = 0.43 },
		{ id = "129532965484353", judul = "FOLDED", speed = 0.43 },
		{ id = "136386314734452", judul = "GABRIELA", speed = 0.43 },
		{ id = "110408895359055", judul = "GIVE ME PROMISCUOUS", speed = 0.43 },
		{ id = "109784356096479", judul = "GOOD FOR YOU X ONE OF THE GIRLS – MASHUP", speed = 0.43 },
		{ id = "125908891850336", judul = "GOT 2 LUV U (FEAT. ALEXIS JORDAN)", speed = 0.43 },
		{ id = "136468126776022", judul = "GRENADE – BRUNO MARS", speed = 0.43 },
		{ id = "86310599989139", judul = "HAVANA (FEAT. YOUNG THUG)", speed = 0.43 },
		{ id = "108289817034775", judul = "HEART ATTACK – DEMI LOVATO", speed = 0.43 },
		{ id = "98363905347954", judul = "HEAVEN (FEAT. VERONICA)", speed = 0.43 },
		{ id = "123704675912072", judul = "HERE WITH ME", speed = 0.43 },
		{ id = "113787130702257", judul = "HEY DADDY – USHER", speed = 0.43 },
		{ id = "96449076197214", judul = "HOW TO LOVE", speed = 0.43 },
		{ id = "134205820435230", judul = "I ADORE YOU – HUGEL, TOPIC, ARASH FT. DAECOLM", speed = 0.43 },
		{ id = "92766256407674", judul = "I LOVE YOU 3000 – STEPHANIE POETRI", speed = 0.43 },
		{ id = "120744720669681", judul = "I LOVE YOU BABY", speed = 0.43 },
		{ id = "140259186765615", judul = "I", speed = 0.43 },
		{ id = "137968836209429", judul = "IT WILL RAIN – BRUNO MARS", speed = 0.43 },
		{ id = "128038120486261", judul = "JUDAS – LADY GAGA", speed = 0.43 },
		{ id = "138701140784343", judul = "JJUST THE WAY YOU ARE – BRUNO MARS", speed = 0.43 },
		{ id = "106909634491777", judul = "KAVKAZ", speed = 0.43 },
		{ id = "82850087585121", judul = "KING - OLLY ALEXANDER", speed = 0.43 },
		{ id = "126820480532864", judul = "KREEPEEK - PLAYBOY CAPTIKUS", speed = 0.43 },
		{ id = "81179715579017", judul = "LA LA LA - SAM SMITH", speed = 0.43 },
		{ id = "72872586126510", judul = "LADY GAGA, BRUNO MARS - DIE WITH A SMILE", speed = 0.43 },
		{ id = "105356784057959", judul = "LET ME GO", speed = 0.43 },
		{ id = "105356784057959", judul = "LET ME LOVE YOU", speed = 0.43 },
		{ id = "124273394563221", judul = "LIKE A G6", speed = 0.43 },
		{ id = "127952719429116", judul = "LOCKED OUT OF HEAVEN – BRUNO MARS", speed = 0.43 },
		{ id = "111730125544993", judul = "LOCO LOCO", speed = 0.43 },
		{ id = "104494409838301", judul = "LONELY TOGETHER (FEAT. RITA ORA)", speed = 0.43 },
		{ id = "107132859576786", judul = "LOWKEY – NIKI", speed = 0.43 },
		{ id = "91094865742672", judul = "MIDNIGHT DRIFT", speed = 0.43 },
		{ id = "85557439758541", judul = "MINEFIELDS – FAOUZIA & JOHN LEGEND", speed = 0.43 },
		{ id = "125367020013519", judul = "MOVE SHAKE DROP REMIX", speed = 0.43 },
		{ id = "91232020298385", judul = "MOVE", speed = 0.43 },
		{ id = "77948159247642", judul = "MR. MASH - SHOW ME LOVE X TAKE MY MIND", speed = 0.43 },
		{ id = "113388277798336", judul = "MY LECON – JTL", speed = 0.43 },
		{ id = "86657279243652", judul = "NEW RULES – DUA LIPA", speed = 0.43 },
		{ id = "105872940876117", judul = "NEW THANG – REDFOO", speed = 0.43 },
		{ id = "112980607009086", judul = "NEW", speed = 0.43 },
		{ id = "108551997352945", judul = "ON THE FLOOR – JENNIFER LOPEZ FT. PITBULL", speed = 0.43 },
		{ id = "99451155839906", judul = "ONE KISS – CALVIN HARRIS, DUA LIPA", speed = 0.43 },
		{ id = "120242668500492", judul = "ONE LAST TIME – ARIANA GRANDE", speed = 0.43 },
		{ id = "101461802776311", judul = "OURS TO KEEP", speed = 0.43 },
		{ id = "119175673559680", judul = "PAMUNGKAS - TO THE BONE", speed = 0.43 },
		{ id = "100088955665842", judul = "PARADISE – COLDPLAY", speed = 0.43 },
		{ id = "97943855355420", judul = "PEDRO CAPÓ, FARRUKO - CALMA - REMIX", speed = 0.43 },
		{ id = "112959868112214", judul = "PEOPLE X NAINOWALE NE – MASHUP", speed = 0.43 },
		{ id = "77732973664319", judul = "PEPAS – FARRUKO", speed = 0.43 },
		{ id = "121951263594456", judul = "PERFECT STRANGERS – JONAS BLUE FT. JP COOPER", speed = 0.43 },
		{ id = "89324491525255", judul = "PIECE OF YOUR HEART – MEDUZA FT. GOODBOYS", speed = 0.43 },
		{ id = "107665349275172", judul = "PLAY DATE – MELANIE MARTINEZ", speed = 0.43 },
		{ id = "109772207477202", judul = "POKER FACE – LADY GAGA", speed = 0.43 },
		{ id = "125684824756669", judul = "PROBLEM – ARIANA GRANDE FT. IGGY AZALEA", speed = 0.43 },
		{ id = "127501241986742", judul = "RAINDANCE", speed = 0.43 },
		{ id = "91774244679990", judul = "RAVYN LENAE - LOVE ME NOT", speed = 0.43 },
		{ id = "114766541542426", judul = "RECKLESS – MADISON BEER", speed = 0.43 },
		{ id = "105998406558060", judul = "REMEDY – ALESSO", speed = 0.43 },
		{ id = "98081128739374", judul = "REWRITE THE STARS – ANNE-MARIE & JAMES ARTHUR", speed = 0.43 },
		{ id = "92415708768255", judul = "RIGHT NOW - ONE DIRECTION", speed = 0.43 },
		{ id = "91148392716357", judul = "RISK IT ALL", speed = 0.43 },
		{ id = "75339874792375", judul = "RUNAWAY – AURORA", speed = 0.43 },
		{ id = "120773918360330", judul = "SABRINA , ARIANA GRANDE, BRUNO MARS, DUA LIPA", speed = 0.43 },
		{ id = "90526547684814", judul = "SAY IT RIGHT", speed = 0.43 },
		{ id = "127820824110491", judul = "SEÑORITA – SHAWN MENDES & CAMILA CABELLO", speed = 0.43 },
		{ id = "92149803401258", judul = "SHAPE OF YOU – ED SHEERAN", speed = 0.43 },
		{ id = "133473613368715", judul = "SHOW MUST GO ON - EXTENDED VERSION", speed = 0.43 },
		{ id = "138864395279071", judul = "SNOWMAN – SIA", speed = 0.43 },
		{ id = "127243151671199", judul = "SO AM I – AVA MAX", speed = 0.43 },
		{ id = "127253957435246", judul = "SOMEBODY ELSE – THE 1975", speed = 0.43 },
		{ id = "139979234540336", judul = "SOMEBODY", speed = 0.43 },
		{ id = "79074920741055", judul = "SOS (FEAT. ALOE BLACC) – AVICII", speed = 0.43 },
		{ id = "120103883068855", judul = "STAY THE NIGHT - HAYLEY WILLIAMS", speed = 0.43 },
		{ id = "138507593317414", judul = "STEREO LOVE X ON THE FLOOR – MASHUP", speed = 0.43 },
		{ id = "90223963339679", judul = "SUBEME LA RADIO – ENRIQUE IGLESIAS", speed = 0.43 },
		{ id = "127190824807077", judul = "SUMMERTIME SADNESS – LANA DEL REY", speed = 0.43 },
		{ id = "98075070321023", judul = "SWALLA (FEAT. NICKI MINAJ & TY DOLLA $IGN)", speed = 0.43 },
		{ id = "130884823962160", judul = "SYMPHONY (FEAT. ZARA LARSSON)", speed = 0.43 },
		{ id = "111641221274652", judul = "SNOOZE – SZA", speed = 0.43 },
		{ id = "105485375154471", judul = "SI AI - MARSHMELLO & UKAY REMIX", speed = 0.43 },
		{ id = "105496338924620", judul = "THAT", speed = 0.43 },
		{ id = "112142773667595", judul = "THE DRUM – ALAN WALKER", speed = 0.43 },
		{ id = "116305308141457", judul = "TTHE ONE THAT GOT AWAY – KATY PERRY", speed = 0.43 },
		{ id = "124743287070864", judul = "THE WEEKND, DAFT PUNK - STARBOY", speed = 0.43 },
		{ id = "106187846125118", judul = "THIS IS MY LIFE – EDWARD MAYA & VIKA JIGULINA", speed = 0.43 },
		{ id = "100863332990614", judul = "TITANIUM (FEAT. SIA)", speed = 0.43 },
		{ id = "106505255681358", judul = "TWERK IT LIKE MILEY – BRANDON BEAL", speed = 0.43 },
		{ id = "94946333921248", judul = "UMBRELLA – RIHANNA FT. JAY-Z", speed = 0.43 },
		{ id = "137263185225497", judul = "UNFORGETTABLE X I FOUND YOU – MASHUP", speed = 0.43 },
		{ id = "109276294743783", judul = "VIVA LA VIDA – COLDPLAY", speed = 0.43 },
		{ id = "121692728020654", judul = "VOODOO", speed = 0.43 },
		{ id = "130921831987405", judul = "WALK THRU FIRE – VICETONE", speed = 0.43 },
		{ id = "82450453986504", judul = "WE FOUND LOVE – RIHANNA FT. CALVIN HARRIS", speed = 0.43 },
		{ id = "98535582322176", judul = "WHEN I WAS YOUR MAN – BRUNO MARS", speed = 0.43 },
		{ id = "97445520020992", judul = "WHERE WE ARE X ONE THING X SNAP X GHOST X STRONG", speed = 0.43 },
		{ id = "92209677429610", judul = "WHO", speed = 0.43 },
		{ id = "71081612062106", judul = "YELLOW – COLDPLAY", speed = 0.43 },
		{ id = "102820354876163", judul = "YOU & ME - RIVO REMIX", speed = 0.43 },
		{ id = "98930856288321", judul = "YOUR LOVE (9PM) – ATB, TOPIC, A7S", speed = 0.43 },
		{ id = "135584481560737", judul = "THE LOTUS OF LIFE", speed = 0.43 },
		{ id = "134093385271929", judul = "WONDER - KATY PERRY", speed = 0.43 },
		{ id = "78094230170963", judul = "ABOUT YOU - THE 1975", speed = 0.43 },
		{ id = "136777117439065", judul = "MERRY CHRISTMAS PLEASE DONT CALL", speed = 0.43 },
		{ id = "120471463875349", judul = "ALL WE KNOW - THE CHAINSMOKERS", speed = 0.43 },
		{ id = "90820821099719", judul = "When I Close My Eyes", speed = 0.9 },
	},

	-- ==========================================================
	-- PLAYLIST 2 (139 Lagu)
	-- ==========================================================
	["PLAYLIST 2"] = {
		{ id = "125123785197681", judul = "Imagine Dragons - Believer", speed = 0.43 },
		{ id = "135795407885794", judul = "Pháo, KAIZ - 2 Phút Hơn Remix", speed = 0.43 },
		{ id = "92468072812953", judul = "Bruno Mars - 24K Magic", speed = 0.43 },
		{ id = "131860408757649", judul = "Anne-Marie - 2002", speed = 0.43 },
		{ id = "93938313289251", judul = "GAYLE - abcdefu", speed = 0.43 },
		{ id = "89413148053463", judul = "Sevdaliza, Pabllo Vittar & Yseult - Alibi", speed = 0.43 },
		{ id = "79199056601515", judul = "R3HAB, A Touch Of Class - All Around The World (La La La)", speed = 0.43 },
		{ id = "136310156670653", judul = "Stromae - Alors on danse", speed = 0.43 },
		{ id = "125893868282095", judul = "Lost Frequencies - Are You With Me", speed = 0.43 },
		{ id = "76677555900708", judul = "Charlie Puth - Attention", speed = 0.43 },
		{ id = "74131453664281", judul = "David Guetta, Showtek, Vassy - Bad", speed = 0.43 },
		{ id = "81694583241745", judul = "Marwa Loud - Bad boy", speed = 0.43 },
		{ id = "107285610587671", judul = "Akon - Bananza", speed = 0.43 },
		{ id = "131065141071279", judul = "Justin Bieber, Nicki Minaj - Beauty And A Beat", speed = 0.43 },
		{ id = "79687467158508", judul = "Måneskin - Beggin", speed = 0.43 },
		{ id = "133146123343770", judul = "Billie Eilish - BIRDS OF A FEATHER", speed = 0.43 },
		{ id = "114636926813110", judul = "Armin van Buuren - Blah Blah Blah", speed = 0.43 },
		{ id = "104300829677999", judul = "BLACKPINK - BOOMBAYAH", speed = 0.43 },
		{ id = "108888658191229", judul = "Showtek, We Are Loud!, Sonny Wilson - Booyah", speed = 0.43 },
		{ id = "122025536435298", judul = "The Pussycat Dolls - Britney Spears - Toxic", speed = 0.43 },
		{ id = "73665690002977", judul = "The Pussycat Dolls - Buttons", speed = 0.43 },
		{ id = "71221346799208", judul = "Ariana Grande - bye", speed = 0.43 },
		{ id = "106342934544489", judul = "Brazilian FunkClub - C", speed = 0.43 },
		{ id = "108352233540521", judul = "Akon - Chammak Challo - Remix", speed = 0.43 },
		{ id = "117675790545248", judul = "KSHMR, Tungevaag - Close Your Eyes", speed = 0.43 },
		{ id = "78867975994669", judul = "Aya Nakamura - Copines", speed = 0.43 },
		{ id = "108785504161409", judul = "OneRepublic - Counting Stars", speed = 0.43 },
		{ id = "134713114726890", judul = "BLACKPINK - DDU-DU DDU-DU", speed = 0.43 },
		{ id = "113889055026850", judul = "Imagine Dragons - Demons", speed = 0.43 },
		{ id = "87689294214968", judul = "David Guetta, OneRepublic - I Don", speed = 0.43 },
		{ id = "91495388196704", judul = "Pia Mia, Chris Brown, Tyga - Do It Again", speed = 0.43 },
		{ id = "113417336172764", judul = "фрози, Mwizz, Genjutsu - Don", speed = 0.43 },
		{ id = "140138779696457", judul = "BTS - Dynamite", speed = 0.43 },
		{ id = "86960197883937", judul = "Ariana Grande, Future - Everyday", speed = 0.43 },
		{ id = "83934692312609", judul = "Klaas, Ruiz - Feel Only Love", speed = 0.43 },
		{ id = "126621356371339", judul = "Hartzon - Finally Found You", speed = 0.43 },
		{ id = "138127404702087", judul = "Jessie J - Flashlight", speed = 0.43 },
		{ id = "134624356708618", judul = "Marshmello - Freal Luv", speed = 0.43 },
		{ id = "129107676016959", judul = "FloyyMenor, Cris MJ - Gata Only", speed = 0.43 },
		{ id = "90601105931989", judul = "Dillon Francis, DJ Snake - Get Low", speed = 0.43 },
		{ id = "82060958562272", judul = "HUNTR; X, EJAE, A... - Golden", speed = 0.43 },
		{ id = "107767305268529", judul = "Ciara, Petey Pablo - Goodies", speed = 0.43 },
		{ id = "98147104512562", judul = "Tate McRae - greedy", speed = 0.43 },
		{ id = "81263444217113", judul = "Habibi - Albanian Remix", speed = 0.43 },
		{ id = "103840020435749", judul = "Tove Lo - Habits (Stay High)", speed = 0.43 },
		{ id = "132154108438718", judul = "Bring Me The Horizon - Happy Song", speed = 0.43 },
		{ id = "124675013865789", judul = "Katy Perry - Harleys In Hawaii", speed = 0.43 },
		{ id = "70898523747613", judul = "Twenty One Pilots - Heathens", speed = 0.43 },
		{ id = "109723738485957", judul = "Skate Avenue PH - Heaven Knows - Rock Version", speed = 0.43 },
		{ id = "72864385602930", judul = "Jamie Miller - Here", speed = 0.43 },
		{ id = "79709779328321", judul = "Alesso, Tove Lo - Heroes", speed = 0.43 },
		{ id = "82274185214832", judul = "David Guetta - Hey Mama", speed = 0.43 },
		{ id = "123458185325843", judul = "Pitbull - Hotel Room Service", speed = 0.43 },
		{ id = "136836238237170", judul = "Calvin Harris, Disciples - How Deep Is Your Love", speed = 0.43 },
		{ id = "134545309462305", judul = "BLACKPINK - How You Like That", speed = 0.43 },
		{ id = "105195558549406", judul = "Mike Posner, Seeb - I Took A Pill In Ibiza Remix", speed = 0.43 },
		{ id = "103339124039240", judul = "Yung Bleu - Ice On My Baby", speed = 0.43 },
		{ id = "87441043469057", judul = "LANY - ILYSB", speed = 0.43 },
		{ id = "93630643546248", judul = "Ariana Grande - Into You", speed = 0.43 },
		{ id = "78154150613249", judul = "SZA - Kill Bill", speed = 0.43 },
		{ id = "89862250114655", judul = "Ava Max - Kings & Queens", speed = 0.43 },
		{ id = "108291097685032", judul = "фрози - kompa pasión", speed = 0.43 },
		{ id = "110015473458051", judul = "Oxlade, Camila Cabello - KU LO SA", speed = 0.43 },
		{ id = "95637289581190", judul = "Shoti - LDR", speed = 0.43 },
		{ id = "134438776774682", judul = "Marshmello - Leave Before You Love Me", speed = 0.43 },
		{ id = "126438002057380", judul = "Charlie Puth, Jung Kook - Left and Right", speed = 0.43 },
		{ id = "110904377974946", judul = "Legends Never Die", speed = 0.43 },
		{ id = "131704814792697", judul = "Major Lazer, Nyla, Fuse ODG - Light It Up", speed = 0.43 },
		{ id = "131549896252527", judul = "CKay - love nwantiti (ah ah ah)", speed = 0.43 },
		{ id = "115457254610416", judul = "Selena Gomez - Love You Like A Love", speed = 0.43 },
		{ id = "111588768397709", judul = "Chris Brown, Lil Wayne, Tyga - Loyal", speed = 0.43 },
		{ id = "124046651866950", judul = "Bruno Mars - Marry You", speed = 0.43 },
		{ id = "137907107069486", judul = "Charlie Puth, Meghan Trainor - Marvin Gaye", speed = 0.43 },
		{ id = "96613254746235", judul = "LAUV, LANY - Mean It", speed = 0.43 },
		{ id = "72854957009054", judul = "J Balvin, Willy William - Mi Gente", speed = 0.43 },
		{ id = "136946747325299", judul = "Elley Duhé - MIDDLE OF THE NIGHT", speed = 0.43 },
		{ id = "132566446773108", judul = "Zara Larsson, MNEK - Never Forget You", speed = 0.43 },
		{ id = "128653944005919", judul = "One Direction - Night Changes", speed = 0.43 },
		{ id = "135378155849460", judul = "Cheat Codes, Demi Lovato - No Promises", speed = 0.43 },
		{ id = "109701211202500", judul = "Billie Eilish - ocean eyes", speed = 0.43 },
		{ id = "130642128558293", judul = "SONIC MUSIC - Oh Carol", speed = 0.43 },
		{ id = "137295547488017", judul = "Panca Borneo - Oh Honey", speed = 0.43 },
		{ id = "93538889308082", judul = "Drake, Wizkid, Kyla - One Dance", speed = 0.43 },
		{ id = "103286010107622", judul = "brux XTN - Paid to Exist", speed = 0.43 },
		{ id = "140306512922811", judul = "Nej - Paro", speed = 0.43 },
		{ id = "139576926179266", judul = "Midas the Jagaban - Party With A Jagaban", speed = 0.43 },
		{ id = "98833666197021", judul = "MEDUZA, Goodboys - Piece Of Your Heart", speed = 0.43 },
		{ id = "135588377901671", judul = "The Weeknd, Playboi Carti, Madonna - Popular", speed = 0.43 },
		{ id = "106495801273248", judul = "Moises Roswick Funes - Pota Pota Dance", speed = 0.43 },
		{ id = "81741065689787", judul = "Jessie J, B.o.B - Price Tag", speed = 0.43 },
		{ id = "109614975278095", judul = "CARYS - Princesses Don", speed = 0.43 },
		{ id = "88494769050919", judul = "AYA MUSIC OFC - Right Here Waiting", speed = 0.43 },
		{ id = "83159765059740", judul = "Faouzia - RIP, Love", speed = 0.43 },
		{ id = "105706387589913", judul = "Jonas Blue, Jack & Jack - Rise", speed = 0.43 },
		{ id = "76519714870465", judul = "Tiësto, Jonas Blue, Rita Ora - Ritual", speed = 0.43 },
		{ id = "137680040969651", judul = "Egzod, Maestro Chives, Neoni - Royalty", speed = 0.43 },
		{ id = "131074215208180", judul = "Serena - Safari", speed = 0.43 },
		{ id = "117458096748479", judul = "Jawsh 685, Jason Derulo - Savage Love", speed = 0.43 },
		{ id = "97457350813607", judul = "Jamrud - Selamat Ulang Tahun", speed = 0.43 },
		{ id = "86004684164028", judul = "Set Me Free - Remix", speed = 0.43 },
		{ id = "83788786716314", judul = "Camila Cabello - Shameless", speed = 0.43 },
		{ id = "73865424123139", judul = "Ed Sheeran - Shape of You", speed = 0.43 },
		{ id = "132743768759903", judul = "David Guetta - Shot Me Down", speed = 0.43 },
		{ id = "122702989213439", judul = "Yellow Claw, Rochelle - Shotgun", speed = 0.43 },
		{ id = "116894496750750", judul = "Becky G, NATTI NATASHA - Sin Pijama", speed = 0.43 },
		{ id = "82563787929925", judul = "Adele - Skyfall", speed = 0.43 },
		{ id = "116459335836138", judul = "Olivia Dean - So Easy", speed = 0.43 },
		{ id = "91219873450152", judul = "Clean Bandit, Demi Lovato - Solo", speed = 0.43 },
		{ id = "91219873450152", judul = "JENNIE - SOLO", speed = 0.43 },
		{ id = "78839686821546", judul = "Bex - Suffer", speed = 0.43 },
		{ id = "97078465128999", judul = "Ava Max - Sweet but Psycho", speed = 0.43 },
		{ id = "124311613473622", judul = "Loreen - Tattoo", speed = 0.43 },
		{ id = "113860168113794", judul = "Gracie Abrams - That", speed = 0.43 },
		{ id = "116745405722166", judul = "Taylor Swift - The Fate of Ophelia", speed = 0.43 },
		{ id = "93102288583928", judul = "The Script - The Man Who Can", speed = 0.43 },
		{ id = "81471413597387", judul = "Alan Walker - The Spectre", speed = 0.43 },
		{ id = "82207261138166", judul = "Lil Uzi Vert, Oh Wonder - The Way Life Goes", speed = 0.43 },
		{ id = "72367734251635", judul = "Kungs, Cookin", speed = 0.43 },
		{ id = "119446093391173", judul = "Calvin Harris, Rihanna - This Is What You Came For", speed = 0.43 },
		{ id = "83975041678547", judul = "David Guetta, Zara Larsson - This One", speed = 0.43 },
		{ id = "121433160488697", judul = "ONE OR EIGHT - TOKYO DRIFT", speed = 0.43 },
		{ id = "103408496298570", judul = "Britney Spears - Toxic", speed = 0.43 },
		{ id = "105382993159808", judul = "Shawn Mendes - Treat You Better", speed = 0.43 },
		{ id = "75209909311906", judul = "DVBBS, Borgeous - Tsunami", speed = 0.43 },
		{ id = "104291020165931", judul = "Chris Brown - Under The Influence", speed = 0.43 },
		{ id = "70426699815547", judul = "Shakira - Waka Waka", speed = 0.43 },
		{ id = "128970373926931", judul = "Silentó - Watch Me", speed = 0.43 },
		{ id = "137845708453815", judul = "Tyla - Water", speed = 0.43 },
		{ id = "83892102648898", judul = "One Direction - What Makes You Beautiful", speed = 0.43 },
		{ id = "101442802984639", judul = "Jack Ü, Skrillex, Diplo, Justin Bieber - Where Are Ü Now", speed = 0.43 },
		{ id = "79492561657062", judul = "Billie Eilish - WILDFLOWER", speed = 0.43 },
		{ id = "115212459657917", judul = "Halsey - Without Me", speed = 0.43 },
		{ id = "125679714008079", judul = "Doja Cat - Woman", speed = 0.43 },
		{ id = "138571607129198", judul = "Fifth Harmony, Ty Dolla $ign - Work from Home", speed = 0.43 },
		{ id = "94946211178327", judul = "NIKI - You", speed = 0.43 },
		{ id = "131996827933861", judul = "Khalid - Young Dumb & Broke", speed = 0.43 },
		{ id = "74868175074141", judul = "Ikimonogakari - ブルーバード", speed = 0.43 },
		{ id = "127766894928897", judul = "Juepak, จ๊ะ นงผณี, G... - เมร่อน", speed = 0.43 },
		{ id = "77707571119066", judul = "Baimint, GUNNER - จ๊าบของแท้ - GUNNER Remix", speed = 0.43 },
	},

	-- ==========================================================
	-- BREAKBEAT (210 Lagu)
	-- ==========================================================
	["BREAKBEAT"] = {
		{ id = "105498304144504", judul = "BREAKBEAT BAILAR BLACK HOLE", speed = 0.9 },
		{ id = "103475221920430", judul = "BREAKBEAT TANPA CINTA", speed = 0.9 },
		{ id = "94090915796948", judul = "AKON - BEAUTIFUL", speed = 0.9 },
		{ id = "122253866454061", judul = "BREAKBEAT POMPEII", speed = 0.9 },
		{ id = "74647900745715", judul = "Dj If It Wasn", speed = 0.9 },
		{ id = "135337259541231", judul = "BREAKBEAT GLADE YOU CAME", speed = 0.9 },
		{ id = "71423184999824", judul = "WAITING STADIUM BREAKBEAT", speed = 0.9 },
		{ id = "122502605906661", judul = "ATLANTIS STADIUM BREAKBEAT", speed = 0.9 },
		{ id = "120915132243496", judul = "BREAKBEAT SUN AND MOON", speed = 0.9 },
		{ id = "98756748818407", judul = "BREAKBEAT THE SECOND YOU SLEEP", speed = 0.9 },
		{ id = "73599587113479", judul = "BREAKBEAT CANT STOP LOVING YOU", speed = 0.9 },
		{ id = "126643849808708", judul = "BREAKBEAT CLOSE YOUR EYES", speed = 0.9 },
		{ id = "96368504905727", judul = "BREAKBEAT JANGAN TUNGGU LAMA LAMA", speed = 0.9 },
		{ id = "102625381230369", judul = "BREAKBEAT THE FATE OF OPHRLIA", speed = 0.9 },
		{ id = "78930738470270", judul = "BREAKBEAT TANTE TANTE CULIK AKU DONG", speed = 0.9 },
		{ id = "118231341943264", judul = "BREAKBEAT REMIX SEAN - PAUL SHE DOESN", speed = 0.9 },
		{ id = "100134393792281", judul = "BREAKBEAT LAROXX - PROJECT DON", speed = 0.9 },
		{ id = "109256791527622", judul = "BREAKBEAT GIRLS GENERATIONSNSD - OH", speed = 0.9 },
		{ id = "117023580399391", judul = "BREAKBEAT PROGRESSIVE DORA DORA X BRAND NEW DAY", speed = 0.9 },
		{ id = "138394176444816", judul = "BREAKBEAT Ciperi Pam Pam", speed = 0.9 },
		{ id = "121353060114685", judul = "BREAKBEAT Horizon", speed = 0.9 },
		{ id = "84529855617994", judul = "BREAKBEAT ROSSA - TAK SANGGUP LAGI", speed = 0.9 },
		{ id = "103113810859462", judul = "BREAKBEAT I NEED A DOCTOR", speed = 0.9 },
		{ id = "132091575381190", judul = "BREAKBEAT WHERE DO WE BEGIN", speed = 0.9 },
		{ id = "97255165323923", judul = "BREAKBEAT DRIVE", speed = 0.9 },
		{ id = "90153230363269", judul = "BREAKBEAT EVERYTHING I NEED", speed = 0.9 },
		{ id = "122128659091503", judul = "BREAKBEAT FEELS LIKE HOME", speed = 0.9 },
		{ id = "86321979672906", judul = "BREAKBEAT HEARTBREAKING", speed = 0.9 },
		{ id = "111268716383584", judul = "BREAKBEAT MAN ON THE RUN", speed = 0.9 },
		{ id = "135645023276954", judul = "BREAKBEAT THIS I VOW", speed = 0.9 },
		{ id = "103558212918173", judul = "BREAKBEAT RAMELIA", speed = 0.9 },
		{ id = "134282782367630", judul = "BREAKBEAT BE AS ONE", speed = 0.9 },
		{ id = "128362773204435", judul = "BREAKBEAT TILL THE SKY FALLS DOWN", speed = 0.9 },
		{ id = "110184593820416", judul = "BREAKBEAT BEAUTIFUL LIE", speed = 0.9 },
		{ id = "84605967471172", judul = "BREAKBEAT FREEFALL", speed = 0.9 },
		{ id = "123124685248155", judul = "BREAKBEAT Put Your Hands Up", speed = 0.9 },
		{ id = "135604099859125", judul = "BREAKBEAT Better Off Alone", speed = 0.9 },
		{ id = "138840603572468", judul = "BREAKBEAT I Got U", speed = 0.9 },
		{ id = "102869498075580", judul = "BREAKBEAT Hanya Ingin Kau Tau", speed = 0.9 },
		{ id = "111809764403727", judul = "BREAKBEAT Just Another Night", speed = 0.9 },
		{ id = "108888809665815", judul = "BREAKBEAT You", speed = 0.9 },
		{ id = "103616711888221", judul = "BREAKBEAT Plastic", speed = 0.9 },
		{ id = "139640669049168", judul = "BREAKBEAT Shadow", speed = 0.9 },
		{ id = "137399827851381", judul = "BREAKBEAT IN AND OUT OF LOVE", speed = 0.9 },
		{ id = "104128642039869", judul = "BREAKBEAT Aku Sayang Sampai Mati", speed = 0.9 },
		{ id = "97365449980687", judul = "Freaks Time", speed = 0.9 },
		{ id = "137964573724941", judul = "Wet Dream", speed = 0.9 },
		{ id = "100583222608426", judul = "BREAKBEAT Terserah (Raisa)", speed = 0.9 },
		{ id = "108575134456100", judul = "BREAKBEAT Sound Of My Dream", speed = 0.9 },
		{ id = "111673988982403", judul = "BREAKBEAT Always Loving You", speed = 0.9 },
		{ id = "133638540362172", judul = "BREAKBEAT Dancing With Your Ghost", speed = 0.9 },
		{ id = "140328305976667", judul = "BREAKBEAT Aurora", speed = 0.9 },
		{ id = "123411462236449", judul = "BREAKBEAT Danza Kuduro", speed = 0.9 },
		{ id = "73835490732159", judul = "BREAKBEAT RIGHT NOW (NA NA NA)", speed = 0.9 },
		{ id = "128702648637622", judul = "BREAKBEAT BHABI", speed = 0.9 },
		{ id = "125710994306296", judul = "BREAKBEAT Thank You (Not So Bad)", speed = 0.9 },
		{ id = "75734899625892", judul = "BREAKBEAT I Don", speed = 0.9 },
		{ id = "125966225704229", judul = "BREAKBEAT MACARENA", speed = 0.9 },
		{ id = "111968042309187", judul = "BREAKBEAT Someone Like You", speed = 0.9 },
		{ id = "126723036079403", judul = "BREAKBEAT Wirang", speed = 0.9 },
		{ id = "121593775087320", judul = "BREAKBEAT Lost Without You", speed = 0.9 },
		{ id = "139576874142238", judul = "BREAKBEAT Serana", speed = 0.9 },
		{ id = "135236944972072", judul = "BREAKBEAT Faded X Alone", speed = 0.9 },
		{ id = "122795769130133", judul = "BREAKBEAT Save Me", speed = 0.9 },
		{ id = "78091269992641", judul = "BREAKBEAT Dynamite X Drive", speed = 0.9 },
		{ id = "131106560732896", judul = "BREAKBEAT Hero - Alan Walker", speed = 0.9 },
		{ id = "97022378985103", judul = "BREAKBEAT NU", speed = 0.9 },
		{ id = "86487374612171", judul = "BREAKBEAT Love Is Unbound", speed = 0.9 },
		{ id = "126373862940021", judul = "BREAKBEAT NOW I SEE", speed = 0.9 },
		{ id = "122598264064126", judul = "BREAKBEAT TABOLA BALE", speed = 0.9 },
		{ id = "122446227623730", judul = "BREAKBEAT Not You", speed = 0.9 },
		{ id = "77044004268048", judul = "BREAKBEAT Power Of Magic V2", speed = 0.9 },
		{ id = "105166838331594", judul = "BREAKBEAT Jakarta", speed = 0.9 },
		{ id = "122377272211224", judul = "BREAKBEAT Kota Ini Tak Sama Tanpamu", speed = 0.9 },
		{ id = "126191403600753", judul = "BREAKBEAT Love Story", speed = 0.9 },
		{ id = "72597047733804", judul = "BREAKBEAT Love", speed = 0.9 },
		{ id = "123594749227298", judul = "BREAKBEAT Take Me Home, Country Roads", speed = 0.9 },
		{ id = "138879592235902", judul = "BREAKBEAT Drive Me Crazy", speed = 0.9 },
		{ id = "115477585823113", judul = "BREAKBEAT Close to the Stars", speed = 0.9 },
		{ id = "89211783344563", judul = "BREAKBEAT Mencintaimu", speed = 0.9 },
		{ id = "93764871626839", judul = "BREAKBEAT You", speed = 0.9 },
		{ id = "138150043475960", judul = "BREAKBEAT Teganya Kau", speed = 0.9 },
		{ id = "84438419182722", judul = "BREAKBEAT AFTERSHOCK" },
		{ id = "78699624855964", judul = "BREAKBEAT CYBERDREAM" },
		{ id = "136467152968541", judul = "BREAKBEAT Alive" },
		{ id = "130096834598482", judul = "BREAKBEAT Can We Dance", speed = 0.9 },
		{ id = "113866909192562", judul = "BREAKBEAT HANDS", speed = 0.9 },
		{ id = "131633227619562", judul = "BREAKBEAT Shut Up and Dance", speed = 0.9 },
		{ id = "91068299807070", judul = "BREAKBEAT Pure Love", speed = 0.9 },
		{ id = "107439410822623", judul = "BREKBEAT Un-Break My Heart" },
		{ id = "123940974514916", judul = "BREAKBEAT Where Have You Been", speed = 0.9 },
		{ id = "87271721081505", judul = "BREAKBEAT RUSSIAN R0UL3TT3", speed = 0.9 },
		{ id = "87655422840771", judul = "BREAKBEAT SYMPHONY", speed = 0.9 },
		{ id = "112615350496910", judul = "BREAKBEAT IM LO", speed = 0.9 },
		{ id = "120437660594492", judul = "BREAKBEAT SEPARUH NAFASKU" },
		{ id = "102864592855033", judul = "BREAKBEAT PENIPU HATI" },
		{ id = "132608652867470", judul = "BREAKBEAT Barbie Girl x Que Pasa" },
		{ id = "129266256358292", judul = "BREAKBEAT Jar of Heart" },
		{ id = "90410735710111", judul = "BREAKBEAT Disarankan Di Bandung", speed = 0.9 },
		{ id = "95412810647622", judul = "BREAKBEAT Beautiful Now", speed = 0.9 },
		{ id = "133521288044966", judul = "BEAUTY AND A BEAT" },
		{ id = "71739713303715", judul = "WildFlower - Billie Eilish" },
		{ id = "96658868498111", judul = "Beauty And A Beat - Justin Bieber" },
		{ id = "123798644499311", judul = "I WISH" },
		{ id = "131434979823319", judul = "ANGELS LIKE YOU" },
		{ id = "81795986620169", judul = "STEREO LOVE" },
		{ id = "79036934804022", judul = "DON" },
		{ id = "140307464955008", judul = "SOUL ON THE RUN" },
		{ id = "80984680926356", judul = "THIS I VOW" },
		{ id = "131384364335670", judul = "Jonas Blue - Perfect Strangers" },
		{ id = "116474214270991", judul = "Dynamite" },
		{ id = "118033326486674", judul = "Ain" },
		{ id = "72305398957096", judul = "EEEE A - Dial" },
		{ id = "97667027396765", judul = "Faded" },
		{ id = "110974005461814", judul = "Where We Are" },
		{ id = "112628994948375", judul = "BLUE" },
		{ id = "91997083709307", judul = "Malu Malu Boy" },
		{ id = "87510137146967", judul = "Golden" },
		{ id = "117958712648696", judul = "Play" },
		{ id = "109680690451375", judul = "FLASHLIGHT" },
		{ id = "95150908894825", judul = "SHELTER" },
		{ id = "83350632225675", judul = "Middle" },
		{ id = "102052409456362", judul = "UMBRELLA" },
		{ id = "104692490212730", judul = "Believe" },
		{ id = "108354272091309", judul = "When It Ends It Starts Again" },
		{ id = "138369528481690", judul = "SERANA" },
		{ id = "129349311051513", judul = "Where You Are" },
		{ id = "79046859597055", judul = "Take Me Home" },
		{ id = "108396916634517", judul = "Dream" },
		{ id = "97861526205534", judul = "STARS COLLIDE X GOODBYE" },
		{ id = "86823111827904", judul = "Kasih Tau Mama" },
		{ id = "83829219721062", judul = "Butterfly" },
		{ id = "98251507031381", judul = "RECKLESS" },
		{ id = "94179869407995", judul = "So ASU" },
		{ id = "85422102997418", judul = "Sad Sometimes" },
		{ id = "107336984768245", judul = "Believe (Alt)" },
		{ id = "90040341854319", judul = "Because Youre Here" },
		{ id = "111972811478756", judul = "RISK IT ALL" },
		{ id = "124329198776323", judul = "TILL THE SKY FALLS DOWN" },
		{ id = "113898928848544", judul = "LOVE ATAN ATAN x BINTANG" },
		{ id = "132697530045986", judul = "Ghost - Justin Bieber" },
		{ id = "111118770070856", judul = "Right_Now_Na_Na_Na" },
		{ id = "95316179760818", judul = "Love" },
		{ id = "110108362191323", judul = "MIRACLES" },
		{ id = "130573949850577", judul = "BRAND NEW DAY X DORA DORA" },
		{ id = "93119586262696", judul = "River Flows In You" },
		{ id = "126611532124152", judul = "A Sky Full Of Stars" },
		{ id = "95462060550415", judul = "This Love Drives Me Crazy" },
		{ id = "135493429463331", judul = "YOU DONT EVEN KNOW ME X PEOPLE" },
		{ id = "120383160106356", judul = "All Night", speed = 0.9 },
		{ id = "90921300628080", judul = "TEN FEET TALL", speed = 0.9 },
		{ id = "106832004561605", judul = "DREAMER", speed = 0.9 },
		{ id = "101951488636873", judul = "Invicible", speed = 0.9 },
		{ id = "90204322497494", judul = "Dora X Stephanie", speed = 0.9 },
		{ id = "87585494472221", judul = "Ours To Keep", speed = 0.9 },
		{ id = "94616536057586", judul = "If I Lose Myself", speed = 0.9 },
		{ id = "127019714407426", judul = "STAY WITH ME", speed = 0.9 },
		{ id = "137258078964918", judul = "BREAKBEAT DJ JOANNA", speed = 0.9 },
		{ id = "75481507579973", judul = "BREAKBEAT DJ UNITY X PLAY FOR ME", speed = 0.9 },
		{ id = "138965817761821", judul = "BREAKBEAT DJ YA ODNA X THE DRUM", speed = 0.9 },
		{ id = "132188097930446", judul = "Wolves - Selena Gomez Marshmello", speed = 0.9 },
		{ id = "108498617675673", judul = "Lions In The Wild", speed = 0.9 },
		{ id = "131732563686566", judul = "I SURRENDER TO YOU", speed = 0.9 },
		{ id = "127023516638422", judul = "Turn It Up", speed = 0.9 },
		{ id = "131570146956313", judul = "Dont Watch Me Cry", speed = 0.9 },
		{ id = "96585234835928", judul = "PUT YOUR HANDS UP", speed = 0.9 },
		{ id = "82800024361608", judul = "SUMMER AIR", speed = 0.9 },
		{ id = "95728842583428", judul = "DESPACITO", speed = 0.9 },
		{ id = "112641289202152", judul = "Inside The Lines Mike Perry", speed = 0.9 },
		{ id = "125525119845707", judul = "Shimpony", speed = 0.9 },
		{ id = "99837751187401", judul = "Beby Dont Go", speed = 0.9 },
		{ id = "108723294028764", judul = "E e e a", speed = 0.9 },
		{ id = "75040733117467", judul = "TO LOVE YOU MORE", speed = 0.9 },
		{ id = "135006908074580", judul = "Sedia Aku Sebelum Hujan", speed = 0.9 },
		{ id = "75545164837383", judul = "VIERRA - PERIH", speed = 0.9 },
		{ id = "74934787369700", judul = "Close to You", speed = 0.9 },
		{ id = "81405359566835", judul = "KISINAN x NEMEN", speed = 0.9 },
		{ id = "130168099307452", judul = "TANYA HATI", speed = 0.9 },
		{ id = "116119101594923", judul = "Last Child - Duka", speed = 0.9 },
		{ id = "135967332909455", judul = "Mimosa", speed = 0.9 },
		{ id = "112293233287931", judul = "NOW I SEE X IN AND OUT OF LOVE", speed = 0.9 },
		{ id = "112225285920304", judul = "ROCKABYE", speed = 0.9 },
		{ id = "131329071633662", judul = "REST OF OUR LIVES", speed = 0.9 },
		{ id = "103800473180699", judul = "KOTA INI TAK SAMA TANPAMU", speed = 0.9 },
		{ id = "80206885810979", judul = "SO IM YRS", speed = 0.9 },
		{ id = "103786049761147", judul = "ONE IN A MILLION", speed = 0.9 },
		{ id = "111624142825016", judul = "CINTA SATU MALAM", speed = 0.9 },
		{ id = "111141144551849", judul = "OUR LOVE", speed = 0.9 },
		{ id = "100693436109082", judul = "I WILL FIND YOU", speed = 0.9 },
		{ id = "102392919687639", judul = "SAMSON - DI UJUNG JALAN", speed = 0.9 },
		{ id = "135648480510653", judul = "SCARED TO BE LONELY", speed = 0.9 },
		{ id = "98467725289439", judul = "EVERYTHING AT ONCE", speed = 0.9 },
		{ id = "132899973744315", judul = "FOR THE LOVE", speed = 0.9 },
		{ id = "132195017360346", judul = "Good Side", speed = 0.9 },
		{ id = "133717121367094", judul = "Orang Yang Salah", speed = 0.9 },
		{ id = "121886677783639", judul = "Kenangan Terindah", speed = 0.9 },
		{ id = "99913250155476", judul = "Freeze Time", speed = 0.9 },
		{ id = "127135428052460", judul = "Walking On Air", speed = 0.9 },
		{ id = "133791309904037", judul = "Komang", speed = 0.9 },
		{ id = "104521051049200", judul = "Love Is Gone", speed = 0.9 },
		{ id = "124607399350502", judul = "BABY", speed = 0.9 },
		{ id = "92507017240598", judul = "Tak Ingin Usai", speed = 0.9 },
		{ id = "98276204331532", judul = "NOT YOU", speed = 0.9 },
		{ id = "100104887781678", judul = "Angel Baby", speed = 0.9 },
		{ id = "134245225858269", judul = "Semata Karenamu", speed = 0.9 },
		{ id = "121894042941802", judul = "Still The Same", speed = 0.9 },
		{ id = "130858517049116", judul = "BAD LIAR", speed = 0.9 },
		{ id = "84191613296110", judul = "For The One", speed = 0.9 },
		{ id = "120425660332478", judul = "Aurora", speed = 0.9 },
		{ id = "134094528868484", judul = "ASHES", speed = 0.9 },
	},

	-- ==========================================================
	-- THAILAND STYLE (25 Lagu)
	-- ==========================================================
	["THAILAND STYLE"] = {
		{ id = "108408071718050", judul = "THAILAND STYLE Kehlani Folded", speed = 0.9 },
		{ id = "100938032342972", judul = "THAILAND STYLE Bye", speed = 0.9 },
		{ id = "89699825050196", judul = "THAILAND STYLE Toton Caribo Ora Urus", speed = 0.9 },
		{ id = "125321559827165", judul = "THAILAND STYLE Shae Sayang", speed = 0.9 },
		{ id = "115992008938120", judul = "THAILAND STYLE Dia _ Tenxi Sency", speed = 0.9 },
		{ id = "72938763435547", judul = "THAILAND STYLE Natasya Sabella Menerima Luka", speed = 0.9 },
		{ id = "98149105037050", judul = "THAILAND STYLE Pata Pata", speed = 0.9 },
		{ id = "110302481017671", judul = "THAILAND STYLE Glenn Fredly Januari", speed = 0.9 },
		{ id = "121528010781939", judul = "THAILAND STYLE Body Pata Pata X Stecu Stecu", speed = 0.9 },
		{ id = "84496427560934", judul = "THAILAND STYLE Curi Curi Pandang", speed = 0.9 },
		{ id = "83679436916114", judul = "THAILAND STYLE Toton Caribo Ngapain Repot", speed = 0.9 },
		{ id = "81346766136527", judul = "THAILAND STYLE Perunggu “33x”", speed = 0.9 },
		{ id = "102786064793133", judul = "THAILAND STYLE Izanor Alveiro “Ade Su Nikah”", speed = 0.9 },
		{ id = "137274500408453", judul = "THAILAND STYLE Lina Lady Geboy ”Jarang Pulang”", speed = 0.9 },
		{ id = "139010273504520", judul = "THAILAND STYLE Kasih Aba-Aba", speed = 0.9 },
		{ id = "85115877260374", judul = "THAILAND STYLE Lolita ”Alay”", speed = 0.9 },
		{ id = "98509262574700", judul = "THAILAND STYLE ndx aka - ”tresno tekan mati”", speed = 0.9 },
		{ id = "87704203254983", judul = "THAILAND STYLE garam dan madu", speed = 0.9 },
		{ id = "108394196769796", judul = "THAILAND STYLE DITINGGAL RABI X SEWATES KONCO", speed = 0.9 },
		{ id = "71538060113255", judul = "THAILAND STYLE KICAU MANIA", speed = 0.9 },
		{ id = "93989503395575", judul = "THAILAND STYLE Kangen Band Nilailah Aku" },
		{ id = "97419595340862", judul = "hold on thailand edit", speed = 0.7 },
		{ id = "124885931890954", judul = "Armada Mabuk Cinta - Thailand Edit", speed = 0.7 },
		{ id = "107402047715247", judul = "Shine Of Black Jang Ganggu - Thailand Edit", speed = 0.7 },
		{ id = "78758780594659", judul = "Goyang Dumang X Hold On - Thailand Edit", speed = 0.7 },
	},

	-- ==========================================================
	-- FUNKOT STYLE (20 Lagu)
	-- ==========================================================
	["FUNKOT STYLE"] = {
		{ id = "71330340665281", judul = "FUNKOT DAMON VACATION X TERENA METE X TOLONG PA NGANA", speed = 0.9 },
		{ id = "84169167680157", judul = "FUNKOT STECU STECU", speed = 0.9 },
		{ id = "119604195746368", judul = "FUNKOT APA KABAR SAYANG", speed = 0.9 },
		{ id = "80812080448807", judul = "FUNKOT DI UJUNG JALAN", speed = 0.9 },
		{ id = "72612522452910", judul = "FUNKOT DUKA", speed = 0.9 },
		{ id = "74948645966301", judul = "FUNKOT KOPLO TIE ME DOWN", speed = 0.9 },
		{ id = "85845230173199", judul = "FUNKOT SUMPAH DAN CINTA MATIKU", speed = 0.9 },
		{ id = "74457406744934", judul = "FUNKOT SUMPAH DAN CINTA MATIKU - NIDJI", speed = 0.9 },
		{ id = "118944211081297", judul = "FUNKOT SIN PIJAMA", speed = 0.9 },
		{ id = "138171841183952", judul = "FUNKOT LAMUNAN", speed = 0.9 },
		{ id = "74808544918385", judul = "FUNKOT - DEWI", speed = 0.9 },
		{ id = "108277229733937", judul = "FUNKOT - CINTA PERTAMA", speed = 0.9 },
		{ id = "118724559390281", judul = "FUNKOT ULTRAMAN", speed = 0.9 },
		{ id = "136221920286430", judul = "FUNKOT APA KAU AMNESIA", speed = 0.9 },
		{ id = "118325434180290", judul = "FUNKOT PERGILAH KAU", speed = 0.9 },
		{ id = "90001934122818", judul = "FUNKOT DANDELIONS", speed = 0.9 },
		{ id = "136353140315860", judul = "FUNKOT KUTUKAN MANTAN", speed = 0.9 },
		{ id = "88656718093423", judul = "FUNKOT CINDERELLA", speed = 0.9 },
		{ id = "115182723152730", judul = "FUNKOT PIPI MIMI", speed = 0.9 },
		{ id = "88996971963655", judul = "FUNKOT Bukit Berbunga", speed = 0.7 },
	},

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

		for _, item in ipairs(list) do
			local idStr = tostring(item.id)
			local song = {
				id            = idStr,
				judul         = tostring(item.judul),
				album         = albumName,
				sampul        = item.sampul or cover,
				Duration      = item.Duration,
				PlaybackSpeed = item.PlaybackSpeed or item.speed or 1.0,
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
end

rebuildDatabase()

-- ==============================================================================
-- 4. PUBLIC API
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

-- Mengambil lagu berdasarkan album
function MusicModule:GetAlbumSongs(albumName, favoriteSongs)
	favoriteSongs = favoriteSongs or {}

	if albumName == "All Songs" then
		return MusicDatabase
	elseif albumName == "My Favorites" then
		local favorites = {}
		for _, favId in ipairs(favoriteSongs) do
			local music = self:GetMusicById(favId)
			if music then
				table.insert(favorites, music)
			end
		end
		return favorites
	else
		local songs = {}
		for _, music in ipairs(MusicDatabase) do
			if music.album == albumName then
				table.insert(songs, music)
			end
		end
		return songs
	end
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
