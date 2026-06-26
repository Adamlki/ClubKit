-- ====================================
-- MUSIC MODULE (EXAMPLE WITH PLAYBACK SPEED)
-- ====================================
local MusicModule = {}
-- ====================================
-- MUSIC DATABASE
-- Format:
-- {
--     id = "Music ID",
--     judul = "Song Title",
--     sampul = "Album Cover rbxassetid://...",
--     album = "Album Name",
--     Duration = seconds (number),
--     PlaybackSpeed = 1.0 (default, range 0.5 - 2.0)
-- }
-- ====================================

local MusicDatabase = {
	-- ==========================================
	-- PLAYLIST 1
	-- ==========================================
	{
		id = "125123785197681",
		judul = "Imagine Dragons - Believer",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
        id = "115176297102556",
        judul = "PLAY – ALAN WALKER, K-391, TUNGEVAAG, MANGOO",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
	{
		id = "80645766074424", 
		judul = "LANY - You", 
		sampul = "rbxassetid://110370706778065", 
		album = "PLAYLIST 1", 
		Duration = nil, 
		PlaybackSpeed = 0.7,
		PitchOctave = 1.1
	},
	{
		id = "81257869135562",
		judul = "LANY - 'Cause You Have To",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 1",
		Duration = nil,
		PlaybackSpeed = 0.7,
		PitchOctave = 1.1
	},
	{
		id = "125816766946068",
		judul = "LANY - 13",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 1",
		Duration = nil,
		PlaybackSpeed = 0.7,
		PitchOctave = 1.1
	},
	{
		id = "85428778844636",
		judul = "LANY - Super Far",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 1",
		Duration = nil,
		PlaybackSpeed = 0.7,
		PitchOctave = 1.1
	},
	{
		id = "114204415546617",
		judul = "LANY - XXL",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 1",
		Duration = nil,
		PlaybackSpeed = 0.7,
		PitchOctave = 1.1
	},
	{
		id = "75331949790916",
		judul = "LANY - Thru These Tears",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 1",
		Duration = nil,
		PlaybackSpeed = 0.7,
		PitchOctave = 1.1
	},
	{
		id = "108268996390872",
		judul = "LANY - anything 4 u",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 1",
		Duration = nil,
		PlaybackSpeed = 0.7,
		PitchOctave = 1.1
	},
	{
		id = "91656074831192",
		judul = "LANY - Thick And Thin",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 1",
		Duration = nil,
		PlaybackSpeed = 0.7,
		PitchOctave = 1.1
	},
	{
		id = "110595139107215",
		judul = "The Weeknd - Blinding Lights",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 1",
		Duration = nil,
		PlaybackSpeed = 0.7,
		PitchOctave = 1.1
	},
	{
		id = "90343504797110",
		judul = "The Weeknd - Save Your Tears",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 1",
		Duration = nil,
		PlaybackSpeed = 0.7,
		PitchOctave = 1.1
	},
	{
		id = "79527978829243",
		judul = "The Weeknd - Hardest To Love",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 1",
		Duration = nil,
		PlaybackSpeed = 0.7,
		PitchOctave = 1.1
	},
	{
		id = "88854879737198",
		judul = "The Weeknd - Moth To A Flame",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 1",
		Duration = nil,
		PlaybackSpeed = 0.7,
		PitchOctave = 1.1
	},
	{
		id = "103253348115248",
		judul = "DJ Obh Combi Sachet",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 1",
		Duration = nil,
		PlaybackSpeed = 1,
		PitchOctave = 1
	},
	{
        id = "130297969168941",
        judul = "8 LETTERS – WHY DON'T WE (R3HAB REMIX)",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
	{
        id = "135526164745515",
        judul = "A Little Piece of Heaven - Avenged Sevenfold",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "135836231614223",
        judul = "A SKY FULL OF STARS - COLDPLAY",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "106624023362146",
        judul = "A THOUSAND YEARS - CHIRSTINA PERRI",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "118707946823603",
        judul = "ABOUT YOU X MULTO X BACK TO FRIENDS X PAYPHONE X WHERE WE ARE – MASHUP",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "86710490431507",
        judul = "ALAN WALKER, SABRINA CARPENTER, FARRUKO - ON MY WAY",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "114867023056058",
        judul = "ALL OF ME REMIX – JOHN LEGEND",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "75155361233643",
        judul = "MARSHMALLOW ALONE",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "82412473170633",
        judul = "ANGEL BABY – TROYE SIVAN",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "120201147209026",
        judul = "ANGELS LIKE YOU – MILEY CYRUS",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "88385976833537",
        judul = "ANIMALS - MAROON 5",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "80950769201112",
        judul = "ANIMALS - MARTIN GARIX",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "117876919570667",
        judul = "APT - ROSE X BRUNO MARS",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "112129515270393",
        judul = "ARIANA GRANDE - WE CAN'T BE FRIENDS",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "76481523653289",
        judul = "BACK TO FRIENDS",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "76163143897061",
        judul = "BAD ROMANCE – LADY GAGA",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "134081121981319",
        judul = "BE KIND WITH HALSEY",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "108562268357287",
        judul = "BE WITH YOU - AKON",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "75772290043987",
        judul = "BEAUTIFUL THINGS – BENSON BOONE",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "110039425060700",
        judul = "BEAUTIFUL – AKON",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "115618759275696",
        judul = "BILLIE EILISH, KHALID - LOVELY",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "104767488760702",
        judul = "BIRDS OF A FEATHER – BILLIE EILISH",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "111364073728189",
        judul = "BLACK FRIDAY (PRETTY LIKE THE SUN) – TOM ODELL",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "75397349278251",
        judul = "BOO",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "103574160857676",
        judul = "BREAKING ME – TOPIC, A7S",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "100419866459447",
        judul = "BROKEN ANGEL – ARASH FT. HELENA",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "71354152693034",
        judul = "CALL ME MAYBE – CARLY RAE JEPSEN",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "76710762392097",
        judul = "CALM DOWN – REMA & SELENA GOMEZ",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "113103219499546",
        judul = "CASH CASH, CHRISTINA PERRI - HERO",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "136243393861624",
        judul = "CHEERLEADER - FELIX JAEHN REMIX",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "78868972793897",
        judul = "CIRCLES – POST MALONE",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "105685615777196",
        judul = "CLARITY (FEAT. FOXES) - TIËSTO REMIX",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "124490599120948",
        judul = "COLD HEART REMIX – ELTON JOHN & DUA LIPA",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "132580829371558",
        judul = "COMETHRU – JEREMY ZUCKER",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "77191434117702",
        judul = "DANCE MONKEY – TONES AND I",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "97295641373432",
        judul = "DANCIN (KRONO REMIX) – AARON SMITH",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "111932673797078",
        judul = "DEAR GOD - OVENGED SEVENFOLD",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "123522108128356",
        judul = "DIE ON THIS HILL",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "108347186300519",
        judul = "DISCO LINES, TINASHE - NO BROKE BOYS",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "125515758303190",
        judul = "DON’T WAKE ME UP – CHRIS BROWN",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "116008232879857",
        judul = "DON'T LET ME DOWN – THE CHAINSMOKERS FT. DAYA",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "104897004079874",
        judul = "ECHOS OF YOU",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "81936058100631",
        judul = "ELECTRIC PULSE",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "97163339936875",
        judul = "END OF BEGINNING – DJO",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "130052617394144",
        judul = "FADED X ON MY WAY – ALAN WALKER",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "113331925685981",
        judul = "FLOWERS – MILEY CYRUS",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "129532965484353",
        judul = "FOLDED",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "136386314734452",
        judul = "GABRIELA",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "110408895359055",
        judul = "GIVE ME PROMISCUOUS",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "109784356096479",
        judul = "GOOD FOR YOU X ONE OF THE GIRLS – MASHUP",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "125908891850336",
        judul = "GOT 2 LUV U (FEAT. ALEXIS JORDAN)",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "136468126776022",
        judul = "GRENADE – BRUNO MARS",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "86310599989139",
        judul = "HAVANA (FEAT. YOUNG THUG)",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "108289817034775",
        judul = "HEART ATTACK – DEMI LOVATO",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "98363905347954",
        judul = "HEAVEN (FEAT. VERONICA)",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "123704675912072",
        judul = "HERE WITH ME",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "113787130702257",
        judul = "HEY DADDY – USHER",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "96449076197214",
        judul = "HOW TO LOVE",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "134205820435230",
        judul = "I ADORE YOU – HUGEL, TOPIC, ARASH FT. DAECOLM",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "92766256407674",
        judul = "I LOVE YOU 3000 – STEPHANIE POETRI",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "120744720669681",
        judul = "I LOVE YOU BABY",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "140259186765615",
        judul = "I'M GOOD (BLUE) – DAVID GUETTA & BEBE REXHA",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "137968836209429",
        judul = "IT WILL RAIN – BRUNO MARS",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "128038120486261",
        judul = "JUDAS – LADY GAGA",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "138701140784343",
        judul = "JJUST THE WAY YOU ARE – BRUNO MARS",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "106909634491777",
        judul = "KAVKAZ",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "82850087585121",
        judul = "KING - OLLY ALEXANDER",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "126820480532864",
        judul = "KREEPEEK - PLAYBOY CAPTIKUS",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "81179715579017",
        judul = "LA LA LA - SAM SMITH",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "72872586126510",
        judul = "LADY GAGA, BRUNO MARS - DIE WITH A SMILE",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "105356784057959",
        judul = "LET ME GO",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "105356784057959",
        judul = "LET ME LOVE YOU",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "124273394563221",
        judul = "LIKE A G6",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "127952719429116",
        judul = "LOCKED OUT OF HEAVEN – BRUNO MARS",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "111730125544993",
        judul = "LOCO LOCO",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "104494409838301",
        judul = "LONELY TOGETHER (FEAT. RITA ORA)",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "107132859576786",
        judul = "LOWKEY – NIKI",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "91094865742672",
        judul = "MIDNIGHT DRIFT",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "85557439758541",
        judul = "MINEFIELDS – FAOUZIA & JOHN LEGEND",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "125367020013519",
        judul = "MOVE SHAKE DROP REMIX",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "91232020298385",
        judul = "MOVE",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "77948159247642",
        judul = "MR. MASH - SHOW ME LOVE X TAKE MY MIND",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "113388277798336",
        judul = "MY LECON – JTL",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "86657279243652",
        judul = "NEW RULES – DUA LIPA",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "105872940876117",
        judul = "NEW THANG – REDFOO",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "112980607009086",
        judul = "NEW",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "108551997352945",
        judul = "ON THE FLOOR – JENNIFER LOPEZ FT. PITBULL",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "99451155839906",
        judul = "ONE KISS – CALVIN HARRIS, DUA LIPA",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "120242668500492",
        judul = "ONE LAST TIME – ARIANA GRANDE",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "101461802776311",
        judul = "OURS TO KEEP",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "119175673559680",
        judul = "PAMUNGKAS - TO THE BONE",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "100088955665842",
        judul = "PARADISE – COLDPLAY",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "97943855355420",
        judul = "PEDRO CAPÓ, FARRUKO - CALMA - REMIX",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "112959868112214",
        judul = "PEOPLE X NAINOWALE NE – MASHUP",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "77732973664319",
        judul = "PEPAS – FARRUKO",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "121951263594456",
        judul = "PERFECT STRANGERS – JONAS BLUE FT. JP COOPER",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "89324491525255",
        judul = "PIECE OF YOUR HEART – MEDUZA FT. GOODBOYS",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "107665349275172",
        judul = "PLAY DATE – MELANIE MARTINEZ",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },

    {
        id = "109772207477202",
        judul = "POKER FACE – LADY GAGA",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "125684824756669",
        judul = "PROBLEM – ARIANA GRANDE FT. IGGY AZALEA",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "127501241986742",
        judul = "RAINDANCE",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "91774244679990",
        judul = "RAVYN LENAE - LOVE ME NOT",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "114766541542426",
        judul = "RECKLESS – MADISON BEER",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "105998406558060",
        judul = "REMEDY – ALESSO",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "98081128739374",
        judul = "REWRITE THE STARS – ANNE-MARIE & JAMES ARTHUR",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "92415708768255",
        judul = "RIGHT NOW - ONE DIRECTION",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "91148392716357",
        judul = "RISK IT ALL",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "75339874792375",
        judul = "RUNAWAY – AURORA",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "120773918360330",
        judul = "SABRINA , ARIANA GRANDE, BRUNO MARS, DUA LIPA",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "90526547684814",
        judul = "SAY IT RIGHT",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "127820824110491",
        judul = "SEÑORITA – SHAWN MENDES & CAMILA CABELLO",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "92149803401258",
        judul = "SHAPE OF YOU – ED SHEERAN",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "133473613368715",
        judul = "SHOW MUST GO ON - EXTENDED VERSION",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "138864395279071",
        judul = "SNOWMAN – SIA",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "127243151671199",
        judul = "SO AM I – AVA MAX",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "127253957435246",
        judul = "SOMEBODY ELSE – THE 1975",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "139979234540336",
        judul = "SOMEBODY'S PLEASURE – AZIZ HEDRA",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "79074920741055",
        judul = "SOS (FEAT. ALOE BLACC) – AVICII",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "120103883068855",
        judul = "STAY THE NIGHT - HAYLEY WILLIAMS",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "138507593317414",
        judul = "STEREO LOVE X ON THE FLOOR – MASHUP",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "90223963339679",
        judul = "SUBEME LA RADIO – ENRIQUE IGLESIAS",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "127190824807077",
        judul = "SUMMERTIME SADNESS – LANA DEL REY",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "98075070321023",
        judul = "SWALLA (FEAT. NICKI MINAJ & TY DOLLA $IGN)",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "130884823962160",
        judul = "SYMPHONY (FEAT. ZARA LARSSON)",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "111641221274652",
        judul = "SNOOZE – SZA",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "105485375154471",
        judul = "SI AI - MARSHMELLO & UKAY REMIX",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "105496338924620",
        judul = "THAT'S WHAT I LIKE – BRUNO MARS",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "112142773667595",
        judul = "THE DRUM – ALAN WALKER",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "116305308141457",
        judul = "TTHE ONE THAT GOT AWAY – KATY PERRY",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "124743287070864",
        judul = "THE WEEKND, DAFT PUNK - STARBOY",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "106187846125118",
        judul = "THIS IS MY LIFE – EDWARD MAYA & VIKA JIGULINA",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "100863332990614",
        judul = "TITANIUM (FEAT. SIA)",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "106505255681358",
        judul = "TWERK IT LIKE MILEY – BRANDON BEAL",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "94946333921248",
        judul = "UMBRELLA – RIHANNA FT. JAY-Z",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "137263185225497",
        judul = "UNFORGETTABLE X I FOUND YOU – MASHUP",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "109276294743783",
        judul = "VIVA LA VIDA – COLDPLAY",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "121692728020654",
        judul = "VOODOO",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "130921831987405",
        judul = "WALK THRU FIRE – VICETONE",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "82450453986504",
        judul = "WE FOUND LOVE – RIHANNA FT. CALVIN HARRIS",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "98535582322176",
        judul = "WHEN I WAS YOUR MAN – BRUNO MARS",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "97445520020992",
        judul = "WHERE WE ARE X ONE THING X SNAP X GHOST X STRONG",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "92209677429610",
        judul = "WHO'S THAT GIRL – EVE",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "71081612062106",
        judul = "YELLOW – COLDPLAY",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "102820354876163",
        judul = "YOU & ME - RIVO REMIX",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "98930856288321",
        judul = "YOUR LOVE (9PM) – ATB, TOPIC, A7S",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "135584481560737",
        judul = "THE LOTUS OF LIFE",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "134093385271929",
        judul = "WONDER - KATY PERRY",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "78094230170963",
        judul = "ABOUT YOU - THE 1975",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "136777117439065",
        judul = "MERRY CHRISTMAS PLEASE DONT CALL",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },
    {
        id = "120471463875349",
        judul = "ALL WE KNOW - THE CHAINSMOKERS",
        sampul = "rbxassetid://110370706778065",
        album = "PLAYLIST 1",
        Duration = nil,
        PlaybackSpeed = 0.43,
    },

	-- ==========================================
	-- FUNKOT STYLE
	-- ==========================================
	{
		id = "71330340665281", 
		judul = "FUNKOT DAMON VACATION X TERENA METE X TOLONG PA NGANA", 
		sampul = "rbxassetid://110370706778065", 
		album = "FUNKOT STYLE", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "84169167680157", 
		judul = "FUNKOT STECU STECU", 
		sampul = "rbxassetid://110370706778065", 
		album = "FUNKOT STYLE", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "119604195746368", 
		judul = "FUNKOT APA KABAR SAYANG", 
		sampul = "rbxassetid://110370706778065", 
		album = "FUNKOT STYLE", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "80812080448807", 
		judul = "FUNKOT DI UJUNG JALAN", 
		sampul = "rbxassetid://110370706778065", 
		album = "FUNKOT STYLE", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "72612522452910", 
		judul = "FUNKOT DUKA", 
		sampul = "rbxassetid://110370706778065", 
		album = "FUNKOT STYLE", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "74948645966301", 
		judul = "FUNKOT KOPLO TIE ME DOWN", 
		sampul = "rbxassetid://110370706778065", 
		album = "FUNKOT STYLE", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "85845230173199", 
		judul = "FUNKOT SUMPAH DAN CINTA MATIKU", 
		sampul = "rbxassetid://110370706778065", 
		album = "FUNKOT STYLE", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "74457406744934", 
		judul = "FUNKOT SUMPAH DAN CINTA MATIKU - NIDJI", 
		sampul = "rbxassetid://110370706778065", 
		album = "FUNKOT STYLE", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "118944211081297", 
		judul = "FUNKOT SIN PIJAMA", 
		sampul = "rbxassetid://110370706778065", 
		album = "FUNKOT STYLE", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "138171841183952", 
		judul = "FUNKOT LAMUNAN", 
		sampul = "rbxassetid://110370706778065", 
		album = "FUNKOT STYLE", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "74808544918385", 
		judul = "FUNKOT - DEWI", 
		sampul = "rbxassetid://110370706778065", 
		album = "FUNKOT STYLE", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "108277229733937", 
		judul = "FUNKOT - CINTA PERTAMA", 
		sampul = "rbxassetid://110370706778065", 
		album = "FUNKOT STYLE", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "118724559390281", 
		judul = "FUNKOT ULTRAMAN", 
		sampul = "rbxassetid://110370706778065", 
		album = "FUNKOT STYLE", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "136221920286430", 
		judul = "FUNKOT APA KAU AMNESIA", 
		sampul = "rbxassetid://110370706778065", 
		album = "FUNKOT STYLE", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "118325434180290", 
		judul = "FUNKOT PERGILAH KAU", 
		sampul = "rbxassetid://110370706778065", 
		album = "FUNKOT STYLE", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "90001934122818", 
		judul = "FUNKOT DANDELIONS", 
		sampul = "rbxassetid://110370706778065", 
		album = "FUNKOT STYLE", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "136353140315860", 
		judul = "FUNKOT KUTUKAN MANTAN", 
		sampul = "rbxassetid://110370706778065", 
		album = "FUNKOT STYLE", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "88656718093423", 
		judul = "FUNKOT CINDERELLA", 
		sampul = "rbxassetid://110370706778065", 
		album = "FUNKOT STYLE", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "115182723152730", 
		judul = "FUNKOT PIPI MIMI", 
		sampul = "rbxassetid://110370706778065", 
		album = "FUNKOT STYLE", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "88996971963655",
		judul = "FUNKOT Bukit Berbunga",
		sampul = "rbxassetid://110370706778065",
		album = "FUNKOT STYLE",
		Duration = nil,
		PlaybackSpeed = 0.7,
		PitchOctave = 1
	},
	-- ==========================================
	-- PLAYLIST 2
	-- ==========================================
	{
		id = "135795407885794",
		judul = "Pháo, KAIZ - 2 Phút Hơn Remix",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "92468072812953",
		judul = "Bruno Mars - 24K Magic",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "131860408757649",
		judul = "Anne-Marie - 2002",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "93938313289251",
		judul = "GAYLE - abcdefu",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "89413148053463",
		judul = "Sevdaliza, Pabllo Vittar & Yseult - Alibi",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "79199056601515",
		judul = "R3HAB, A Touch Of Class - All Around The World (La La La)",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "136310156670653",
		judul = "Stromae - Alors on danse",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "125893868282095",
		judul = "Lost Frequencies - Are You With Me",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "76677555900708",
		judul = "Charlie Puth - Attention",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "74131453664281",
		judul = "David Guetta, Showtek, Vassy - Bad",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "81694583241745",
		judul = "Marwa Loud - Bad boy",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "107285610587671",
		judul = "Akon - Bananza",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "131065141071279",
		judul = "Justin Bieber, Nicki Minaj - Beauty And A Beat",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "79687467158508",
		judul = "Måneskin - Beggin'",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "133146123343770",
		judul = "Billie Eilish - BIRDS OF A FEATHER",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "114636926813110",
		judul = "Armin van Buuren - Blah Blah Blah",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
		{
		id = "90820821099719", 
		judul = "When I Close My Eyes", 
		sampul = "rbxassetid://110370706778065", 
		album = "PLAYLIST 1", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "104300829677999",
		judul = "BLACKPINK - BOOMBAYAH",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "108888658191229",
		judul = "Showtek, We Are Loud!, Sonny Wilson - Booyah",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "122025536435298",
		judul = "The Pussycat Dolls - Britney Spears - Toxic",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "73665690002977",
		judul = "The Pussycat Dolls - Buttons",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "71221346799208",
		judul = "Ariana Grande - bye",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "106342934544489",
		judul = "Brazilian FunkClub - C'est La Vie x Danza Kuduro",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "108352233540521",
		judul = "Akon - Chammak Challo - Remix",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "117675790545248",
		judul = "KSHMR, Tungevaag - Close Your Eyes",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "78867975994669",
		judul = "Aya Nakamura - Copines",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "108785504161409",
		judul = "OneRepublic - Counting Stars",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "134713114726890",
		judul = "BLACKPINK - DDU-DU DDU-DU",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "113889055026850",
		judul = "Imagine Dragons - Demons",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "87689294214968",
		judul = "David Guetta, OneRepublic - I Don't Wanna Wait",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "91495388196704",
		judul = "Pia Mia, Chris Brown, Tyga - Do It Again",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "113417336172764",
		judul = "фрози, Mwizz, Genjutsu - Don't Copy My Flow",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "140138779696457",
		judul = "BTS - Dynamite",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "86960197883937",
		judul = "Ariana Grande, Future - Everyday",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "83934692312609",
		judul = "Klaas, Ruiz - Feel Only Love",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "126621356371339",
		judul = "Hartzon - Finally Found You",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "138127404702087",
		judul = "Jessie J - Flashlight",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "134624356708618",
		judul = "Marshmello - Freal Luv",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "129107676016959",
		judul = "FloyyMenor, Cris MJ - Gata Only",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "90601105931989",
		judul = "Dillon Francis, DJ Snake - Get Low",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "82060958562272",
		judul = "HUNTR; X, EJAE, A... - Golden",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "107767305268529",
		judul = "Ciara, Petey Pablo - Goodies",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "98147104512562",
		judul = "Tate McRae - greedy",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "81263444217113",
		judul = "Habibi - Albanian Remix",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "103840020435749",
		judul = "Tove Lo - Habits (Stay High)",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "132154108438718",
		judul = "Bring Me The Horizon - Happy Song",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "124675013865789",
		judul = "Katy Perry - Harleys In Hawaii",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "70898523747613",
		judul = "Twenty One Pilots - Heathens",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "109723738485957",
		judul = "Skate Avenue PH - Heaven Knows - Rock Version",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "72864385602930",
		judul = "Jamie Miller - Here's Your Perfect",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "79709779328321",
		judul = "Alesso, Tove Lo - Heroes",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "82274185214832",
		judul = "David Guetta - Hey Mama",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "123458185325843",
		judul = "Pitbull - Hotel Room Service",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "136836238237170",
		judul = "Calvin Harris, Disciples - How Deep Is Your Love",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "134545309462305",
		judul = "BLACKPINK - How You Like That",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "105195558549406",
		judul = "Mike Posner, Seeb - I Took A Pill In Ibiza Remix",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "103339124039240",
		judul = "Yung Bleu - Ice On My Baby",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "87441043469057",
		judul = "LANY - ILYSB",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "93630643546248",
		judul = "Ariana Grande - Into You",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "78154150613249",
		judul = "SZA - Kill Bill",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "89862250114655",
		judul = "Ava Max - Kings & Queens",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "108291097685032",
		judul = "фрози - kompa pasión",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "110015473458051",
		judul = "Oxlade, Camila Cabello - KU LO SA",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "95637289581190",
		judul = "Shoti - LDR",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "134438776774682",
		judul = "Marshmello - Leave Before You Love Me",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "126438002057380",
		judul = "Charlie Puth, Jung Kook - Left and Right",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "110904377974946",
		judul = "Legends Never Die",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "131704814792697",
		judul = "Major Lazer, Nyla, Fuse ODG - Light It Up",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "131549896252527",
		judul = "CKay - love nwantiti (ah ah ah)",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "115457254610416",
		judul = "Selena Gomez - Love You Like A Love",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "111588768397709",
		judul = "Chris Brown, Lil Wayne, Tyga - Loyal",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "124046651866950",
		judul = "Bruno Mars - Marry You",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "137907107069486",
		judul = "Charlie Puth, Meghan Trainor - Marvin Gaye",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "96613254746235",
		judul = "LAUV, LANY - Mean It",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "72854957009054",
		judul = "J Balvin, Willy William - Mi Gente",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "136946747325299",
		judul = "Elley Duhé - MIDDLE OF THE NIGHT",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "132566446773108",
		judul = "Zara Larsson, MNEK - Never Forget You",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "128653944005919",
		judul = "One Direction - Night Changes",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "135378155849460",
		judul = "Cheat Codes, Demi Lovato - No Promises",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "109701211202500",
		judul = "Billie Eilish - ocean eyes",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "130642128558293",
		judul = "SONIC MUSIC - Oh Carol",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "137295547488017",
		judul = "Panca Borneo - Oh Honey",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "93538889308082",
		judul = "Drake, Wizkid, Kyla - One Dance",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "103286010107622",
		judul = "brux XTN - Paid to Exist",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "140306512922811",
		judul = "Nej - Paro",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "139576926179266",
		judul = "Midas the Jagaban - Party With A Jagaban",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "98833666197021",
		judul = "MEDUZA, Goodboys - Piece Of Your Heart",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "135588377901671",
		judul = "The Weeknd, Playboi Carti, Madonna - Popular",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "106495801273248",
		judul = "Moises Roswick Funes - Pota Pota Dance",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "81741065689787",
		judul = "Jessie J, B.o.B - Price Tag",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "109614975278095",
		judul = "CARYS - Princesses Don't Cry",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "88494769050919",
		judul = "AYA MUSIC OFC - Right Here Waiting",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "83159765059740",
		judul = "Faouzia - RIP, Love",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "105706387589913",
		judul = "Jonas Blue, Jack & Jack - Rise",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "76519714870465",
		judul = "Tiësto, Jonas Blue, Rita Ora - Ritual",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "137680040969651",
		judul = "Egzod, Maestro Chives, Neoni - Royalty",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "131074215208180",
		judul = "Serena - Safari",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "117458096748479",
		judul = "Jawsh 685, Jason Derulo - Savage Love",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "97457350813607",
		judul = "Jamrud - Selamat Ulang Tahun",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "86004684164028",
		judul = "Set Me Free - Remix",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "83788786716314",
		judul = "Camila Cabello - Shameless",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "73865424123139",
		judul = "Ed Sheeran - Shape of You",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "132743768759903",
		judul = "David Guetta - Shot Me Down",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "122702989213439",
		judul = "Yellow Claw, Rochelle - Shotgun",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "116894496750750",
		judul = "Becky G, NATTI NATASHA - Sin Pijama",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "82563787929925",
		judul = "Adele - Skyfall",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "116459335836138",
		judul = "Olivia Dean - So Easy",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "91219873450152",
		judul = "Clean Bandit, Demi Lovato - Solo",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "91219873450152",
		judul = "JENNIE - SOLO",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "78839686821546",
		judul = "Bex - Suffer",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "97078465128999",
		judul = "Ava Max - Sweet but Psycho",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "124311613473622",
		judul = "Loreen - Tattoo",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "113860168113794",
		judul = "Gracie Abrams - That's So True",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "116745405722166",
		judul = "Taylor Swift - The Fate of Ophelia",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "93102288583928",
		judul = "The Script - The Man Who Can't Be Moved",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "81471413597387",
		judul = "Alan Walker - The Spectre",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "82207261138166",
		judul = "Lil Uzi Vert, Oh Wonder - The Way Life Goes",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "72367734251635",
		judul = "Kungs, Cookin' On 3 Burners - This Girl",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "119446093391173",
		judul = "Calvin Harris, Rihanna - This Is What You Came For",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "83975041678547",
		judul = "David Guetta, Zara Larsson - This One's for You",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "121433160488697",
		judul = "ONE OR EIGHT - TOKYO DRIFT",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "103408496298570",
		judul = "Britney Spears - Toxic",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "105382993159808",
		judul = "Shawn Mendes - Treat You Better",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "75209909311906",
		judul = "DVBBS, Borgeous - Tsunami",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "104291020165931",
		judul = "Chris Brown - Under The Influence",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "70426699815547",
		judul = "Shakira - Waka Waka",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "128970373926931",
		judul = "Silentó - Watch Me",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "137845708453815",
		judul = "Tyla - Water",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "83892102648898",
		judul = "One Direction - What Makes You Beautiful",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "101442802984639",
		judul = "Jack Ü, Skrillex, Diplo, Justin Bieber - Where Are Ü Now",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "79492561657062",
		judul = "Billie Eilish - WILDFLOWER",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "115212459657917",
		judul = "Halsey - Without Me",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "125679714008079",
		judul = "Doja Cat - Woman",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "138571607129198",
		judul = "Fifth Harmony, Ty Dolla $ign - Work from Home",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "94946211178327",
		judul = "NIKI - You'll Be in My Heart",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "131996827933861",
		judul = "Khalid - Young Dumb & Broke",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "74868175074141",
		judul = "Ikimonogakari - ブルーバード",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "127766894928897",
		judul = "Juepak, จ๊ะ นงผณี, G... - เมร่อน",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	{
		id = "77707571119066",
		judul = "Baimint, GUNNER - จ๊าบของแท้ - GUNNER Remix",
		sampul = "rbxassetid://110370706778065",
		album = "PLAYLIST 2",
		Duration = nil,
		PlaybackSpeed = 0.43
	},
	-- ==========================================
	-- THAILAND STYLE
	-- ==========================================
	{
		id = "108408071718050", 
		judul = "THAILAND STYLE Kehlani Folded", 
		sampul = "rbxassetid://110370706778065", 
		album = "THAILAND STYLE", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "100938032342972", 
		judul = "THAILAND STYLE Bye", 
		sampul = "rbxassetid://110370706778065", 
		album = "THAILAND STYLE", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "89699825050196", 
		judul = "THAILAND STYLE Toton Caribo Ora Urus", 
		sampul = "rbxassetid://110370706778065", 
		album = "THAILAND STYLE", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "125321559827165", 
		judul = "THAILAND STYLE Shae Sayang", 
		sampul = "rbxassetid://110370706778065", 
		album = "THAILAND STYLE", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "115992008938120", 
		judul = "THAILAND STYLE Dia _ Tenxi Sency", 
		sampul = "rbxassetid://110370706778065", 
		album = "THAILAND STYLE", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "72938763435547", 
		judul = "THAILAND STYLE Natasya Sabella Menerima Luka", 
		sampul = "rbxassetid://110370706778065", 
		album = "THAILAND STYLE", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "98149105037050", 
		judul = "THAILAND STYLE Pata Pata", 
		sampul = "rbxassetid://110370706778065", 
		album = "THAILAND STYLE", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "110302481017671", 
		judul = "THAILAND STYLE Glenn Fredly Januari", 
		sampul = "rbxassetid://110370706778065", 
		album = "THAILAND STYLE", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "121528010781939", 
		judul = "THAILAND STYLE Body Pata Pata X Stecu Stecu", 
		sampul = "rbxassetid://110370706778065", 
		album = "THAILAND STYLE", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "84496427560934", 
		judul = "THAILAND STYLE Curi Curi Pandang", 
		sampul = "rbxassetid://110370706778065", 
		album = "THAILAND STYLE", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "83679436916114", 
		judul = "THAILAND STYLE Toton Caribo Ngapain Repot", 
		sampul = "rbxassetid://110370706778065", 
		album = "THAILAND STYLE", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "81346766136527", 
		judul = "THAILAND STYLE Perunggu “33x”", 
		sampul = "rbxassetid://110370706778065", 
		album = "THAILAND STYLE", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "102786064793133", 
		judul = "THAILAND STYLE Izanor Alveiro “Ade Su Nikah”", 
		sampul = "rbxassetid://110370706778065", 
		album = "THAILAND STYLE", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "137274500408453", 
		judul = "THAILAND STYLE Lina Lady Geboy ”Jarang Pulang”", 
		sampul = "rbxassetid://110370706778065", 
		album = "THAILAND STYLE", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "139010273504520", 
		judul = "THAILAND STYLE Kasih Aba-Aba", 
		sampul = "rbxassetid://110370706778065", 
		album = "THAILAND STYLE", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "85115877260374", 
		judul = "THAILAND STYLE Lolita ”Alay”", 
		sampul = "rbxassetid://110370706778065", 
		album = "THAILAND STYLE", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "98509262574700", 
		judul = "THAILAND STYLE ndx aka - ”tresno tekan mati”", 
		sampul = "rbxassetid://110370706778065", 
		album = "THAILAND STYLE", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "87704203254983", 
		judul = "THAILAND STYLE garam dan madu", 
		sampul = "rbxassetid://110370706778065", 
		album = "THAILAND STYLE", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "108394196769796", 
		judul = "THAILAND STYLE DITINGGAL RABI X SEWATES KONCO", 
		sampul = "rbxassetid://110370706778065", 
		album = "THAILAND STYLE", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "71538060113255", 
		judul = "THAILAND STYLE KICAU MANIA", 
		sampul = "rbxassetid://110370706778065", 
		album = "THAILAND STYLE", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "93989503395575", 
		judul = "THAILAND STYLE Kangen Band Nilailah Aku", 
		sampul = "rbxassetid://110370706778065", 
		album = "THAILAND STYLE", 
		Duration = nil, 
		PlaybackSpeed = 1.0
	},
	{
		id = "97419595340862",
		judul = "hold on thailand edit",
		sampul = "rbxassetid://110370706778065",
		album = "THAILAND STYLE",
		Duration = nil,
		PlaybackSpeed = 0.7,
		PitchOctave = 1
	},
	{
		id = "124885931890954",
		judul = "Armada Mabuk Cinta - Thailand Edit",
		sampul = "rbxassetid://110370706778065",
		album = "THAILAND STYLE",
		Duration = nil,
		PlaybackSpeed = 0.7,
		PitchOctave = 1
	},
	{
		id = "107402047715247",
		judul = "Shine Of Black Jang Ganggu - Thailand Edit",
		sampul = "rbxassetid://110370706778065",
		album = "THAILAND STYLE",
		Duration = nil,
		PlaybackSpeed = 0.7,
		PitchOctave = 1
	},
	{
		id = "78758780594659",
		judul = "Goyang Dumang X Hold On - Thailand Edit",
		sampul = "rbxassetid://110370706778065",
		album = "THAILAND STYLE",
		Duration = nil,
		PlaybackSpeed = 0.7,
		PitchOctave = 1
	},

	-- ==========================================
	-- BREAKBEAT
	-- ==========================================
	{
		id = "105498304144504", 
		judul = "BREAKBEAT BAILAR BLACK HOLE", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "103475221920430", 
		judul = "BREAKBEAT TANPA CINTA", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "94090915796948", 
		judul = "AKON - BEAUTIFUL", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "122253866454061", 
		judul = "BREAKBEAT POMPEII", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "74647900745715", 
		judul = "Dj If It Wasn't For You Alesso Breakbeat", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "135337259541231", 
		judul = "BREAKBEAT GLADE YOU CAME", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "71423184999824", 
		judul = "WAITING STADIUM BREAKBEAT", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "122502605906661", 
		judul = "ATLANTIS STADIUM BREAKBEAT", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "120915132243496", 
		judul = "BREAKBEAT SUN AND MOON", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "98756748818407", 
		judul = "BREAKBEAT THE SECOND YOU SLEEP", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "73599587113479", 
		judul = "BREAKBEAT CANT STOP LOVING YOU", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "126643849808708", 
		judul = "BREAKBEAT CLOSE YOUR EYES", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "96368504905727", 
		judul = "BREAKBEAT JANGAN TUNGGU LAMA LAMA", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "102625381230369", 
		judul = "BREAKBEAT THE FATE OF OPHRLIA", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "78930738470270", 
		judul = "BREAKBEAT TANTE TANTE CULIK AKU DONG", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "118231341943264", 
		judul = "BREAKBEAT REMIX SEAN - PAUL SHE DOESN'T MIND", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "100134393792281", 
		judul = "BREAKBEAT LAROXX - PROJECT DON'T CRY MY LOVE", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "109256791527622", 
		judul = "BREAKBEAT GIRLS GENERATIONSNSD - OH", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "117023580399391", 
		judul = "BREAKBEAT PROGRESSIVE DORA DORA X BRAND NEW DAY", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "138394176444816", 
		judul = "BREAKBEAT Ciperi Pam Pam", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "121353060114685", 
		judul = "BREAKBEAT Horizon", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "84529855617994", 
		judul = "BREAKBEAT ROSSA - TAK SANGGUP LAGI", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "103113810859462", 
		judul = "BREAKBEAT I NEED A DOCTOR", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "132091575381190", 
		judul = "BREAKBEAT WHERE DO WE BEGIN", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "97255165323923", 
		judul = "BREAKBEAT DRIVE", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "90153230363269", 
		judul = "BREAKBEAT EVERYTHING I NEED", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "122128659091503", 
		judul = "BREAKBEAT FEELS LIKE HOME", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "86321979672906", 
		judul = "BREAKBEAT HEARTBREAKING", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "111268716383584", 
		judul = "BREAKBEAT MAN ON THE RUN", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "135645023276954", 
		judul = "BREAKBEAT THIS I VOW", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "103558212918173", 
		judul = "BREAKBEAT RAMELIA", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "134282782367630", 
		judul = "BREAKBEAT BE AS ONE", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "128362773204435", 
		judul = "BREAKBEAT TILL THE SKY FALLS DOWN", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "110184593820416", 
		judul = "BREAKBEAT BEAUTIFUL LIE", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "84605967471172", 
		judul = "BREAKBEAT FREEFALL", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "123124685248155", 
		judul = "BREAKBEAT Put Your Hands Up", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "135604099859125", 
		judul = "BREAKBEAT Better Off Alone", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "138840603572468", 
		judul = "BREAKBEAT I Got U", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "102869498075580", 
		judul = "BREAKBEAT Hanya Ingin Kau Tau", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "111809764403727", 
		judul = "BREAKBEAT Just Another Night", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "108888809665815", 
		judul = "BREAKBEAT You're My Angel", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "103616711888221", 
		judul = "BREAKBEAT Plastic", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "139640669049168", 
		judul = "BREAKBEAT Shadow",
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "137399827851381", 
		judul = "BREAKBEAT IN AND OUT OF LOVE", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "104128642039869", 
		judul = "BREAKBEAT Aku Sayang Sampai Mati", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "97365449980687", 
		judul = "Freaks Time", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "137964573724941", 
		judul = "Wet Dream", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "100583222608426", 
		judul = "BREAKBEAT Terserah (Raisa)", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "108575134456100", 
		judul = "BREAKBEAT Sound Of My Dream", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "111673988982403", 
		judul = "BREAKBEAT Always Loving You", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "133638540362172", 
		judul = "BREAKBEAT Dancing With Your Ghost", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "140328305976667", 
		judul = "BREAKBEAT Aurora", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "123411462236449", 
		judul = "BREAKBEAT Danza Kuduro", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "73835490732159", 
		judul = "BREAKBEAT RIGHT NOW (NA NA NA)", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "128702648637622", 
		judul = "BREAKBEAT BHABI", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "125710994306296", 
		judul = "BREAKBEAT Thank You (Not So Bad)", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "75734899625892", 
		judul = "BREAKBEAT I Don't Love You", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "125966225704229", 
		judul = "BREAKBEAT MACARENA", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "111968042309187", 
		judul = "BREAKBEAT Someone Like You", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "126723036079403", 
		judul = "BREAKBEAT Wirang", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "121593775087320", 
		judul = "BREAKBEAT Lost Without You", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "139576874142238", 
		judul = "BREAKBEAT Serana", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "135236944972072", 
		judul = "BREAKBEAT Faded X Alone", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "122795769130133", 
		judul = "BREAKBEAT Save Me", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "78091269992641", 
		judul = "BREAKBEAT Dynamite X Drive", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "131106560732896", 
		judul = "BREAKBEAT Hero - Alan Walker", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "97022378985103", 
		judul = "BREAKBEAT NU", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "86487374612171", 
		judul = "BREAKBEAT Love Is Unbound", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "126373862940021", 
		judul = "BREAKBEAT NOW I SEE", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "122598264064126", 
		judul = "BREAKBEAT TABOLA BALE", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "122446227623730", 
		judul = "BREAKBEAT Not You", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "77044004268048", 
		judul = "BREAKBEAT Power Of Magic V2", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "105166838331594", 
		judul = "BREAKBEAT Jakarta", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "122377272211224", 
		judul = "BREAKBEAT Kota Ini Tak Sama Tanpamu", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "126191403600753", 
		judul = "BREAKBEAT Love Story", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "72597047733804", 
		judul = "BREAKBEAT Love", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "123594749227298", 
		judul = "BREAKBEAT Take Me Home, Country Roads", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "138879592235902", 
		judul = "BREAKBEAT Drive Me Crazy", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "115477585823113", 
		judul = "BREAKBEAT Close to the Stars", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "89211783344563", 
		judul = "BREAKBEAT Mencintaimu", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "93764871626839", 
		judul = "BREAKBEAT You'll Be In My Heart", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "138150043475960", 
		judul = "BREAKBEAT Teganya Kau", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "84438419182722", 
		judul = "BREAKBEAT AFTERSHOCK", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 1.0
	},
	{
		id = "78699624855964", 
		judul = "BREAKBEAT CYBERDREAM", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 1.0
	},
	{
		id = "136467152968541", 
		judul = "BREAKBEAT Alive", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 1.0
	},
	{
		id = "130096834598482", 
		judul = "BREAKBEAT Can We Dance", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "113866909192562", 
		judul = "BREAKBEAT HANDS", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "131633227619562", 
		judul = "BREAKBEAT Shut Up and Dance", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "91068299807070", 
		judul = "BREAKBEAT Pure Love", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "107439410822623", 
		judul = "BREKBEAT Un-Break My Heart ", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 1.0
	},
	{
		id = "123940974514916", 
		judul = "BREAKBEAT Where Have You Been", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "87271721081505", 
		judul = "BREAKBEAT RUSSIAN R0UL3TT3", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "87655422840771", 
		judul = "BREAKBEAT SYMPHONY", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "112615350496910", 
		judul = "BREAKBEAT IM LO", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "120437660594492", 
		judul = "BREAKBEAT SEPARUH NAFASKU", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 1.0
	},
	{
		id = "102864592855033", 
		judul = "BREAKBEAT PENIPU HATI", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 1.0
	},
	{
		id = "132608652867470", 
		judul = "BREAKBEAT Barbie Girl x Que Pasa", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 1.0
	},
	{
		id = "129266256358292", 
		judul = "BREAKBEAT Jar of Heart", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 1.0
	},
	{
		id = "90410735710111", 
		judul = "BREAKBEAT Disarankan Di Bandung", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "95412810647622", 
		judul = "BREAKBEAT Beautiful Now", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "133521288044966", 
		judul = "BEAUTY AND A BEAT", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 1.0
	},
	{
		id = "71739713303715", 
		judul = "WildFlower - Billie Eilish", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 1.0
	},
	{
		id = "96658868498111", 
		judul = "Beauty And A Beat - Justin Bieber", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 1.0
	},
	{
		id = "123798644499311", 
		judul = "I WISH", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 1.0
	},
	{
		id = "131434979823319", 
		judul = "ANGELS LIKE YOU", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 1.0
	},
	{
		id = "81795986620169", 
		judul = "STEREO LOVE", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 1.0
	},
	{
		id = "79036934804022", 
		judul = "DON'T YOU REMEMBER", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 1.0
	},
	{
		id = "140307464955008", 
		judul = "SOUL ON THE RUN", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 1.0
	},
	{
		id = "80984680926356", 
		judul = "THIS I VOW", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 1.0
	},
	{
		id = "131384364335670", 
		judul = "Jonas Blue - Perfect Strangers", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 1.0
	},
	{
		id = "116474214270991", 
		judul = "Dynamite", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 1.0
	},
	{
		id = "118033326486674", 
		judul = "Ain't My Fault", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 1.0
	},
	{
		id = "72305398957096", 
		judul = "EEEE A - Dial", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 1.0
	},
	{
		id = "97667027396765", 
		judul = "Faded", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 1.0
	},
	{
		id = "110974005461814", 
		judul = "Where We Are", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 1.0
	},
	{
		id = "112628994948375", 
		judul = "BLUE", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 1.0
	},
	{
		id = "91997083709307", 
		judul = "Malu Malu Boy", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 1.0
	},
	{
		id = "87510137146967", 
		judul = "Golden", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 1.0
	},
	{
		id = "117958712648696", 
		judul = "Play", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 1.0
	},
	{
		id = "109680690451375", 
		judul = "FLASHLIGHT", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 1.0
	},
	{
		id = "95150908894825", 
		judul = "SHELTER", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 1.0
	},
	{
		id = "83350632225675", 
		judul = "Middle", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 1.0
	},
	{
		id = "102052409456362", 
		judul = "UMBRELLA", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 1.0
	},
	{
		id = "104692490212730", 
		judul = "Believe", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 1.0
	},
	{
		id = "108354272091309", 
		judul = "When It Ends It Starts Again", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 1.0
	},
	{
		id = "138369528481690", 
		judul = "SERANA", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 1.0
	},
	{
		id = "129349311051513", 
		judul = "Where You Are", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 1.0
	},
	{
		id = "79046859597055", 
		judul = "Take Me Home", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 1.0
	},
	{
		id = "108396916634517", 
		judul = "Dream", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 1.0
	},
	{
		id = "97861526205534", 
		judul = "STARS COLLIDE X GOODBYE", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 1.0
	},
	{
		id = "86823111827904", 
		judul = "Kasih Tau Mama", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 1.0
	},
	{
		id = "83829219721062", 
		judul = "Butterfly", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 1.0
	},
	{
		id = "98251507031381", 
		judul = "RECKLESS", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 1.0
	},
	{
		id = "94179869407995", 
		judul = "So ASU", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 1.0
	},
	{
		id = "85422102997418", 
		judul = "Sad Sometimes", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 1.0
	},
	{
		id = "107336984768245", 
		judul = "Believe (Alt)", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 1.0
	},
	{
		id = "90040341854319", 
		judul = "Because Youre Here", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 1.0
	},
	{
		id = "111972811478756", 
		judul = "RISK IT ALL", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 1.0
	},
	{
		id = "124329198776323", 
		judul = "TILL THE SKY FALLS DOWN", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 1.0
	},
	{
		id = "113898928848544", 
		judul = "LOVE ATAN ATAN x BINTANG", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 1.0
	},
	{
		id = "132697530045986", 
		judul = "Ghost - Justin Bieber", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 1.0
	},
	{
		id = "111118770070856", 
		judul = "Right_Now_Na_Na_Na", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 1.0
	},
	{
		id = "95316179760818", 
		judul = "Love", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 1.0
	},
	{
		id = "110108362191323", 
		judul = "MIRACLES", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 1.0
	},
	{
		id = "130573949850577", 
		judul = "BRAND NEW DAY X DORA DORA", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 1.0
	},
	{
		id = "93119586262696", 
		judul = "River Flows In You", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 1.0
	},
	{
		id = "126611532124152", 
		judul = "A Sky Full Of Stars", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 1.0
	},
	{
		id = "95462060550415", 
		judul = "This Love Drives Me Crazy", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 1.0
	},
	{
		id = "135493429463331", 
		judul = "YOU DONT EVEN KNOW ME X PEOPLE", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 1.0
	},
	{
		id = "120383160106356", 
		judul = "All Night", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "90921300628080", 
		judul = "TEN FEET TALL", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "106832004561605", 
		judul = "DREAMER", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "101951488636873", 
		judul = "Invicible", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "90204322497494", 
		judul = "Dora X Stephanie", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "87585494472221", 
		judul = "Ours To Keep", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "94616536057586", 
		judul = "If I Lose Myself", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "127019714407426", 
		judul = "STAY WITH ME", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "137258078964918", 
		judul = "BREAKBEAT DJ JOANNA", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "75481507579973", 
		judul = "BREAKBEAT DJ UNITY X PLAY FOR ME", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "138965817761821", 
		judul = "BREAKBEAT DJ YA ODNA X THE DRUM", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "132188097930446", 
		judul = "Wolves - Selena Gomez Marshmello", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "108498617675673", 
		judul = "Lions In The Wild", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "131732563686566", 
		judul = "I SURRENDER TO YOU", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "127023516638422", 
		judul = "Turn It Up", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "131570146956313", 
		judul = "Dont Watch Me Cry", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "96585234835928", 
		judul = "PUT YOUR HANDS UP", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "82800024361608", 
		judul = "SUMMER AIR", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	-- 	{
	-- 	id = "123133787276766", 
	-- 	judul = "Kupu-Kupu", 
	-- 	sampul = "rbxassetid://110370706778065", 
	-- 	album = "BREAKBEAT", 
	-- 	Duration = nil, 
	-- 	PlaybackSpeed = 1
	-- },
	{
		id = "95728842583428", 
		judul = "DESPACITO", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "112641289202152", 
		judul = "Inside The Lines Mike Perry", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "125525119845707", 
		judul = "Shimpony", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "99837751187401", 
		judul = "Beby Dont Go", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "108723294028764", 
		judul = "E e e a", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "75040733117467", 
		judul = "TO LOVE YOU MORE", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "135006908074580", 
		judul = "Sedia Aku Sebelum Hujan", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "75545164837383", 
		judul = "VIERRA - PERIH", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "74934787369700", 
		judul = "Close to You", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "81405359566835", 
		judul = "KISINAN x NEMEN", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "130168099307452", 
		judul = "TANYA HATI", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "116119101594923", 
		judul = "Last Child - Duka", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "135967332909455", 
		judul = "Mimosa", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "112293233287931", 
		judul = "NOW I SEE X IN AND OUT OF LOVE", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "112225285920304", 
		judul = "ROCKABYE", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "131329071633662", 
		judul = "REST OF OUR LIVES", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "103800473180699", 
		judul = "KOTA INI TAK SAMA TANPAMU", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "80206885810979", 
		judul = "SO IM YRS", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "103786049761147", 
		judul = "ONE IN A MILLION", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "111624142825016", 
		judul = "CINTA SATU MALAM", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "111141144551849", 
		judul = "OUR LOVE", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "100693436109082", 
		judul = "I WILL FIND YOU", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "102392919687639", 
		judul = "SAMSON - DI UJUNG JALAN", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "135648480510653", 
		judul = "SCARED TO BE LONELY", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "98467725289439", 
		judul = "EVERYTHING AT ONCE", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "132899973744315", 
		judul = "FOR THE LOVE", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "132195017360346", 
		judul = "Good Side", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "133717121367094", 
		judul = "Orang Yang Salah", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "121886677783639", 
		judul = "Kenangan Terindah", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "99913250155476", 
		judul = "Freeze Time", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "127135428052460", 
		judul = "Walking On Air", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "133791309904037", 
		judul = "Komang", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "104521051049200", 
		judul = "Love Is Gone", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "124607399350502", 
		judul = "BABY", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "92507017240598", 
		judul = "Tak Ingin Usai", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "98276204331532", 
		judul = "NOT YOU", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "100104887781678", 
		judul = "Angel Baby", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "134245225858269", 
		judul = "Semata Karenamu", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "121894042941802", 
		judul = "Still The Same", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "130858517049116", 
		judul = "BAD LIAR", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "84191613296110", 
		judul = "For The One", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "132417206852041", 
		judul = "My Reflection", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "120425660332478", 
		judul = "Aurora", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "134094528868484", 
		judul = "ASHES", 
		sampul = "rbxassetid://110370706778065", 
		album = "BREAKBEAT", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	}
}

-- ====================================
-- GET ALL MUSIC
-- ====================================
function MusicModule:GetAllMusic()
	return MusicDatabase
end

-- ====================================
-- GET MUSIC BY ID
-- ====================================
function MusicModule:GetMusicById(id)
	for _, music in ipairs(MusicDatabase) do
		if music.id == id then
			return music
		end
	end
	return nil
end

-- ====================================
-- GET ALL ALBUMS
-- ====================================
function MusicModule:GetAllAlbums(favoriteSongs)
	favoriteSongs = favoriteSongs or {}
	local albums = {}
	local albumCounts = {}

	-- Count songs per album
	for _, music in ipairs(MusicDatabase) do
		local albumName = music.album or "Unknown"
		albumCounts[albumName] = (albumCounts[albumName] or 0) + 1
	end

	-- "All Songs" album
	table.insert(albums, {
		name = "All Songs",
		songCount = #MusicDatabase
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
			songCount = favCount
		})
	end

	-- Other albums
	for albumName, count in pairs(albumCounts) do
		table.insert(albums, {
			name = albumName,
			songCount = count
		})
	end

	return albums
end

-- ====================================
-- GET ALBUM SONGS
-- ====================================
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

-- ====================================
-- SEARCH IN ALBUM
-- ====================================
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
