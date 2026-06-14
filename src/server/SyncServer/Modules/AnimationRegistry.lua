local module = {}

-- ============================================
-- 🔐 ANIMATION ID REGISTRY
-- ============================================
-- Format: [AnimationName] = "rbxassetid://ID"

-- DANCE ANIMATIONS
module.Dances = {
	["Kicau Mania"] = "rbxassetid://140349022227594",
	["Spongebob"] = "rbxassetid://112338575188163",
	["Accuracy Dance"] = "rbxassetid://83600187972870",
	["Acelerada"] = "rbxassetid://103360497719320",
	["2pa2"] = "rbxassetid://91678970285264",
	["6 7 Dance"] = "rbxassetid://117961236980639",
	["7 rings dance"] = "rbxassetid://74387250908176",
	["Air bending"] = "rbxassetid://123649339787519",
	["Allow Vibe"] = "rbxassetid://81076982124026",
	["Antifragile"] = "rbxassetid://84561978111673",
	["Side Suffle"] = "rbxassetid://85247727536511",
	["Clap"] = "rbxassetid://10713966026",
	["Arms Groove"] = "rbxassetid://89296895828112",
	["Ashi ashi dance"] = "rbxassetid://91762541141326",
	["Aura Farming"] = "rbxassetid://80310147207105",
	["Avion"] = "rbxassetid://114518297506926",
	["BHA"] = "rbxassetid://91746738989420",
	["BlackPink 1"] = "rbxassetid://79979515443365",
	["BlackPink 2"] = "rbxassetid://85478531180450",
	["Bachata"] = "rbxassetid://106592448726028",
	["Back D T"] = "rbxassetid://78858697200410",
	["Bad Romance"] = "rbxassetid://109367770639860",
	["Banana Shake"] = "rbxassetid://71132816230435",
	["Barcola Dance"] = "rbxassetid://83064564490945",
	["Bboy Hip Hop"] = "rbxassetid://106522914573804",
	["Beggin"] = "rbxassetid://72816626774477",
	["Bell Air"] = "rbxassetid://96764522829086",
	["Belly Dance 1"] = "rbxassetid://113243969788722",
	["Belly Dance 2"] = "rbxassetid://120966103389187",
	["Belly Twist"] = "rbxassetid://130432663544269",
	["Bhangra Dance"] = "rbxassetid://78416657618448",
	["Big G Bounce"] = "rbxassetid://115193774522990",
	["Billy Bounce"] = "rbxassetid://133394554631338",
	["Bizcochito"] = "rbxassetid://107725066915114",
	["Blinding Light 2"] = "rbxassetid://82665096617315",
	["Blinding light"] = "rbxassetid://71850970401543",
	["Boneless"] = "rbxassetid://76233961342346",
	["Bones"] = "rbxassetid://78004256536637",
	["Boogie Down"] = "rbxassetid://78138216847825",
	["Boogie Down 2"] = "rbxassetid://117332890963657",
	["Boots"] = "rbxassetid://118478698300180",
	["Bouncy Cute"] = "rbxassetid://106398383152416",
	["Boy'S A Liar"] = "rbxassetid://131210953953073",
	["Break"] = "rbxassetid://96078519637664",
	["Break Dancing"] = "rbxassetid://107853684946252",
	["Breakdance"] = "rbxassetid://139316100443270",
	["Bye Bye Bye"] = "rbxassetid://134594513356628",
	["Cabare dance"] = "rbxassetid://79245915329984",
	["Can Can"] = "rbxassetid://88414168007740",
	["Candy Emote"] = "rbxassetid://136073073685621",
	["Cat Car Dance"] = "rbxassetid://74363280528801",
	["Cha Cha Dance"] = "rbxassetid://90166098423888",
	["Chainsaw Man"] = "rbxassetid://128611142091245",
	["Chakalita"] = "rbxassetid://115541521213228",
	["Chess"] = "rbxassetid://138396652435935",
	["Cholo Cumbia"] = "rbxassetid://123090505598681",
	["Coffin Walkout"] = "rbxassetid://126771729094882",
	["Confess Dance"] = "rbxassetid://96583410232950",
	["Conga 1"] = "rbxassetid://70644559159115",
	["Conga 2"] = "rbxassetid://112166894693605",
	["Conga 3"] = "rbxassetid://83476183024011",
	["Conga 4"] = "rbxassetid://122861923327013",
	["Cool 1"] = "rbxassetid://107645348186593",
	["Cool 2"] = "rbxassetid://84939350788905",
	["Cortis"] = "rbxassetid://84411629009577",
	["Criss Cross"] = "rbxassetid://81733449586987",
	["Cuerda"] = "rbxassetid://128363639179565",
	["Cute Dance"] = "rbxassetid://15517864808",
	["Dare"] = "rbxassetid://94569503223288",
	["DKWTD"] = "rbxassetid://132079805400856",
	["Dance Fever"] = "rbxassetid://106075698225441",
	["Dancing"] = "rbxassetid://126649778668933",
	["Dancing Everyday"] = "rbxassetid://71804412191835",
	["Danielas"] = "rbxassetid://78379687654810",
	["Dark Arts 2"] = "rbxassetid://114650242724805",
	["Deadpoll"] = "rbxassetid://96769959258150",
	["Delicia Dance"] = "rbxassetid://108759656834820",
	["Diva"] = "rbxassetid://130899482778298",
	["Do you want me"] = "rbxassetid://109364514498221",
	["Don Pollo"] = "rbxassetid://139661757526700",
	["Dont Start Dance"] = "rbxassetid://115316009045457",
	["Drum Feet"] = "rbxassetid://91645659575706",
	["Druski Pop Out"] = "rbxassetid://111060112236071",
	["Duranguense"] = "rbxassetid://117383911498788",
	["Dxrk 1"] = "rbxassetid://131223715778932",
	["Dxrk 2"] = "rbxassetid://90012750634270",
	["Dxrk R"] = "rbxassetid://119790932983122",
	["Dynamite"] = "rbxassetid://104511004260553",
	["El Azul"] = "rbxassetid://103630793529461",
	["El Coco"] = "rbxassetid://113226751413165",
	["El Son 1"] = "rbxassetid://96363627746842",
	["El Son 2"] = "rbxassetid://93084961588302",
	["El Son 3"] = "rbxassetid://96457053352275",
	["El Toro"] = "rbxassetid://84749574617983",
	["Electro Shuffle"] = "rbxassetid://122599479076921",
	["Empress Fan"] = "rbxassetid://117653394600742",
	["Enhypen"] = "rbxassetid://70397195897275",
	["Everybody Loves Me"] = "rbxassetid://93650537970037",
	["Evil Plan"] = "rbxassetid://74012392874651",
	["Fearless"] = "rbxassetid://140437777986813",
	["Fame is a Gun"] = "rbxassetid://121110107634787",
	["Fast Hops"] = "rbxassetid://127730510910237",
	["Feelin myself"] = "rbxassetid://77780134372141",
	["Feeling"] = "rbxassetid://77321546404346",
	["Festa No Brasil"] = "rbxassetid://82516443009513",
	["Festive Dance"] = "rbxassetid://15679621440",
	["Floss"] = "rbxassetid://111548719797489",
	["FootLoose"] = "rbxassetid://97884046960451",
	["Forsaken"] = "rbxassetid://76389296606994",
	["Fortnire"] = "rbxassetid://83222694145373",
	["Gangnam style"] = "rbxassetid://131104967711844",
	["Get DMF"] = "rbxassetid://96649139759245",
	["Get Griddy"] = "rbxassetid://136655006826362",
	["Get Sturdy"] = "rbxassetid://102571052202995",
	["Give me everything"] = "rbxassetid://96471578843776",
	["Goku's Warmup"] = "rbxassetid://82461945694033",
	["Golden Dance"] = "rbxassetid://104845664978994",
	["Groove"] = "rbxassetid://117245629278318",
	["Guadalajara"] = "rbxassetid://92814726085803",
	["Guittar"] = "rbxassetid://128854052142716",
	["HIT dance 1"] = "rbxassetid://131829783462785",
	["HIT dance 2"] = "rbxassetid://136545999491428",
	["Hand Down swip"] = "rbxassetid://91767510752557",
	["Heel Toe"] = "rbxassetid://96512545729071",
	["Hey Ya Move"] = "rbxassetid://119734573196374",
	["Hi High"] = "rbxassetid://71528865065489",
	["High Wave"] = "rbxassetid://10714362852",
	["Hip sway"] = "rbxassetid://138316142522795",
	["HipHop Arm Dance"] = "rbxassetid://105987146309586",
	["HipHop Arm Wave"] = "rbxassetid://132233575741833",
	["Hype Boy"] = "rbxassetid://74950885921818",
	["Ice Spice"] = "rbxassetid://99558490932154",
	["Im jockin"] = "rbxassetid://71049110885171",
	["In Ha Hood"] = "rbxassetid://114682282129958",
	["In The Rain"] = "rbxassetid://140418182009287",
	["Indian Dance"] = "rbxassetid://140045473880554",
	["Its ok Im ok"] = "rbxassetid://112322179960255",
	["Jabba Switchway"] = "rbxassetid://77791964179635",
	["Jamal Dance"] = "rbxassetid://114463328960354",
	["Jelly Dance"] = "rbxassetid://119334432736404",
	["Jig 2"] = "rbxassetid://83153371854753",
	["Jubi Slide"] = "rbxassetid://77471219823552",
	["Jump Dance"] = "rbxassetid://124697621871530",
	["Jumpstyle"] = "rbxassetid://86272822145078",
	["Just be competent"] = "rbxassetid://129245317392856",
	["KPOP"] = "rbxassetid://73603565152518",
	["Ketlin Dance"] = "rbxassetid://138980457623979",
	["Kick It"] = "rbxassetid://12259826609",
	["Killin It Girl"] = "rbxassetid://98227246077390",
	["Kotonai"] = "rbxassetid://83650099589962",
	["Last Forever"] = "rbxassetid://128218916374983",
	["Lets Get Sturdy"] = "rbxassetid://122215157965385",
	["Lighter"] = "rbxassetid://105865125341943",
	["Like Jennie Dance"] = "rbxassetid://132682262315910",
	["Little Soda Pop"] = "rbxassetid://132710822676089",
	["Louisiana Jigg 1"] = "rbxassetid://126597745883758",
	["Louisiana Jigg 2"] = "rbxassetid://83153371854753",
	["Lush Life"] = "rbxassetid://73332778181668",
	["M3GAN's Dance"] = "rbxassetid://99649534578309",
	["MOSH"] = "rbxassetid://96147994216119",
	["Macarena"] = "rbxassetid://106534063593882",
	["Make Waves"] = "rbxassetid://86082766713867",
	["Make You Mine"] = "rbxassetid://78063069360906",
	["Maneuvering Dance"] = "rbxassetid://111508363684293",
	["Mannrobics"] = "rbxassetid://73932117454031",
	["Miau Miau"] = "rbxassetid://109028475644463",
	["Midnight sun"] = "rbxassetid://76844683252596",
	["Money Hop Spin"] = "rbxassetid://75672330899301",
	["NONONO COCONO"] = "rbxassetid://115147263460500",
	["Tyranno Dance"] = "rbxassetid://97359339294795",
	["Nokia Dance"] = "rbxassetid://106735437955644",
	["Nonchalant Dance"] = "rbxassetid://97086109091396",
	["OG STURDY"] = "rbxassetid://101011728520473",
	["Oblivion"] = "rbxassetid://117081427175655",
	["Oh"] = "rbxassetid://138909741135203",
	["Ombrino 1"] = "rbxassetid://91749814658072",
	["Ombrino 2"] = "rbxassetid://94764192470964",
	["Ombrino 3"] = "rbxassetid://86435507645475",
	["Orange Justice"] = "rbxassetid://95127716920692",
	["PCR"] = "rbxassetid://104024628199104",
	["PONPONPON Dance"] = "rbxassetid://73903479506022",
	["Pangya Dance"] = "rbxassetid://70735468992188",
	["Parking Lot"] = "rbxassetid://101841781757637",
	["Party Dancing"] = "rbxassetid://99016862356135",
	["Pasayo De Rodeo"] = "rbxassetid://135069740440631",
	["Pennywise"] = "rbxassetid://137636495361294",
	["Performance"] = "rbxassetid://110489307106534",
	["Popular"] = "rbxassetid://93062298566806",
	["Prince Of Egypt"] = "rbxassetid://97246196405886",
	["Pull Love"] = "rbxassetid://125236272165399",
	["Pump it Up"] = "rbxassetid://76887834098387",
	["Punjap"] = "rbxassetid://77848071235677",
	["Push2Start"] = "rbxassetid://96072539308174",
	["Quick Style"] = "rbxassetid://74804430904049",
	["Raise The Roof"] = "rbxassetid://110329776064340",
	["Rakai Dance"] = "rbxassetid://115858722399476",
	["Rambunctious"] = "rbxassetid://129991743366120",
	["Rat Dance"] = "rbxassetid://123592030317597",
	["Ride The Pony"] = "rbxassetid://90829569188792",
	["Rock"] = "rbxassetid://124755593548350",
	["Rock Out"] = "rbxassetid://122719596509695",
	["Rollie"] = "rbxassetid://138097548542741",
	["Ruben"] = "rbxassetid://75294481891818",
	["Russian Dance"] = "rbxassetid://97148848007002",
	["Safe Your Tears"] = "rbxassetid://97792666202931",
	["Salsa Dance"] = "rbxassetid://92252791228988",
	["Salsa Dance 1"] = "rbxassetid://124474935977481",
	["Salsa Dance 2"] = "rbxassetid://93266445700992",
	["Salsa Dance 3"] = "rbxassetid://74103063111811",
	["Salsa Dance 4"] = "rbxassetid://78725893691704",
	["Salsa Dance 5"] = "rbxassetid://105876017232406",
	["Salsa Dance 6"] = "rbxassetid://87600473518933",
	["Samba Dance"] = "rbxassetid://103356254839664",
	["Scenario"] = "rbxassetid://77367050151442",
	["Sega Walk"] = "rbxassetid://111823656989061",
	["Sequencia 1"] = "rbxassetid://109366035363166",
	["Sequencia 2"] = "rbxassetid://119912324780403",
	["Shake That"] = "rbxassetid://138296642082362",
	["Shimmer Swerve"] = "rbxassetid://86295087151051",
	["Shuffle 1"] = "rbxassetid://17748314784",
	["Shuffle 2"] = "rbxassetid://117991470645633",
	["Shuffle 3"] = "rbxassetid://118468821959324",
	["Shuffling Sig"] = "rbxassetid://112931882473990",
	["Side To Side"] = "rbxassetid://98741601232127",
	["Silly Thang"] = "rbxassetid://120340292784136",
	["Single Ladies"] = "rbxassetid://138824225787647",
	["Skeleton"] = "rbxassetid://15122972413",
	["Slide In"] = "rbxassetid://122307134950307",
	["Slowmo backflip"] = "rbxassetid://126859564967032",
	["Snoop's Walk"] = "rbxassetid://110204898807330",
	["Space Dance"] = "rbxassetid://97327442310468",
	["Spicy Life Dance"] = "rbxassetid://71589647866255",
	["Spike"] = "rbxassetid://100587562805432",
	["Spin With Friend"] = "rbxassetid://80879471830819",
	["Spinner Dance"] = "rbxassetid://127068078640747",
	["Starlit"] = "rbxassetid://121046119752797",
	["Still Standing"] = "rbxassetid://11444443576",
	["Street Glide"] = "rbxassetid://82378883639086",
	["Sturdy Dance"] = "rbxassetid://132967433846099",
	["Sturdy"] = "rbxassetid://140333103929828",
	["Super Shy"] = "rbxassetid://85695442396675",
	["Swet Escape"] = "rbxassetid://75916708100195",
	["Swoo"] = "rbxassetid://111060437271811",
	["Tail Wag Happy"] = "rbxassetid://129026910898635",
	["Tell Me"] = "rbxassetid://99499902539238",
	["Thai dance"] = "rbxassetid://123965099095742",
	["The Dance Laroi"] = "rbxassetid://91219524625419",
	["The Feels"] = "rbxassetid://100415783658122",
	["The Tylil Dance"] = "rbxassetid://110494040742516",
	["To the Floor Dance"] = "rbxassetid://92001399624797",
	["Trappin"] = "rbxassetid://140300672229544",
	["True Heart Dance"] = "rbxassetid://85047784800271",
	["Twice Takedown"] = "rbxassetid://127104635954695",
	["Two dance"] = "rbxassetid://86525155818684",
	["Tyla Dance"] = "rbxassetid://111623528834900",
	["Uptown Dance"] = "rbxassetid://111088453758554",
	["Vai, Toma"] = "rbxassetid://132671797643713",
	["Vibe"] = "rbxassetid://110530853297115",
	["WLR Dance"] = "rbxassetid://107765500827026",
	["Wall Dance"] = "rbxassetid://137103162499439",
	["We wanna party"] = "rbxassetid://112463506075862",
	["Weekend"] = "rbxassetid://71105746210464",
	["What Is Love"] = "rbxassetid://134364277920166",
	["Work It"] = "rbxassetid://136545999491428",
	["Xaviersobased"] = "rbxassetid://90802740360125",
	["Ice Skating 1"] = "rbxassetid://140580440476493",
	["Ice Skating 2"] = "rbxassetid://138649905634305",
	["Ice Skating 3"] = "rbxassetid://90153163200238",
	["YB Jump"] = "rbxassetid://15609995579",
	["Just Feeling It"] = "rbxassetid://106394461480628",
	["Brazillian Vibe"] = "rbxassetid://99638411514722",
	["La Detone"] = "rbxassetid://102779295838500",
	["Urban Dance"] = "rbxassetid://119453677541532",
	["Courtly bow"] = "rbxassetid://117913449580238",
	["Spice Floor"] = "rbxassetid://83989072055447",
	["Snail Groove"] = "rbxassetid://136497483629350",
	["Street Walks"] = "rbxassetid://129559554023672",
	["Cute Bouncy"] = "rbxassetid://78286661104382",
	["Bumblebee"] = "rbxassetid://112992730901588",
	["Just Following"] = "rbxassetid://109785195029161",
	["The Glide"] = "rbxassetid://100985704087421",
	["Cat Daddy"] = "rbxassetid://82941366907179",
	["Amapiano Mnike"] = "rbxassetid://110271735617084",
	["Dembow Cintureo"] = "rbxassetid://71367193255332",
	["Get Out"] = "rbxassetid://126763060398632",
	["Real Drill"] = "rbxassetid://99112168140938",
	["Run The Bill"] = "rbxassetid://112104913626342",
	["Let's Dougie"] = "rbxassetid://92788660378972",
	["Street Flow"] = "rbxassetid://140584597268816",
	["Ichi Ichi"] = "rbxassetid://88809480805647",
	["Street Shuffle"] = "rbxassetid://132100137705335",
	["Spongebob Shuffle"] = "rbxassetid://77558928620404",
	["Special Zombie Dance"] = "rbxassetid://117708570576445",
	["WISH NLE"] = "rbxassetid://82501710348206",
	["NLE CHOPPA"] = "rbxassetid://138847072995537",
	["POP DAT THANG"] = "rbxassetid://120615013035083",
	["DropKick"] = "rbxassetid://133566007754001",
	-- Add your dance animation IDs here
}

-- POSE ANIMATIONS
module.Poses = {
	["Feel the music Pose"] = "rbxassetid://118956645124495",
	["Needy Stretch Pose"] = "rbxassetid://73318082260914",
	["Sonic Smash Bro Pose"] = "rbxassetid://110340154189809",
	["Sonic Adventure Pose"] = "rbxassetid://127286984691941",
	["Standing pose"] = "rbxassetid://97846337026061",
	["One legged"] = "rbxassetid://132512143844520",
	["Tyranno"] = "rbxassetid://84624681260553",
	["Hands Up"] = "rbxassetid://135078793551909",
	["Fake Death"] = "rbxassetid://72130163105210",
	["Cute Angry Idle"] = "rbxassetid://137727152532518",
	["Arthur Morgan"] = "rbxassetid://94428390083053",
	["Inchworm"] = "rbxassetid://119096405600200",
	["2017X Point"] = "rbxassetid://93810591156861",
	["Bang Head"] = "rbxassetid://89060597619453",
	["Adventure Pose"] = "rbxassetid://105286298891700",
	["Chill Guy"] = "rbxassetid://107466254930590",
	["Cower"] = "rbxassetid://4940563117",
	["Cute Hips"] = "rbxassetid://117181705578424",
	["Elegant Picture"] = "rbxassetid://113345525010569",
	["FF Push Up"] = "rbxassetid://76988349893259",
	["Fantano Squat"] = "rbxassetid://124972507696792",
	["Fashion"] = "rbxassetid://93106139772346",
	["Fashionable Pretty"] = "rbxassetid://133076490374907",
	["Fetal Crying"] = "rbxassetid://87595043597341",
	["For the Pic"] = "rbxassetid://117336874204710",
	["Handstand Pose"] = "rbxassetid://75102478510616",
	["Jumping Wave"] = "rbxassetid://10714378156",
	["Kid tantrum"] = "rbxassetid://86339673982616",
	["Nonchalant Sit"] = "rbxassetid://124882373076963",
	["Police Vest Rest"] = "rbxassetid://83026903211659",
	["Pose 1"] = "rbxassetid://90198206120117",
	["Push Up"] = "rbxassetid://90420644924192",
	["Sad"] = "rbxassetid://131737004503275",
	["Shinra Pose"] = "rbxassetid://121514889513586",
	["Sit 2"] = "rbxassetid://102544119718369",
	["Sleep Face"] = "rbxassetid://10714360343",
	["Sleeping Soundly"] = "rbxassetid://121641415206650",
	["Spider Swing"] = "rbxassetid://120676400102543",
	["Spiderman"] = "rbxassetid://123888267685221",
	["Spiderman Hanging"] = "rbxassetid://82468904268739",
	["Squat Sit"] = "rbxassetid://84129863420846",
	["Sweet Hug V2"] = "rbxassetid://118264035209903",
	["Sweet Sit V1"] = "rbxassetid://75141049180386",
	["Swinging"] = "rbxassetid://78512680384025",
	["Wall Lean"] = "rbxassetid://113694692828125",
	["Doll idle pose"] = "rbxassetid://75578209828688",
	["Girl idle pose"] = "rbxassetid://89439480855309",
	["Sit"] = "rbxassetid://86898753801433",
	["Sit and hug"] = "rbxassetid://117154715182434",
	["Sitting idle pose"] = "rbxassetid://112618514893492",
	["Roundhouse Kick"] = "rbxassetid://91454113537761",
	["NO NO"] = "rbxassetid://115134008219873",
	["Wall Aura"] = "rbxassetid://97751249599208",
	["DJ Emote"] = "rbxassetid://114486154887764",
	-- Add your pose animation IDs here
}

-- ============================================
-- 🔧 HELPER FUNCTIONS
-- ============================================

-- Get animation ID by name
function module.getAnimationId(animName, category)
	if category == "Pose" then
		return module.Poses[animName]
	else
		return module.Dances[animName]
	end
end

-- Get category for animation name
function module.getCategory(animName)
	if module.Poses[animName] then
		return "Pose"
	elseif module.Dances[animName] then
		return "Dance"
	end
	return nil
end

-- Get all animation names by category
function module.getNamesByCategory(category)
	local names = {}

	if category == "Dance" then
		for name, _ in pairs(module.Dances) do
			table.insert(names, name)
		end
	elseif category == "Pose" then
		for name, _ in pairs(module.Poses) do
			table.insert(names, name)
		end
	end

	table.sort(names)
	return names
end

-- Get all animation names (both categories)
function module.getAllNames()
	local names = {}

	for name, _ in pairs(module.Dances) do
		table.insert(names, name)
	end

	for name, _ in pairs(module.Poses) do
		table.insert(names, name)
	end

	table.sort(names)
	return names
end

-- Validate if animation exists
function module.exists(animName)
	return module.Dances[animName] ~= nil or module.Poses[animName] ~= nil
end

-- Get total count
function module.getCount()
	local count = 0

	for _ in pairs(module.Dances) do
		count = count + 1
	end

	for _ in pairs(module.Poses) do
		count = count + 1
	end

	return count
end

return module