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
		id = "71538060113255", 
		judul = "THAILAND STYLE KICAU MANIA", 
		sampul = "rbxassetid://110370706778065", 
		album = "THAILAND STYLE", 
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
		id = "93989503395575", 
		judul = "THAILAND STYLE Kangen Band Nilailah Aku", 
		sampul = "rbxassetid://110370706778065", 
		album = "THAILAND STYLE", 
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
	},
	{
		id = "90820821099719", 
		judul = "When I Close My Eyes", 
		sampul = "rbxassetid://110370706778065", 
		album = "Sad Vibes", 
		Duration = nil, 
		PlaybackSpeed = 0.9
	},
	{
		id = "80645766074424", 
		judul = "LANY - You", 
		sampul = "rbxassetid://110370706778065", 
		album = "LANY", 
		Duration = nil, 
		PlaybackSpeed = 0.7,
		PitchOctave = 1.1
	},
	{
		id = "81257869135562",
		judul = "LANY - 'Cause You Have To",
		sampul = "rbxassetid://110370706778065",
		album = "LANY",
		Duration = nil,
		PlaybackSpeed = 0.7,
		PitchOctave = 1.1
	},
	{
		id = "125816766946068",
		judul = "LANY - 13",
		sampul = "rbxassetid://110370706778065",
		album = "LANY",
		Duration = nil,
		PlaybackSpeed = 0.7,
		PitchOctave = 1.1
	},
	{
		id = "85428778844636",
		judul = "LANY - Super Far",
		sampul = "rbxassetid://110370706778065",
		album = "LANY",
		Duration = nil,
		PlaybackSpeed = 0.7,
		PitchOctave = 1.1
	},
	{
		id = "114204415546617",
		judul = "LANY - XXL",
		sampul = "rbxassetid://110370706778065",
		album = "LANY",
		Duration = nil,
		PlaybackSpeed = 0.7,
		PitchOctave = 1.1
	},
	{
		id = "75331949790916",
		judul = "LANY - Thru These Tears",
		sampul = "rbxassetid://110370706778065",
		album = "LANY",
		Duration = nil,
		PlaybackSpeed = 0.7,
		PitchOctave = 1.1
	},
	{
		id = "108268996390872",
		judul = "LANY - anything 4 u",
		sampul = "rbxassetid://110370706778065",
		album = "LANY",
		Duration = nil,
		PlaybackSpeed = 0.7,
		PitchOctave = 1.1
	},
	{
		id = "91656074831192",
		judul = "LANY - Thick And Thin",
		sampul = "rbxassetid://110370706778065",
		album = "LANY",
		Duration = nil,
		PlaybackSpeed = 0.7,
		PitchOctave = 1.1
	},

	-- PLAYLIST THE WEEKND
	{
		id = "110595139107215",
		judul = "The Weeknd - Blinding Lights",
		sampul = "rbxassetid://110370706778065",
		album = "The Weeknd",
		Duration = nil,
		PlaybackSpeed = 0.7,
		PitchOctave = 1.1
	},
	{
		id = "90343504797110",
		judul = "The Weeknd - Save Your Tears",
		sampul = "rbxassetid://110370706778065",
		album = "The Weeknd",
		Duration = nil,
		PlaybackSpeed = 0.7,
		PitchOctave = 1.1
	},
	{
		id = "79527978829243",
		judul = "The Weeknd - Hardest To Love",
		sampul = "rbxassetid://110370706778065",
		album = "The Weeknd",
		Duration = nil,
		PlaybackSpeed = 0.7,
		PitchOctave = 1.1
	},
	{
		id = "88854879737198",
		judul = "The Weeknd - Moth To A Flame",
		sampul = "rbxassetid://110370706778065",
		album = "The Weeknd",
		Duration = nil,
		PlaybackSpeed = 0.7,
		PitchOctave = 1.1
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
	{
		id = "88996971963655",
		judul = "FUNKOT Bukit Berbunga",
		sampul = "rbxassetid://110370706778065",
		album = "FUNKOT STYLE",
		Duration = nil,
		PlaybackSpeed = 0.7,
		PitchOctave = 1
	},
	{
		id = "103253348115248",
		judul = "DJ Obh Combi Sachet",
		sampul = "rbxassetid://110370706778065",
		album = "NEW SONGS",
		Duration = nil,
		PlaybackSpeed = 1,
		PitchOctave = 1
	},
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