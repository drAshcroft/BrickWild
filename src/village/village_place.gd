class_name VillagePlace
extends RefCounted
## A PLACE described by its features, and the village vernacular those
## features make (VILLAGE-PLACE; docs/VILLAGE_PLACE.md).
##
## `VillageVernacular` builds a village from a REGION ROW: house types by
## wealth tier, colour clusters, roof recipes, a landmark, plants, ground and
## names. Four rows are written by hand (Provence, the Cyclades, the Norse
## north, rural Japan). That is four places. This class is the other way in:
## the caller says what the place IS -- how hot, how wet, how high, what the
## land gives to build with, how rich, how well kept, how crowded, which few
## habits its builders have -- and `synthesise()` writes the region row. A
## southern French hill village, a Nordic farm on a mountainside, a British
## hamlet, a Russian collective, a forest village on the Congo and a Chinese
## canal town are then six points in ONE space, and so is everything between
## and beyond them.
##
##   request.vernacular = {"place": {"heat": 0.7, "rain": 0.35, "altitude": 0.3,
##       "stone": 0.8, "wealth": 0.6, "upkeep": 0.3}}
##   request.vernacular = {"place": {"like": "british_hamlet", "upkeep": 0.15}}
##
## Three rules hold the design together.
##
## 1. EVERY feature has a value. A feature the caller leaves out is DERIVED
##    from the ones it gave (`derive()`): forest from rain and height, timber
##    from forest, flat roofs from drought, upkeep from wealth. So two numbers
##    describe a place and thirty describe it exactly, and a stated feature
##    always wins over a derived one.
## 2. The features choose from what the builders can already build. A house
##    type is one of the HouseSpec chassis with a look laid over it, exactly
##    as in the hand-written rows; nothing here adds geometry.
## 3. The output is an ordinary region row, registered under an id made from
##    the features. `VillageVernacularCheck` therefore judges a place village
##    with the rules it already has, and a place can be blended with a region.
##
## PRESETS are named points in the space, not a second dataset: each is a
## handful of stated features. They are the examples and the test fixtures.

const SCHEMA := "brickwild.place"

## Every feature: its group, its kind, what it says, and its ends. `share`
## features run 0..1. A feature marked `derived` is computed from the others
## when it is not stated; the rest have the default shown.
const FEATURES := {
	# ---- the land: where it is
	"heat": {"group": "land", "kind": "share", "default": 0.5,
		"say": "the climate at sea level", "low": "arctic", "high": "equatorial"},
	"rain": {"group": "land", "kind": "share", "default": 0.5,
		"say": "how much water falls", "low": "desert", "high": "rainforest"},
	"altitude": {"group": "land", "kind": "share", "default": 0.1,
		"say": "height above the sea; it cools the place and brings stone and snow",
		"low": "sea level", "high": "3000 m and over"},
	"relief": {"group": "land", "kind": "share", "derived": true,
		"say": "how steep the ground is", "low": "plain", "high": "cliffside"},
	"forest": {"group": "land", "kind": "share", "derived": true,
		"say": "how much of the country is woodland", "low": "bare", "high": "deep forest"},
	"water": {"group": "land", "kind": "name", "default": "",
		"names": ["", "none", "pond", "stream", "river", "coast", "lake"],
		"say": "the water the village stands by; empty leaves the request's own"},
	# ---- the materials: what the land gives to build with
	"timber": {"group": "materials", "kind": "share", "derived": true,
		"say": "building timber to hand", "low": "none", "high": "any amount"},
	"stone": {"group": "materials", "kind": "share", "derived": true,
		"say": "building stone to hand", "low": "none", "high": "a quarry at the door"},
	"earth": {"group": "materials", "kind": "share", "derived": true,
		"say": "clay and mud for walls and for firing", "low": "none", "high": "everywhere"},
	"reed": {"group": "materials", "kind": "share", "derived": true,
		"say": "straw, reed, grass or palm leaf for thatch", "low": "none", "high": "plenty"},
	"lime": {"group": "materials", "kind": "share", "derived": true,
		"say": "lime for render and whitewash", "low": "none", "high": "plenty"},
	# ---- the people: who builds, and with what
	"wealth": {"group": "people", "kind": "share", "default": 0.4,
		"say": "what the households can spend on building", "low": "destitute", "high": "opulent"},
	"upkeep": {"group": "people", "kind": "share", "derived": true,
		"say": "how well the place is cared for; the low end is decay and rot",
		"low": "rotting", "high": "immaculate"},
	"inequality": {"group": "people", "kind": "share", "default": 0.5,
		"say": "how far the richest house is from the poorest",
		"low": "a collective of equals", "high": "a lord and his cottars"},
	"density": {"group": "people", "kind": "share", "default": 0.4,
		"say": "how closely the houses stand", "low": "scattered farms", "high": "a packed town"},
	"order": {"group": "people", "kind": "share", "default": 0.3,
		"say": "how planned and uniform the houses are", "low": "grown", "high": "laid out to one pattern"},
	"colour": {"group": "people", "kind": "share", "derived": true,
		"say": "how much paint is on the place", "low": "bare material", "high": "painted everywhere"},
	"ornament": {"group": "people", "kind": "share", "derived": true,
		"say": "carving, trim, dormers, flowers", "low": "plain", "high": "ornate"},
	"defence": {"group": "people", "kind": "share", "default": -1.0,
		"say": "how fortified; unstated leaves the request's own enclosure",
		"low": "open", "high": "walled"},
	"purpose": {"group": "people", "kind": "name", "default": "",
		"names": ["", "farming", "crossroads", "market", "mill", "fishing", "mining", "garrison",
			"pilgrim", "forest"],
		"say": "what the village lives by; empty leaves the request's own"},
	# ---- the building habits: what its builders do with all that
	"flat_roofs": {"group": "habit", "kind": "share", "derived": true,
		"say": "the share of level roofs", "low": "every roof pitched", "high": "every roof flat"},
	"whitewash": {"group": "habit", "kind": "share", "derived": true,
		"say": "the share of walls limewashed white", "low": "none", "high": "all"},
	"eaves": {"group": "habit", "kind": "share", "derived": true,
		"say": "how far the roof overhangs the wall", "low": "clipped", "high": "deep"},
	"openness": {"group": "habit", "kind": "share", "derived": true,
		"say": "verandas, loggias and porches", "low": "closed against the weather", "high": "open to the air"},
	"raised": {"group": "habit", "kind": "share", "derived": true,
		"say": "houses with the floor raised clear of the ground", "low": "none", "high": "all"},
	"round": {"group": "habit", "kind": "share", "derived": true,
		"say": "round houses under a cone of thatch", "low": "none", "high": "all"},
	"long": {"group": "habit", "kind": "share", "derived": true,
		"say": "longhouses: one long roof over a household and its work", "low": "none", "high": "all"},
	"swept_roof": {"group": "habit", "kind": "share", "default": 0.0,
		"say": "the hip-and-gable roof under grey tile", "low": "none", "high": "every roof"},
	"height": {"group": "habit", "kind": "share", "derived": true,
		"say": "how many storeys the houses run to", "low": "one", "high": "three"},
	"hues": {"group": "habit", "kind": "names", "derived": true,
		"say": "the paints the place uses on doors, shutters and boarded walls"},
	"washes": {"group": "habit", "kind": "names", "derived": true,
		"say": "the tints the place puts in the lime on a rendered wall"},
	"sacred": {"group": "habit", "kind": "name", "derived": true,
		"names": ["basilica", "spire", "dome", "stave"],
		"say": "the form of the landmark"},
	"tongue": {"group": "habit", "kind": "name", "derived": true,
		"say": "the sound of the place names"},
}

const GROUPS: Array[String] = ["land", "materials", "people", "habit"]

## The landmark forms, as the church styles that build them.
const SACRED := {"basilica": &"romanesque", "spire": &"gothic", "dome": &"byzantine",
	"stave": &"nordic_stave"}

## A paint: on a door or shutter (`trim`), as a strong coat on boards
## (`wall`), and thinned into a lime wash on render (`wash`).
const HUES := {
	"red": {"trim": ["8c2c26", "72231e"], "wall": ["8e3024", "76271d"], "wash": ["e5b6a2", "d29a84"]},
	"ochre": {"trim": ["c69c4c", "ae873d"], "wall": ["c69c4c", "ae873d"], "wash": ["dcab62", "c9924a"]},
	"yellow": {"trim": ["e2b63e", "c99f30"], "wall": ["d9b452", "c29c40"], "wash": ["ebca8c", "deb773"]},
	"blue": {"trim": ["2160aa", "1a4d8c"], "wall": ["3e6a92", "31577b"], "wash": ["cadce7", "b5cbd9"]},
	"sky": {"trim": ["5092d0", "3f7cb7"], "wall": ["6d93b8", "587da1"], "wash": ["d3e2ec", "bed1de"]},
	"lavender": {"trim": ["8e9bc6", "7987b5"], "wall": ["8e9bc6", "7987b5"], "wash": ["dcdcec", "c8c9de"]},
	"green": {"trim": ["304b36", "273e2c"], "wall": ["4c6a4d", "3e583f"], "wash": ["cfdcc4", "bccbb0"]},
	"sage": {"trim": ["9fb59b", "86a283"], "wall": ["8fa58b", "788f75"], "wash": ["dde5d3", "cbd5bf"]},
	"olive": {"trim": ["717c4b", "5e683d"], "wall": ["717c4b", "5e683d"], "wash": ["d8d8b6", "c6c6a0"]},
	"turquoise": {"trim": ["2f7e6e", "266659"], "wall": ["4d8f8b", "3e7a76"], "wash": ["c6e0da", "b0cfc8"]},
	"bordeaux": {"trim": ["7f2f35", "68252b"], "wall": ["7f2f35", "68252b"], "wash": ["e3bfc0", "d2a8aa"]},
	"white": {"trim": ["efebe1", "dedacd"], "wall": ["ece8dc", "dcd7c8"], "wash": ["f7f6f1", "ecebe4"]},
	"grey": {"trim": ["7e90a4", "68798e"], "wall": ["8b9198", "767c83"], "wash": ["d9dcdc", "c8cbcb"]},
	"black": {"trim": ["2b221c", "1f1915"], "wall": ["3d3129", "2e251f"], "wash": ["bdb7ac", "aaa498"]},
	"vermilion": {"trim": ["b03a26", "952f1e"], "wall": ["a8432d", "8d3624"], "wash": ["ecc2b2", "dfab98"]},
	"pink": {"trim": ["c9788a", "b06476"], "wall": ["d79a9f", "c48388"], "wash": ["efcdc1", "e2b3a4"]},
}

## Place-name sounds. A tongue is a habit like any other: stated, or taken
## from the nearest preset.
const TONGUES := {
	"romance": {"roots": ["Bon", "Lour", "Men", "Gor", "Cade", "Vau", "Sail", "Roque", "Mira", "Cab", "Lacos", "Oppe"],
		"endings": ["ieux", "marin", "erbes", "des", "net", "gues", "ane", "brune", "val", "rieres", "te", "de"],
		"patterns": ["{root}{ending}", "{root}{ending}", "Saint-{root}{ending}", "La Roque-{root}{ending}"]},
	"hellenic": {"roots": ["Lef", "Nao", "Pyr", "Apol", "Kast", "Chor", "Emb", "Mar", "Kam", "Ol", "Pla", "Sif"],
		"endings": ["kes", "ussa", "gos", "lonia", "ro", "a", "orio", "pissa", "ari", "ymbos", "ka", "nos"],
		"patterns": ["{root}{ending}", "{root}{ending}", "Ano {root}{ending}", "Kato {root}{ending}"]},
	"norse": {"roots": ["Hrafn", "Ulf", "Sval", "Eid", "Bjorn", "Skog", "Fjar", "Heg", "Vik", "Thor", "Aud", "Sig"],
		"endings": ["heim", "vik", "by", "stad", "dal", "nes", "fjord", "holt", "gard", "oy", "set", "bo"],
		"patterns": ["{root}{ending}"]},
	"nippon": {"roots": ["O", "Tsu", "Maga", "Shira", "Kura", "Mi", "Na", "Kiso", "Hara", "Ta", "Yama", "Kawa"],
		"endings": ["uchi", "mago", "me", "kawa", "shiki", "yama", "gura", "zawa", "no", "saki", "mura", "hara"],
		"patterns": ["{root}{ending}", "{root}{ending}-juku", "{root}{ending}-mura"]},
	"english": {"roots": ["Ash", "Wood", "Stan", "Brad", "Hol", "Mar", "Thorn", "Ald", "Whit", "Nor", "Comp", "Hather"],
		"endings": ["ton", "ham", "ford", "ley", "wick", "bury", "combe", "stead", "worth", "den", "by", "field"],
		"patterns": ["{root}{ending}", "{root}{ending}", "Little {root}{ending}", "{root}{ending} St Mary"]},
	"celtic": {"roots": ["Bal", "Kil", "Glen", "Inver", "Drum", "Aber", "Dun", "Strath", "Ard", "Loch", "Tully", "Ben"],
		"endings": ["more", "beg", "ness", "dee", "gorm", "nagar", "craig", "ruadh", "allan", "ochy", "vane", "lair"],
		"patterns": ["{root}{ending}", "{root}{ending}", "{root} {ending}"]},
	"germanic": {"roots": ["Roth", "Wald", "Stein", "Ober", "Lauf", "Dinkel", "Alt", "Neu", "Hohen", "Mark", "Schwarz", "Kalt"],
		"endings": ["burg", "bach", "dorf", "heim", "feld", "berg", "au", "hausen", "kirchen", "brunn", "tal", "stadt"],
		"patterns": ["{root}{ending}", "{root}{ending}", "{root}{ending} am See"]},
	"slavic": {"roots": ["Nov", "Star", "Krasn", "Bel", "Zel", "Dobr", "Bor", "Ber", "Mal", "Vel", "Kamen", "Lip"],
		"endings": ["ovka", "oye", "ino", "ovo", "aya", "skoye", "ichi", "itsa", "ovsk", "gorod", "ka", "nik"],
		"patterns": ["{root}{ending}", "{root}{ending}", "Novo{ending}", "Kolkhoz {root}{ending}"]},
	"arabic": {"roots": ["Tam", "Zag", "Tin", "Ksar", "Ghar", "Mer", "Tad", "Ouar", "Sidi", "Taf", "Bou", "Agh"],
		"endings": ["egroute", "ora", "erhir", "daia", "zouga", "akech", "imoun", "zazate", "ilalt", "raoute", "dib", "mat"],
		"patterns": ["{root}{ending}", "{root}{ending}", "Ait {root}{ending}", "Ksar {root}{ending}"]},
	"sahelian": {"roots": ["Djen", "Tom", "Sang", "Band", "Mop", "Seg", "Gao", "Kor", "Ning", "Yen", "Dour", "San"],
		"endings": ["ne", "bouctou", "ha", "iagara", "ti", "ou", "ro", "ogo", "ari", "dabo", "entza", "ga"],
		"patterns": ["{root}{ending}"]},
	"bantu": {"roots": ["Mban", "Kis", "Lub", "Mak", "Ngo", "Bom", "Kin", "Lis", "Yan", "Bol", "Mon", "Ike"],
		"endings": ["daka", "angani", "umba", "oua", "ma", "ongo", "du", "ala", "gambi", "obo", "kole", "la"],
		"patterns": ["{root}{ending}"]},
	"sinitic": {"roots": ["Zhou", "Wu", "Xi", "Tong", "Nan", "Hong", "Li", "Ping", "Feng", "Luo", "An", "Shui"],
		"endings": ["zhuang", "zhen", "tang", "li", "xun", "cun", "jiang", "yao", "huang", "ting", "qiao", "kou"],
		"patterns": ["{root}{ending}"]},
	"malay": {"roots": ["Kam", "Ban", "Sung", "Tan", "Mua", "Pak", "Bat", "Tel", "Ran", "Sam", "Kuala", "Lang"],
		"endings": ["pong", "tay", "ai", "jung", "ra", "se", "ang", "uk", "tau", "bas", "ka", "sat"],
		"patterns": ["{root}{ending}", "Kampong {root}{ending}", "Ban {root}{ending}"]},
	"andean": {"roots": ["Pis", "Ollan", "Chin", "Cusi", "Hua", "Tam", "Anda", "Yan", "Puma", "Qui", "Mara", "Uru"],
		"endings": ["ac", "taytambo", "chero", "pata", "ras", "bo", "huaylas", "aoca", "marca", "llabamba", "s", "bamba"],
		"patterns": ["{root}{ending}"]},
}

## Named points in the space. Each states only what sets it apart; the rest
## is derived. `label` and `summary` are words for a person, `tongue` and
## `sacred` are stated on every one because they are what an unstated tongue
## or landmark is borrowed from.
const PRESETS := {
	"provence_hill": {"label": "Southern French hill village",
		"summary": "ochre and sand render over limestone, low canal-tile roofs, painted shutters, tall houses packed on a hill",
		"heat": 0.68, "rain": 0.38, "altitude": 0.25, "relief": 0.55, "forest": 0.25, "stone": 0.8, "earth": 0.6,
		"wealth": 0.55, "density": 0.75, "colour": 0.75, "flat_roofs": 0.0, "whitewash": 0.05,
		"hues": ["lavender", "blue", "sage", "olive", "bordeaux", "grey"], "washes": ["ochre", "ochre", "red", "yellow"],
		"sacred": "basilica", "tongue": "romance"},
	"greek_island": {"label": "Aegean island village",
		"summary": "limewashed cubes under flat roofs, blue doors, a domed chapel, on a dry rock above the sea",
		"heat": 0.78, "rain": 0.18, "altitude": 0.1, "relief": 0.6, "forest": 0.03, "timber": 0.05, "stone": 0.85, "lime": 0.95,
		"wealth": 0.45, "density": 0.8, "colour": 0.85, "flat_roofs": 0.85, "whitewash": 0.9, "height": 0.3,
		"water": "coast", "purpose": "fishing",
		"hues": ["blue", "blue", "sky", "turquoise", "red"], "sacred": "dome", "tongue": "hellenic"},
	"nordic_mountain": {"label": "Nordic farm village on a mountainside",
		"summary": "tarred and red-painted timber under turf and shingle, scattered up a steep fjord side among pine and birch",
		"heat": 0.22, "rain": 0.65, "altitude": 0.45, "relief": 0.7, "forest": 0.85, "stone": 0.5,
		"wealth": 0.4, "density": 0.1, "colour": 0.45, "long": 0.4, "height": 0.15,
		"hues": ["red", "ochre", "white", "black"], "sacred": "stave", "tongue": "norse"},
	"british_hamlet": {"label": "British hamlet",
		"summary": "a dozen cob and stone cottages under thatch and slate, hedges, a green, a small grey church",
		"heat": 0.42, "rain": 0.68, "altitude": 0.08, "relief": 0.12, "forest": 0.35, "stone": 0.55, "earth": 0.6, "reed": 0.75,
		"wealth": 0.42, "density": 0.3, "colour": 0.3, "whitewash": 0.35, "height": 0.25,
		"hues": ["green", "black", "white", "blue"], "sacred": "spire", "tongue": "english"},
	"rhine_town": {"label": "Rich timber-framed market town",
		"summary": "tall jettied frames over stone ground floors, steep tiled roofs, carved and painted, a spire over all",
		"heat": 0.45, "rain": 0.55, "altitude": 0.15, "forest": 0.45, "stone": 0.5, "earth": 0.6,
		"wealth": 0.85, "density": 0.9, "order": 0.5, "colour": 0.6, "ornament": 0.9, "height": 0.85, "purpose": "market",
		"hues": ["red", "green", "ochre", "white"], "sacred": "spire", "tongue": "germanic"},
	"alpine_valley": {"label": "Alpine valley village",
		"summary": "broad timber houses on stone bases under low shingle roofs weighted against the wind, flowers at every window",
		"heat": 0.45, "rain": 0.6, "altitude": 0.65, "relief": 0.6, "forest": 0.7, "stone": 0.75,
		"wealth": 0.6, "density": 0.3, "ornament": 0.75, "eaves": 0.85, "colour": 0.35, "height": 0.55,
		"hues": ["green", "red", "white"], "sacred": "spire", "tongue": "germanic"},
	"russian_collective": {"label": "Russian farming collective",
		"summary": "identical log houses in rows on a plain, a few painted window frames, everything a little let go",
		"heat": 0.28, "rain": 0.45, "altitude": 0.08, "relief": 0.02, "forest": 0.6, "stone": 0.05, "earth": 0.35,
		"wealth": 0.25, "upkeep": 0.4, "inequality": 0.0, "density": 0.3, "order": 1.0, "colour": 0.4, "ornament": 0.3,
		"height": 0.0, "long": 0.0, "purpose": "farming",
		"hues": ["blue", "green", "white", "ochre"], "sacred": "dome", "tongue": "slavic"},
	"highland_croft": {"label": "Poor upland crofting township",
		"summary": "low rubble-stone houses under old turf and thatch, bare ground, half of it falling in",
		"heat": 0.3, "rain": 0.8, "altitude": 0.3, "relief": 0.4, "forest": 0.05, "stone": 0.9, "earth": 0.3,
		"wealth": 0.1, "upkeep": 0.2, "inequality": 0.2, "density": 0.08, "colour": 0.05, "height": 0.0,
		"hues": ["black", "white"], "sacred": "basilica", "tongue": "celtic"},
	"congo_forest": {"label": "African rainforest village",
		"summary": "round and oblong mud houses under deep palm thatch in a clearing of red earth, the forest at every edge",
		"heat": 0.95, "rain": 0.95, "altitude": 0.1, "relief": 0.1, "forest": 1.0, "stone": 0.05, "earth": 0.85, "reed": 0.95,
		"wealth": 0.2, "inequality": 0.25, "density": 0.25, "colour": 0.1, "round": 0.6, "raised": 0.0, "height": 0.0,
		"purpose": "forest", "hues": ["ochre", "white"], "sacred": "basilica", "tongue": "bantu"},
	"savanna_kraal": {"label": "Savanna homestead village",
		"summary": "rings of round thatched houses on dry grassland behind a thorn fence",
		"heat": 0.85, "rain": 0.35, "altitude": 0.3, "relief": 0.05, "forest": 0.15, "stone": 0.15, "earth": 0.9, "reed": 0.8,
		"wealth": 0.2, "inequality": 0.3, "density": 0.2, "colour": 0.15, "round": 0.9, "flat_roofs": 0.0, "height": 0.0,
		"defence": 0.4, "hues": ["ochre", "red"], "sacred": "basilica", "tongue": "bantu"},
	"sahel_town": {"label": "Sahel mud-brick town",
		"summary": "banco courtyard houses with level roofs, buttresses and palm stakes, on a hot river plain",
		"heat": 0.95, "rain": 0.15, "altitude": 0.1, "relief": 0.02, "forest": 0.05, "stone": 0.05, "earth": 1.0, "lime": 0.1,
		"wealth": 0.5, "density": 0.7, "colour": 0.05, "flat_roofs": 1.0, "whitewash": 0.0, "height": 0.4,
		"water": "river", "purpose": "market", "hues": ["ochre"], "sacred": "dome", "tongue": "sahelian"},
	"desert_oasis": {"label": "Desert oasis ksar",
		"summary": "a walled knot of earth houses, terrace on terrace, the colour of the ground they stand on",
		"heat": 0.9, "rain": 0.05, "altitude": 0.35, "relief": 0.2, "forest": 0.0, "stone": 0.3, "earth": 1.0,
		"wealth": 0.35, "density": 0.95, "colour": 0.1, "flat_roofs": 1.0, "whitewash": 0.1, "height": 0.5,
		"defence": 0.9, "water": "pond", "hues": ["blue", "green"], "sacred": "dome", "tongue": "arabic"},
	"andean_highland": {"label": "Andean highland village",
		"summary": "stone and adobe houses under thatch and tile on a terraced mountainside in thin bright air",
		"heat": 0.8, "rain": 0.4, "altitude": 0.95, "relief": 0.75, "forest": 0.05, "stone": 0.9, "earth": 0.8, "reed": 0.6,
		"wealth": 0.3, "density": 0.45, "colour": 0.35, "flat_roofs": 0.0, "whitewash": 0.4, "height": 0.2,
		"hues": ["blue", "green", "red"], "sacred": "basilica", "tongue": "andean"},
	"japanese_farm": {"label": "Japanese farming village",
		"summary": "raised timber farmhouses with plaster walls under deep thatch and grey tile, each in its own plot",
		"heat": 0.55, "rain": 0.75, "altitude": 0.25, "relief": 0.3, "forest": 0.75, "stone": 0.3, "earth": 0.6,
		"wealth": 0.45, "density": 0.3, "colour": 0.0, "raised": 1.0, "swept_roof": 1.0, "eaves": 0.9, "height": 0.1,
		"whitewash": 0.35, "hues": ["black"], "sacred": "stave", "tongue": "nippon"},
	"asian_city": {"label": "East Asian merchant city quarter",
		"summary": "two-storey shop-houses shoulder to shoulder under grey tile, dark lattice fronts, white gable walls",
		"heat": 0.6, "rain": 0.7, "altitude": 0.05, "relief": 0.02, "forest": 0.35, "stone": 0.4, "earth": 0.8,
		"wealth": 0.7, "density": 1.0, "order": 0.8, "colour": 0.2, "raised": 1.0, "swept_roof": 1.0, "eaves": 0.8,
		"height": 0.7, "whitewash": 0.6, "defence": 0.6, "water": "river", "purpose": "market",
		"hues": ["black", "vermilion"], "sacred": "stave", "tongue": "sinitic"},
	"monsoon_delta": {"label": "Monsoon delta stilt village",
		"summary": "timber and bamboo houses raised over wet ground under steep palm thatch, verandas facing the water",
		"heat": 0.9, "rain": 0.9, "altitude": 0.02, "relief": 0.0, "forest": 0.6, "stone": 0.02, "earth": 0.4, "reed": 1.0,
		"wealth": 0.25, "density": 0.4, "colour": 0.15, "raised": 1.0, "round": 0.0, "swept_roof": 0.0, "openness": 1.0, "height": 0.0,
		"water": "river", "purpose": "fishing", "hues": ["sky", "green", "white"], "sacred": "stave", "tongue": "malay"},
	"rotting_frontier": {"label": "A frontier settlement left to rot",
		"summary": "sagging board houses, grey paintless walls, moss on every roof, more nettles than people",
		"heat": 0.4, "rain": 0.7, "altitude": 0.2, "forest": 0.7,
		"wealth": 0.12, "upkeep": 0.05, "inequality": 0.3, "density": 0.25, "colour": 0.1, "height": 0.1,
		"hues": ["grey", "black"], "sacred": "stave", "tongue": "english"},
	"jewel_harbour": {"label": "A rich and beautiful harbour town",
		"summary": "tall bright-washed houses along a quay, every shutter painted, tile roofs, flowers, a domed church",
		"heat": 0.7, "rain": 0.45, "altitude": 0.02, "relief": 0.35, "forest": 0.3, "stone": 0.7, "earth": 0.6, "lime": 0.8,
		"wealth": 0.9, "upkeep": 1.0, "density": 0.85, "colour": 0.95, "ornament": 0.85, "flat_roofs": 0.0,
		"whitewash": 0.15, "height": 0.85, "water": "coast", "purpose": "fishing",
		"hues": ["green", "blue", "turquoise", "bordeaux", "white"], "washes": ["yellow", "pink", "red", "ochre", "sky"],
		"sacred": "dome", "tongue": "romance"},
}

## The layout row each density reads as (VillageRealLayout: the share of
## buildings touching a neighbour), with the heat it belongs to. The nearest
## row is the culture everything the place does not say is built in.
const LAYOUT_CULTURES := [
	{"culture": &"eastern", "touching": 0.18, "heat": 0.4},
	{"culture": &"saharan", "touching": 0.19, "heat": 0.85},
	{"culture": &"norse", "touching": 0.24, "heat": 0.15},
	{"culture": &"east_asian", "touching": 0.29, "heat": 0.5},
	{"culture": &"english", "touching": 0.35, "heat": 0.4},
	{"culture": &"alpine", "touching": 0.36, "heat": 0.2},
	{"culture": &"moorish", "touching": 0.46, "heat": 0.8},
	{"culture": &"mediterranean", "touching": 0.57, "heat": 0.65},
	{"culture": &"frankish", "touching": 0.67, "heat": 0.4},
]

## What a roof covering costs a household, 0..1: a house type roofs itself
## from the coverings within reach of the tiers that live in it.
const ROOF_COST := {"thatch": 0.1, "turf": 0.18, "flat": 0.3, "shingle": 0.45, "tile": 0.7,
	"swept tile": 0.7, "slate": 0.85}

## Grime by climate: what paint weathers toward (VillageVernacular's own
## GRIME is the soot of a temperate town).
const GRIME_SOOT := Color("6e685e")
const GRIME_MOSS := Color("58604a")
const GRIME_DUST := Color("a09076")

## Ground by climate, as the dataset's surface names.
const GROUND := {
	"green": {"ground": "6f8748", "road": "8a7a5e", "common": "78954c", "verge": "688444", "yard": "8b7d60", "field": "8d8a4e", "wear": "86775b", "tread": "9a8a69"},
	"cold": {"ground": "5e7043", "road": "7c6b52", "common": "6c8a48", "verge": "5c7a3f", "yard": "72664a", "field": "7a7a49", "wear": "786950", "tread": "8a7a5c"},
	"dry": {"ground": "b2a685", "road": "cdbf9f", "common": "cfc3a6", "verge": "a69c78", "yard": "c9bb9c", "field": "ae9a6a", "wear": "bfb294", "tread": "d6c9aa"},
	"jungle": {"ground": "4f7038", "road": "a0603e", "common": "9a6a44", "verge": "44682f", "yard": "a26a46", "field": "6c7f3c", "wear": "96603f", "tread": "ad7450"},
}

static var _cache: Dictionary = {}
static var _preset_full: Dictionary = {}


# ================================================================ reading

static func feature_names() -> Array[String]:
	var out: Array[String] = []
	for k in FEATURES:
		out.append(String(k))
	return out


static func preset_ids() -> Array[String]:
	var out: Array[String] = []
	for k in PRESETS:
		out.append(String(k))
	return out


## A preset's stated features (no label or summary); {} when there is none.
static func preset(id: Variant) -> Dictionary:
	var row: Dictionary = PRESETS.get(String(id).to_lower(), {})
	var out := {}
	for k in row:
		if FEATURES.has(String(k)):
			out[String(k)] = row[k]
	return out


## A place request read and judged: {"features": the STATED features with any
## `like` preset folded under them, "like": the preset id or "", "errors"}.
## A place is {feature: value}, optionally with "like": a preset the stated
## features are laid over.
static func parse(v: Variant) -> Dictionary:
	var errors: Array[String] = []
	var stated := {}
	var like := ""
	if v is String or v is StringName:
		v = {"like": String(v)}
	if not v is Dictionary:
		return {"features": {}, "like": "", "errors": ["place: wants {feature: value} or a preset id"]}
	if v.has("like"):
		like = String(v["like"]).to_lower()
		if not PRESETS.has(like):
			errors.append("place: no preset '%s' (one of %s)" % [like, str(preset_ids())])
		else:
			stated = preset(like)
	for key in v:
		var k := String(key)
		if k == "like":
			continue
		if not FEATURES.has(k):
			errors.append("place: no feature '%s' (one of %s)" % [k, str(feature_names())])
			continue
		var why := _value_error(k, v[key])
		if not why.is_empty():
			errors.append("place: " + why)
			continue
		stated[k] = _plain(k, v[key])
	return {"features": stated, "like": like, "errors": errors}


static func _value_error(k: String, value: Variant) -> String:
	var row: Dictionary = FEATURES[k]
	match String(row["kind"]):
		"share":
			if not (value is float or value is int) or not is_finite(float(value)) \
					or float(value) < 0.0 or float(value) > 1.0:
				return "%s wants a number from 0 (%s) to 1 (%s)" % [k, row.get("low", ""), row.get("high", "")]
		"name":
			var names: Array = row.get("names", TONGUES.keys() if k == "tongue" else [])
			if not (value is String or value is StringName) or not String(value) in names:
				return "%s wants one of %s" % [k, str(names)]
		"names":
			if not value is Array or (value as Array).is_empty():
				return "%s wants a list of paints from %s" % [k, str(HUES.keys())]
			for h in value:
				if not HUES.has(String(h)):
					return "%s: no paint '%s' (one of %s)" % [k, str(h), str(HUES.keys())]
	return ""


static func _plain(k: String, value: Variant) -> Variant:
	match String(FEATURES[k]["kind"]):
		"share":
			return float(value)
		"name":
			return String(value)
	var out: Array = []
	for h in value:
		out.append(String(h))
	return out


## A point between two places: every number interpolated, every name and list
## taken from whichever end is nearer. Both are derived first, so the result
## states every feature.
static func mix(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var fa := derive(parse(a)["features"])
	var fb := derive(parse(b)["features"])
	var out := {}
	for k in FEATURES:
		if String(FEATURES[k]["kind"]) == "share":
			out[k] = lerpf(float(fa[k]), float(fb[k]), clampf(t, 0.0, 1.0))
		else:
			out[k] = fa[k] if t < 0.5 else fb[k]
	if float(out["defence"]) < 0.0:
		out.erase("defence")
	return out


# ================================================================ deriving

## Every feature, from the stated ones: a stated feature is kept, the rest
## follow from the land. The order matters and is the argument: climate, then
## what grows, then what there is to build with, then what people do with it.
static func derive(stated: Dictionary) -> Dictionary:
	var f := {}
	for k in ["heat", "rain", "altitude", "wealth", "inequality", "density", "order", "swept_roof"]:
		f[k] = clampf(float(stated.get(k, FEATURES[k]["default"])), 0.0, 1.0)
	f["defence"] = float(stated.get("defence", -1.0))
	f["water"] = String(stated.get("water", ""))
	f["purpose"] = String(stated.get("purpose", ""))
	var heat: float = f["heat"]
	var rain: float = f["rain"]
	var alt: float = f["altitude"]
	var wealth: float = f["wealth"]
	var density: float = f["density"]
	f["relief"] = _s(stated, "relief", clampf(alt * 0.8, 0.0, 1.0))
	var relief: float = f["relief"]
	var w := warmth(f)
	var cold := 1.0 - w
	var sn := snow(f)
	var arid := 1.0 - rain
	# what grows: rain makes forest; the tree line and the tundra take it away
	f["forest"] = _s(stated, "forest", clampf(1.35 * rain - 0.2, 0.0, 1.0)
		* clampf(1.25 - 2.75 * maxf(alt - 0.6, 0.0), 0.0, 1.0) * clampf(0.5 + 5.0 * w, 0.0, 1.0))
	var forest: float = f["forest"]
	# what there is to build with
	f["timber"] = _s(stated, "timber", forest)
	f["stone"] = _s(stated, "stone", clampf(0.2 + 0.45 * alt + 0.45 * relief, 0.0, 1.0))
	f["earth"] = _s(stated, "earth", clampf(0.3 + 0.5 * arid + 0.15 * (1.0 - relief)
		- 0.35 * clampf((0.35 - w) / 0.35, 0.0, 1.0), 0.0, 1.0))
	f["reed"] = _s(stated, "reed", clampf(0.2 + 0.6 * rain - 0.5 * alt + 0.1 * (1.0 - forest), 0.0, 1.0))
	f["lime"] = _s(stated, "lime", clampf(0.05 + 0.55 * float(f["stone"]) + 0.2 * w * arid, 0.0, 1.0))
	# the people
	f["upkeep"] = _s(stated, "upkeep", lerpf(0.6, 1.0, wealth))
	f["colour"] = _s(stated, "colour", clampf(0.2 + 0.35 * wealth, 0.0, 1.0))
	f["ornament"] = _s(stated, "ornament", clampf(0.15 + 0.6 * wealth, 0.0, 1.0))
	# the habits the land teaches
	f["flat_roofs"] = _s(stated, "flat_roofs", smoothstep(0.55, 0.85, arid) * (1.0 - sn)
		* clampf(2.2 * w - 0.3, 0.0, 1.0))
	f["whitewash"] = _s(stated, "whitewash", clampf(1.5 * float(f["lime"]) * smoothstep(0.45, 0.8, w)
		* (0.4 + 0.6 * arid) * (0.4 + 0.6 * wealth), 0.0, 1.0))
	f["eaves"] = _s(stated, "eaves", clampf(0.2 + 0.45 * rain + 0.25 * w * rain, 0.0, 1.0))
	f["openness"] = _s(stated, "openness", clampf(1.3 * w - 0.45, 0.0, 1.0))
	f["raised"] = _s(stated, "raised", clampf((w - 0.55) * 2.5, 0.0, 1.0) * clampf((rain - 0.6) * 2.5, 0.0, 1.0))
	f["round"] = _s(stated, "round", clampf((w - 0.6) * 2.5, 0.0, 1.0) * clampf(1.0 - 2.2 * wealth, 0.0, 1.0)
		* sqrt(float(f["reed"])) * (1.0 - density))
	f["long"] = _s(stated, "long", clampf((cold - 0.55) * 2.5, 0.0, 1.0) * float(f["timber"]) * (1.0 - density))
	f["height"] = _s(stated, "height", clampf(0.1 + 0.5 * density + 0.2 * wealth + 0.25 * relief, 0.0, 1.0))
	# the names a place is known by: stated, or the nearest preset's
	var near := "" if stated.has("tongue") else nearest_preset(f)
	f["tongue"] = String(stated.get("tongue", PRESETS.get(near, {}).get("tongue", "english")))
	if stated.has("sacred"):
		f["sacred"] = String(stated["sacred"])
	elif float(f["timber"]) > 0.65 and float(f["stone"]) < 0.6 and w < 0.6:
		f["sacred"] = "stave"
	elif w > 0.65:
		f["sacred"] = "dome"
	elif rain > 0.5:
		f["sacred"] = "spire"
	else:
		f["sacred"] = "basilica"
	if stated.has("hues"):
		f["hues"] = (stated["hues"] as Array).duplicate()
	else:
		# earth pigments are everywhere; lime gives white, money gives blue
		var hues: Array = ["red", "ochre"]
		if float(f["lime"]) > 0.5 or cold > 0.6:
			hues.append("white")
		if wealth > 0.55:
			hues.append("blue")
		if rain > 0.5:
			hues.append("green")
		f["hues"] = hues
	# a wash is lime and an earth pigment, nearly everywhere
	f["washes"] = (stated["washes"] as Array).duplicate() if stated.has("washes") else ["ochre", "red", "yellow"]
	return f


static func _s(stated: Dictionary, k: String, derived: float) -> float:
	return clampf(float(stated[k]), 0.0, 1.0) if stated.has(k) else clampf(derived, 0.0, 1.0)


## The heat a house feels: the climate, less what the height takes.
static func warmth(f: Dictionary) -> float:
	return clampf(float(f["heat"]) - 0.45 * float(f["altitude"]), 0.0, 1.0)


## How much snow lies on a roof: cold and wet together.
static func snow(f: Dictionary) -> float:
	return clampf((0.42 - warmth(f)) / 0.3, 0.0, 1.0) * clampf(float(f["rain"]) * 1.6, 0.0, 1.0)


## The preset nearest a (partly derived) place, over the land and the people:
## whose tongue and landmark an unstated place borrows.
static func nearest_preset(f: Dictionary) -> String:
	var best := ""
	var best_d := INF
	for id in PRESETS:
		var p: Dictionary = PRESETS[id]
		var d := 0.0
		for k in ["heat", "rain", "altitude", "density", "wealth"]:
			var pv := float(p.get(k, FEATURES[k]["default"]))
			var weight := 2.0 if k in ["heat", "rain"] else 1.0
			d += weight * (float(f[k]) - pv) * (float(f[k]) - pv)
		if d < best_d - 1e-12:
			best_d = d
			best = String(id)
	return best


## The place in a few words, from its features: "hot dry coast, stone and
## lime, rich, well kept". What an unnamed place is labelled.
static func words(f: Dictionary) -> String:
	var w := warmth(f)
	var parts := PackedStringArray()
	var climate := "cold" if w < 0.3 else ("cool" if w < 0.45 else ("mild" if w < 0.6 else ("warm" if w < 0.75 else "hot")))
	var rain := float(f["rain"])
	climate += " " + ("desert" if rain < 0.15 else ("dry" if rain < 0.4 else ("" if rain < 0.6 else ("wet" if rain < 0.85 else "rainforest"))))
	var alt := float(f["altitude"])
	var land := "mountain" if alt >= 0.6 else ("upland" if alt >= 0.3 else ("hillside" if float(f["relief"]) > 0.45 else "lowland"))
	if String(f["water"]) in ["coast", "lake", "river"]:
		land += " " + String(f["water"])
	parts.append((climate.strip_edges() + " " + land).strip_edges())
	var mats: Array = []
	for m in ["timber", "stone", "earth"]:
		if float(f[m]) >= 0.55:
			mats.append(m)
	if not mats.is_empty():
		parts.append(" and ".join(PackedStringArray(mats)))
	var wealth := float(f["wealth"])
	parts.append("destitute" if wealth < 0.15 else ("poor" if wealth < 0.35 else ("middling" if wealth < 0.6 else ("prosperous" if wealth < 0.8 else "rich"))))
	var up := float(f["upkeep"])
	parts.append("rotting" if up < 0.2 else ("run down" if up < 0.5 else ("lived in" if up < 0.8 else "well kept")))
	var dens := float(f["density"])
	parts.append("scattered" if dens < 0.25 else ("loose" if dens < 0.55 else ("close-built" if dens < 0.8 else "packed")))
	return ", ".join(parts)


# ============================================================ synthesising

## The region row a place makes: exactly the shape of a row of
## `vernacular_regions.json`, so the generator draws from it and the check
## judges by it. Pure in the stated features.
static func synthesise(stated: Dictionary, like := "") -> Dictionary:
	var f := derive(stated)
	var w := warmth(f)
	var decay := 1.0 - float(f["upkeep"])
	var roofs := _roofs(f)
	var trim := _trim(f)
	var houses := _houses(f, roofs)
	# only the coverings some house wears stay in the row
	var used := {}
	for tid in houses:
		for rid in houses[tid]["roofs"]:
			used[String(rid)] = true
	for rid in roofs.keys():
		if not used.has(String(rid)):
			roofs.erase(rid)
	# the region's own wall clusters: every type's, each once, by type weight
	var walls: Array = []
	for tid in houses:
		var share := 0.0
		for tier in houses[tid]["tiers"]:
			share += float(houses[tid]["tiers"][tier])
		for c in houses[tid]["walls"]:
			_add(walls, String(c["name"]), float(c["w"]) * maxf(share, 0.05), c["hex"])
	var ineq := float(f["inequality"])
	var grime := GRIME_SOOT.lerp(GRIME_MOSS, clampf(float(f["rain"]) * 1.4 - 0.4, 0.0, 1.0) * clampf(w * 2.0, 0.3, 1.0))
	grime = grime.lerp(GRIME_DUST, smoothstep(0.5, 0.85, 1.0 - float(f["rain"])))
	var label := String(PRESETS.get(like, {}).get("label", "")) if stated == preset(like) else ""
	var row := {
		"label": label if not label.is_empty() else words(f).capitalize(),
		"summary": String(PRESETS.get(like, {}).get("summary", "")) if not label.is_empty() else words(f),
		"culture": String(layout_culture(f)),
		"aliases": [],
		"place": {"schema": SCHEMA, "like": like, "stated": stated.duplicate(true), "features": f},
		"wealth": {
			"rich": clampf(0.03 + 0.24 * ineq, 0.0, 0.4), "poor": clampf(0.06 + 0.5 * ineq, 0.0, 0.5),
			"weathering": {"poor": clampf(0.06 + 0.62 * decay, 0.0, 0.7),
				"middle": clampf(0.02 + 0.5 * decay, 0.0, 0.6), "rich": clampf(0.38 * decay, 0.0, 0.45)},
			"grime": grime.to_html(false),
			# up to four degrees of lean on the poorest house of a rotting place
			"jank": {"poor": _lean((decay - 0.3) * 0.5, 0.35), "middle": _lean((decay - 0.45) * 0.45, 0.25),
				"rich": _lean((decay - 0.65) * 0.35, 0.12)},
		},
		"size": {"area_scale": clampf(0.86 + 0.28 * float(f["wealth"]) - 0.08 * float(f["density"]), 0.6, 1.3)},
		"walls": _tidy(walls, 0.0),
		"trim": trim,
		"roofs": roofs,
		"houses": houses,
		"shop": _shop_type(f, houses),
		"landmark": _landmark(f, walls, roofs),
		"plants": _plants(f),
		"ground": _ground(f),
		"names": (TONGUES[String(f["tongue"])] as Dictionary).duplicate(true),
	}
	row["signature"] = _signature(row)
	return row


## A lean too small to see is no lean (and no warp to pay for).
static func _lean(v: float, cap: float) -> float:
	return 0.0 if v < 0.04 else snappedf(minf(v, cap), 0.01)


## The culture everything the place does not say is built in: the measured
## layout row whose crowding and climate are nearest.
static func layout_culture(f: Dictionary) -> StringName:
	# density 0..1 spans the surveyed range of touching shares, 0.15..0.7
	var touching := lerpf(0.15, 0.7, float(f["density"]))
	var w := warmth(f)
	if float(f["swept_roof"]) >= 0.5 and float(f["density"]) < 0.6:
		return &"east_asian"
	var best: StringName = &"english"
	var best_d := INF
	for row in LAYOUT_CULTURES:
		# a culture also names the castle and the temple: a frontier in the
		# rain is not laid out as a Saharan town however scattered it is
		var c: StringName = row["culture"]
		if c == &"east_asian" or (c in [&"saharan", &"moorish"] and w < 0.6) \
				or (c == &"mediterranean" and w < 0.5) or (c in [&"norse", &"alpine"] and w > 0.45) \
				or (c in [&"english", &"frankish", &"eastern"] and w > 0.7):
			continue
		var d := absf(touching - float(row["touching"])) * 2.5 + absf(w - float(row["heat"])) * 0.5
		if d < best_d - 1e-12:
			best_d = d
			best = row["culture"]
	return best


# ---- colours

static func _c(name: String, weight: float, hex: Array) -> Dictionary:
	return {"name": name, "w": weight, "hex": [String(hex[0]), String(hex[1])]}


## Add a cluster to a list, or its weight to the one of that name.
static func _add(list: Array, name: String, weight: float, hex: Array) -> void:
	if weight <= 0.0:
		return
	for c in list:
		if String(c["name"]) == name:
			c["w"] = float(c["w"]) + weight
			return
	list.append(_c(name, weight, hex))


## Weights rounded and scaled to sum to 1, the small ones dropped, so a row
## reads like one a person wrote.
static func _tidy(list: Array, floor_w := 0.03) -> Array:
	var total := 0.0
	for c in list:
		total += float(c["w"])
	var out: Array = []
	var kept := 0.0
	for c in list:
		if float(c["w"]) / maxf(total, 1e-9) >= floor_w:
			out.append(c)
			kept += float(c["w"])
	if out.is_empty() and not list.is_empty():
		out = [list[0]]
		kept = float(list[0]["w"])
	for c in out:
		c["w"] = snappedf(float(c["w"]) / maxf(kept, 1e-9), 0.001)
		c["w"] = maxf(float(c["w"]), 0.001)
	return out


static func _hues(f: Dictionary) -> Array:
	return f["hues"]


## Bare timber by climate: tarred and silvered in the cold wet, bleached and
## dark hardwood in the heat.
static func _timber_bare(f: Dictionary, list: Array, weight: float) -> void:
	var w := warmth(f)
	var cool := 1.0 - smoothstep(0.45, 0.7, w)
	_add(list, "tarred timber", weight * 0.3 * cool * clampf(float(f["rain"]) * 1.6, 0.0, 1.0), ["3d3129", "2e251f"])
	_add(list, "weathered timber", weight * (0.35 * cool + 0.1), ["716557", "5c5247"])
	_add(list, "brown timber", weight * 0.35, ["5c4532", "48372b"])
	_add(list, "sun-bleached timber", weight * 0.4 * (1.0 - cool), ["8a7658", "75634a"])
	_add(list, "dark hardwood", weight * 0.3 * (1.0 - cool), ["4f3b2a", "3e2e21"])


## Walls of boards or logs: bare, or painted where there is paint.
static func _walls_timber(f: Dictionary) -> Array:
	var out: Array = []
	var paint := clampf(float(f["colour"]) * 1.2, 0.0, 0.9)
	_timber_bare(f, out, 1.0 - paint)
	var hues := _hues(f)
	for h in hues:
		_add(out, "%s paint" % String(h), paint / float(hues.size()), HUES[String(h)]["wall"])
	return _tidy(out)


## Plaster: the infill of a frame and the coat on rubble or mud.
static func _plaster(f: Dictionary, list: Array, weight: float) -> void:
	var white := float(f["whitewash"])
	var tint := clampf(float(f["colour"]) * 1.1 - 0.15, 0.0, 0.9) * (1.0 - white)
	var plain := maxf(1.0 - white - tint, 0.0)
	_add(list, "lime white", weight * white, ["f7f6f1", "ecebe4"])
	_add(list, "cream plaster", weight * plain * 0.55, ["f0e4cc", "e3d4b4"])
	_add(list, "earth plaster", weight * plain * 0.45, ["cab48d", "b59e77"])
	var washes: Array = f["washes"]
	for h in washes:
		_add(list, "%s wash" % String(h), weight * tint / float(washes.size()), HUES[String(h)]["wash"])


static func _walls_plaster(f: Dictionary) -> Array:
	var out: Array = []
	_plaster(f, out, 1.0)
	return _tidy(out)


## Stone, bare or rendered: grey where it is wet and cold, honey where it is
## warm and dry; lime and colour go over it as the place has them.
static func _walls_stone(f: Dictionary) -> Array:
	var out: Array = []
	var w := warmth(f)
	# a warm country renders its rubble and colours the render
	var coat := clampf(float(f["whitewash"]) + 0.9 * float(f["colour"]) * smoothstep(0.35, 0.6, w), 0.0, 0.95)
	var warm := smoothstep(0.35, 0.6, w) * (0.6 + 0.4 * (1.0 - float(f["rain"])))
	_add(out, "grey stone", (1.0 - coat) * (1.0 - warm) * 0.65, ["8a8780", "74716b"])
	_add(out, "dark stone", (1.0 - coat) * (1.0 - warm) * 0.35, ["6b6a66", "585753"])
	_add(out, "honey limestone", (1.0 - coat) * warm * 0.6, ["d9c59e", "c5ad82"])
	_add(out, "sandstone", (1.0 - coat) * warm * 0.4, ["c9a878", "b3915f"])
	_plaster(f, out, coat)
	return _tidy(out)


## Earth: adobe in the dry, red laterite in the hot wet, pale cob between;
## limewashed as the place has lime and the habit.
static func _walls_earth(f: Dictionary) -> Array:
	var out: Array = []
	var w := warmth(f)
	var white := float(f["whitewash"])
	var wet_hot := smoothstep(0.6, 0.85, w) * smoothstep(0.5, 0.8, float(f["rain"]))
	var dry := smoothstep(0.45, 0.8, 1.0 - float(f["rain"])) * smoothstep(0.4, 0.7, w)
	var mild := maxf(1.0 - wet_hot - dry, 0.0)
	_add(out, "lime white", white, ["f7f6f1", "ecebe4"])
	_add(out, "red laterite", (1.0 - white) * wet_hot * 0.55, ["b0603c", "934c2e"])
	_add(out, "mud", (1.0 - white) * (wet_hot * 0.45 + dry * 0.25), ["b98a5e", "94663d"])
	_add(out, "adobe", (1.0 - white) * dry * 0.5, ["c98b58", "a66d40"])
	_add(out, "pale clay", (1.0 - white) * (dry * 0.25 + mild * 0.3), ["d9cdb1", "c9bba1"])
	_add(out, "cob", (1.0 - white) * mild * 0.4, ["efe7d3", "dbcfb4"])
	_add(out, "earth plaster", (1.0 - white) * mild * 0.3, ["cab48d", "b59e77"])
	return _tidy(out)


## Doors, shutters and frames: bare wood, or the place's paints.
static func _trim(f: Dictionary) -> Array:
	var out: Array = []
	var paint := clampf(float(f["colour"]) * 1.15, 0.0, 0.95)
	_timber_bare(f, out, 1.0 - paint)
	var hues := _hues(f)
	for h in hues:
		_add(out, "%s paint" % String(h), paint / float(hues.size()), HUES[String(h)]["trim"])
	return _tidy(out)


# ---- roofs

## Every covering the place could roof with, weighted by what the land gives
## and what the people can pay. The pitch follows the rain and the snow.
static func _roofs(f: Dictionary) -> Dictionary:
	var w := warmth(f)
	var cold := 1.0 - w
	var rain := float(f["rain"])
	var wealth := float(f["wealth"])
	var sn := snow(f)
	var decay := 1.0 - float(f["upkeep"])
	# a round house, a longhouse and a raised house are pitched whatever the
	# rest of the place does, so they keep a share of the pitched coverings
	var special := clampf(float(f["round"]) + float(f["raised"]) + float(f["long"]), 0.0, 1.0)
	var flat := float(f["flat_roofs"]) * (1.0 - special)
	var pitched := 1.0 - flat
	# the pitch a roof needs to shed what falls on it
	var p := lerpf(0.42, 1.2, clampf(0.75 * rain + 0.5 * sn, 0.0, 1.0))
	var eave := lerpf(0.2, 1.0, float(f["eaves"]))
	var forms := {"gable": 0.6, "half_hipped": 0.12 + 0.3 * rain * (1.0 - smoothstep(0.5, 0.75, w)),
		"hipped": 0.1 + 0.35 * smoothstep(0.5, 0.8, w)}
	var out := {}
	var weights := {
		# thatch grows where it rains, and is what a house wears until it can pay
		"thatch": pow(float(f["reed"]), 1.6) * (1.25 - wealth) * pitched
			* (1.0 - 0.75 * smoothstep(0.6, 0.9, float(f["density"]))),
		"turf": cold * cold * float(f["timber"]) * clampf(rain * 1.5, 0.0, 1.0) * (1.15 - wealth) * pitched
			* smoothstep(0.45, 0.65, cold),
		# split timber: the middling roof of a wooded country, left behind by the rich
		"shingle": pow(float(f["timber"]), 1.5) * (0.35 + 0.65 * cold)
			* (0.4 + 0.6 * clampf(1.0 - absf(wealth - 0.45) * 1.6, 0.0, 1.0)) * pitched,
		# slate and stone slab: a wet or cold country with stone and money
		"slate": float(f["stone"]) * smoothstep(0.35, 0.6, float(f["stone"])) * (0.2 + 0.8 * wealth)
			* smoothstep(0.4, 0.75, maxf(cold, rain)) * pitched * (1.0 - float(f["swept_roof"])),
		"tile": maxf(float(f["earth"]), 0.35) * (0.12 + 0.88 * wealth) * (0.3 + 0.7 * smoothstep(0.2, 0.55, w))
			* pitched * (1.0 - float(f["swept_roof"])),
		"swept tile": float(f["swept_roof"]) * (0.2 + 0.8 * wealth) * pitched,
		"flat": flat * 1.2,
	}
	# a country settles on its coverings: the likelier ones crowd the rest out
	var total := 0.0
	for k in weights:
		weights[k] = pow(float(weights[k]), 1.4)
		total += float(weights[k])
	for k in weights:
		weights[k] = float(weights[k]) / maxf(total, 1e-9)
	var straw := smoothstep(0.6, 0.85, w) * smoothstep(0.5, 0.8, rain)   # palm in the hot wet
	out["thatch"] = {"w": weights["thatch"], "types": forms.duplicate(), "material": "thatch",
		"pitch": [snappedf(clampf(maxf(p, 0.9), 0.9, 1.3), 0.01), snappedf(clampf(maxf(p, 0.9) + 0.25, 1.0, 1.5), 0.01)],
		"eave": [snappedf(clampf(eave, 0.35, 1.0), 0.01), snappedf(clampf(eave * 0.8, 0.3, 0.9), 0.01)],
		"colours": _tidy([
			_c("straw", (1.0 - straw) * (1.0 - 0.8 * decay), ["a28e5e", "8c794e"]),
			_c("old thatch", (1.0 - straw) * (0.4 + decay), ["7f6e4a", "6b5c3e"]),
			_c("palm thatch", straw * (1.0 - 0.7 * decay), ["8f7a4e", "76633e"]),
			_c("rotten thatch", (0.02 + decay * decay) * (0.5 + rain), ["5e5a44", "4c4a39"])])}
	out["turf"] = {"w": weights["turf"], "types": {"gable": 1.0}, "material": "earth", "pitch": [0.45, 0.62],
		"colours": _tidy([_c("summer turf", 0.6, ["607b3b", "4f6931"]), _c("dry turf", 0.25, ["7e7b46", "6a673b"]),
			_c("moss turf", 0.15 + decay, ["4b5b36", "3e4b2d"])])}
	out["shingle"] = {"w": weights["shingle"], "types": forms.duplicate(), "material": "shingle",
		"pitch": [snappedf(clampf(p - 0.12, 0.6, 1.2), 0.01), snappedf(clampf(p + 0.15, 0.75, 1.4), 0.01)],
		"eave": [snappedf(clampf(eave, 0.3, 1.1), 0.01), snappedf(clampf(eave * 0.8, 0.25, 0.9), 0.01)],
		"colours": _tidy([
			_c("tarred shingle", 0.5 * (1.0 - smoothstep(0.45, 0.7, w)) * (1.0 - decay), ["3e332b", "2f2721"]),
			_c("silver shingle", 0.4 + 0.3 * decay, ["6f6b63", "5b5851"]),
			_c("brown shingle", 0.3, ["6a4a34", "4e3626"]),
			_c("mossy shingle", decay * rain, ["565a45", "464a39"])])}
	out["slate"] = {"w": weights["slate"], "types": forms.duplicate(), "material": "slate",
		"pitch": [snappedf(clampf(p - 0.2, 0.5, 1.1), 0.01), snappedf(clampf(p + 0.1, 0.65, 1.35), 0.01)],
		"colours": _tidy([_c("blue slate", 0.55, ["4a4f57", "353a41"]), _c("grey stone slab", 0.35, ["77756f", "63615c"]),
			_c("lichen slate", 0.1 + decay * rain, ["676a58", "55584a"])])}
	var tile_p := lerpf(0.3, 0.8, clampf(0.9 * rain + 0.5 * sn - 0.25, 0.0, 1.0))
	out["tile"] = {"w": weights["tile"], "types": {"gable": 0.65, "hipped": 0.35}, "material": "tile",
		"pitch": [snappedf(tile_p, 0.01), snappedf(tile_p + 0.14, 0.01)],
		"colours": _tidy([_c("fired terracotta", 0.45 * (1.0 - 0.7 * decay), ["c26c40", "ab5a34"]),
			_c("old tile", 0.35 + 0.3 * decay, ["aa694c", "8e5642"]),
			_c("lichen tile", 0.2 + 0.6 * decay, ["b59174", "9a785e"])])}
	out["swept tile"] = {"w": weights["swept tile"], "types": {"irimoya": 1.0}, "material": "tile", "pitch": [0.72, 0.88],
		"colours": _tidy([_c("grey tile", 0.6, ["5c6267", "4b5156"]), _c("blue-black tile", 0.3 * (1.0 - decay), ["3d444b", "31373d"]),
			_c("brown tile", 0.1 + 0.4 * decay, ["5f4d41", "4e3f35"])])}
	var limed := float(f["whitewash"]) >= 0.5
	out["flat"] = {"w": weights["flat"], "types": {"flat": 1.0}, "material": "earth", "pitch": [0.0, 0.0],
		"eave": [0.15, 0.15] if limed else [0.22, 0.22],
		"colours": [_c("lime", 1.0, ["f4f3ee", "e7e5dd"])] if limed else _tidy([
			_c("beaten earth", 0.7, ["b58a58", "92704a"]), _c("pale earth", 0.3, ["c9b08a", "b0966f"])])}
	# what nobody would ever roof with here is not a recipe
	for k in out.keys():
		if float(out[k]["w"]) < 0.06:
			out.erase(k)
		else:
			out[k]["w"] = snappedf(float(out[k]["w"]), 0.001)
	if out.is_empty():
		out["thatch"] = {"w": 1.0, "types": forms.duplicate(), "material": "thatch", "pitch": [0.9, 1.2],
			"colours": [_c("straw", 1.0, ["a28e5e", "8c794e"])]}
	return out


## The pitched coverings a house type whose households lie in a cost band
## would wear; the nearest one when the band holds none.
## The commonest covering of the place is on every kind of house but the
## great one (`common` false): a poor Provencal roof is still tile.
static func _coverings(roofs: Dictionary, lo: float, hi: float, forms: Array, common := true) -> Array:
	var out: Array = []
	var near := ""
	var near_d := INF
	var top := ""
	for rid in roofs:
		var fits := false
		for form in roofs[rid]["types"]:
			fits = fits or String(form) in forms
		if not fits:
			continue
		if top.is_empty() or float(roofs[rid]["w"]) > float(roofs[top]["w"]):
			top = String(rid)
		var cost := float(ROOF_COST.get(String(rid), 0.5))
		if cost >= lo - 1e-9 and cost <= hi + 1e-9:
			out.append(String(rid))
		var d := absf(cost - (lo + hi) * 0.5)
		if d < near_d - 1e-12:
			near_d = d
			near = String(rid)
	if common and not top.is_empty() and not out.has(top):
		out.append(top)
	if out.is_empty() and not near.is_empty():
		out.append(near)
	return out


# ---- houses

## The house types of the place: each a chassis the features call for, with
## the look the features give it, lived in by the tiers that can afford it.
static func _houses(f: Dictionary, roofs: Dictionary) -> Dictionary:
	var w := warmth(f)
	var wealth := float(f["wealth"])
	var density := float(f["density"])
	var flat := float(f["flat_roofs"])
	var height := float(f["height"])
	var order := float(f["order"])
	var pitched_forms := ["gable", "half_hipped", "hipped"]
	# how the walls of an ordinary pitched house are made, by what there is:
	# stone costs labour and earth costs none
	var mat := {
		"timber": pow(float(f["timber"]), 1.5),
		"stone": pow(float(f["stone"]), 1.5) * (0.45 + 0.55 * wealth),
		"earth": pow(float(f["earth"]), 1.5) * (1.1 - 0.5 * wealth) * (1.0 - 0.6 * smoothstep(0.5, 0.9, float(f["rain"])) * (1.0 - smoothstep(0.6, 0.8, w))),
	}
	var mat_total := 0.0
	for m in mat:
		mat_total += float(mat[m])
	if mat_total < 1e-6:
		mat = {"earth": 1.0}
		mat_total = 1.0
	var mats := {}
	for m in mat:
		var share := float(mat[m]) / mat_total
		# a planned place builds in one material; a grown one in whatever came
		if share >= lerpf(0.18, 0.4, order):
			mats[m] = share
	if mats.is_empty():
		var top := ""
		for m in mat:
			if top.is_empty() or float(mat[m]) > float(mat[top]):
				top = m
		mats[top] = 1.0
	# the shares of households in each special form; the rest live in the
	# ordinary pitched or flat-roofed house
	var special: float = clampf(float(f["round"]) + float(f["raised"]) + float(f["long"]), 0.0, 1.0)
	var norm := 1.0 / maxf(float(f["round"]) + float(f["raised"]) + float(f["long"]), 1.0)
	var s_round := float(f["round"]) * norm
	var s_raised := float(f["raised"]) * norm
	var s_long := float(f["long"]) * norm
	var s_flat := (1.0 - special) * flat
	var s_pitch := (1.0 - special) * (1.0 - flat)
	var out := {}
	var has_pitched := not _coverings(roofs, 0.0, 1.0, pitched_forms).is_empty()
	if s_round >= 0.06 and roofs.has("thatch"):
		out["round house"] = _type(f, "a round house: one room under a cone of thatch", &"roundhouse",
			{"poor": s_round, "middle": s_round * 0.7, "rich": s_round * 0.15}, {"1": 1.0}, 0.75, ["thatch"],
			{"conical": 1.0}, _walls_earth(f) if float(f["earth"]) >= float(f["timber"]) * 0.5 else _walls_timber(f), {})
	if s_long >= 0.06 and has_pitched:
		out["longhouse"] = _type(f, "the longhouse: one long roof over the household and its work", &"longhall",
			{"poor": s_long * 0.4, "middle": s_long, "rich": s_long * 0.8}, {"1": 1.0}, 1.25,
			_coverings(roofs, 0.0, 0.6, pitched_forms), {},
			_walls_timber(f) if float(f["timber"]) >= 0.5 else _walls_stone(f),
			{"timber": 1.0 if float(f["timber"]) >= 0.5 else 0.0, "framing": ["close_studding"], "studs": [0.34, 0.48],
				"braces": 0.0, "rail": 0.0, "jetty": 0.0, "dormers": 0.0, "stone_ground": 0.0})
	if s_raised >= 0.06:
		var swept := float(f["swept_roof"]) >= 0.5
		var covers := _coverings(roofs, 0.0, 1.0, ["irimoya"]) if swept else []
		if swept and roofs.has("thatch") and (covers.is_empty() or density < 0.6 or wealth < 0.5):
			covers.append("thatch")
		if covers.is_empty():
			covers = _coverings(roofs, 0.0, 0.6, pitched_forms)
		var two := clampf((height - 0.35) * 1.4, 0.0, 0.8)
		var infill := _walls_plaster(f) if float(f["earth"]) + float(f["lime"]) >= float(f["timber"]) else _walls_timber(f)
		if not covers.is_empty():
			out["raised house"] = _type(f, "a timber house with its floor raised clear of the ground, under deep eaves",
				&"asian", {"poor": s_raised, "middle": s_raised, "rich": s_raised * 0.6},
				{"1": 1.0 - two, "2": two}, 1.0, covers, {"irimoya": 1.0}, infill, {"framing": ["square_panel"], "braces": 0.0})
			if density >= 0.6 and swept:
				var dark := _walls_timber(f)
				out["shop-house"] = _type(f, "the town house of the street: narrow, dark-fronted, a shop below", &"asian",
					{"poor": s_raised * 0.3, "middle": s_raised * 0.8, "rich": s_raised * 0.9},
					{"1": 0.25, "2": 0.75}, 0.9, _coverings(roofs, 0.5, 1.0, ["irimoya"]) if roofs.has("swept tile") else covers,
					{"irimoya": 1.0}, dark, {"framing": ["square_panel"], "braces": 0.0},
					{"market": 2.0, "crossroads": 1.8, "farming": 0.4})
	if s_flat >= 0.06 and roofs.has("flat"):
		var earthy := float(f["earth"]) >= float(f["stone"])
		var limed := float(f["whitewash"]) >= 0.5
		var walls: Array = _walls_earth(f) if earthy else _walls_stone(f)
		var two := clampf(height * 1.3 - 0.1, 0.0, 0.85)
		if limed or not earthy:
			# rendered masonry under a level roof behind its parapet
			out["cube house"] = _type(f, "a rendered cube under a level roof", &"mediterranean",
				{"poor": s_flat, "middle": s_flat * 0.8, "rich": s_flat * 0.3}, {"1": 1.0 - two, "2": two}, 0.8, ["flat"], {},
				walls, {"parapet": 1.0, "veranda": 0.0, "dormers": 0.0})
			out["terrace house"] = _type(f, "a cube with a shaded terrace on its front", &"mediterranean",
				{"poor": s_flat * 0.15, "middle": s_flat * 0.4, "rich": s_flat * 0.5}, {"1": 1.0 - two, "2": two}, 0.95, ["flat"], {},
				walls, {"parapet": 1.0, "veranda": 1.0, "dormers": 0.0})
		else:
			out["earth house"] = _type(f, "a thick-walled earth house with a terrace roof", &"pueblo",
				{"poor": s_flat, "middle": s_flat * 0.6, "rich": s_flat * 0.1}, {"1": 1.0 - two * 0.7, "2": two * 0.7}, 0.9,
				["flat"], {"flat": 1.0}, walls, {})
			if w >= 0.6:
				out["courtyard house"] = _type(f, "a mud-brick courtyard house, buttressed, its roof a terrace",
					&"african", {"poor": s_flat * 0.25, "middle": s_flat * 0.7, "rich": s_flat},
					{"1": 1.0 - two, "2": two}, 1.2, ["flat"], {"flat": 1.0}, walls, {})
	if s_pitch >= 0.06 and has_pitched:
		for m in mats:
			var share: float = float(mats[m]) * s_pitch
			var walls: Array
			var look := {}
			var word := String(m)
			match String(m):
				"timber":
					if float(f["timber"]) >= 0.55 or float(f["earth"]) + float(f["lime"]) < 0.5:
						# log or board walls: no frame to show
						walls = _walls_timber(f)
						look = {"timber": 0.0, "jetty": 0.15 * height, "stone_ground": 0.0}
						word = "log"
					else:
						# a frame, its panels plastered
						walls = _walls_plaster(f)
						look = {"timber": 1.0, "jetty": clampf(density * 1.1 * (0.4 + 0.6 * height), 0.0, 1.0),
							"stone_ground": clampf(float(f["stone"]) * wealth * 1.4, 0.0, 0.9)}
						word = "timber-framed"
				"stone":
					walls = _walls_stone(f)
					look = {"timber": 0.0, "jetty": 0.0, "stone_ground": 0.0, "bargeboards": 0.0}
				_:
					walls = _walls_earth(f)
					look = {"timber": 0.0, "jetty": 0.0, "stone_ground": 0.0, "bargeboards": 0.0}
					word = "earth"
			var one := clampf(1.15 - 1.5 * height, 0.0, 1.0)
			var three := clampf((height - 0.6) * 1.5, 0.0, 0.6)
			# thatch on cob: the cottage whose whole character is its roof
			if String(m) == "earth" and roofs.has("thatch") and w < 0.7 and float(f["rain"]) >= 0.45 and density < 0.6:
				out["cob cottage"] = _type(f, "a cob cottage under a steep combed thatch", &"thatch_cottage",
					{"poor": share * 0.9, "middle": share * 0.35}, {"1": maxf(one, 0.5), "2": 1.0 - maxf(one, 0.5)}, 0.85,
					["thatch"], {"gable": 1.0}, walls, {})
				share *= 0.6
			out["%s cottage" % word] = _type(f, "the small %s house" % word, &"cottage",
				{"poor": share * (1.0 - 0.5 * density), "middle": share * 0.45 * (1.0 - 0.6 * density), "rich": share * 0.05},
				{"1": maxf(one, 0.15), "2": 1.0 - maxf(one, 0.15)}, 0.85,
				_coverings(roofs, 0.0, 0.5 + 0.3 * wealth, pitched_forms), {}, walls, look)
			if density < 0.85:
				out["%s farmhouse" % word] = _type(f, "the %s farmhouse: the work of the farm under the same roof" % word,
					# a planned settlement issues dwellings; the farm is not under their roof
					&"farmhouse", {"poor": share * 0.2 * (1.0 - density) * (1.0 - 0.7 * order),
						"middle": share * 0.6 * (1.0 - 0.7 * density) * (1.0 - 0.7 * order),
						"rich": share * 0.45 * (1.0 - 0.7 * density) * (1.0 - 0.7 * order)},
					{"1": maxf(one * 0.8, 0.1), "2": 1.0 - maxf(one * 0.8, 0.1)}, 1.15,
					_coverings(roofs, 0.05, 0.6 + 0.3 * wealth, pitched_forms), {}, walls, look,
					{"farming": 2.0, "mill": 1.5, "forest": 1.5, "market": 0.4}, {"farmer": 2.0})
			if density >= 0.45 and height >= 0.3:
				out["%s town house" % word] = _type(f, "the tall narrow %s house of the street" % word, &"townhouse",
					{"poor": share * 0.6 * density, "middle": share * 0.8 * density, "rich": share * 0.4 * density},
					{"2": 1.0 - three, "3": three}, 0.8, _coverings(roofs, 0.3, 1.0, pitched_forms), {}, walls, look,
					{"market": 1.5, "crossroads": 1.3, "pilgrim": 1.3, "farming": 0.7})
		# the house of the well-off
		var top := ""
		for m in mats:
			if top.is_empty() or float(mats[m]) > float(mats[top]):
				top = String(m)
		var three_r := clampf((height - 0.5) * 1.4, 0.0, 0.6)
		if mats.has("timber") and float(f["ornament"]) >= 0.45 and w < 0.6:
			var framed: bool = float(f["timber"]) < 0.55 and float(f["earth"]) + float(f["lime"]) >= 0.5
			out["great house"] = _type(f, "the great house: tall, close-studded, carved", &"rich",
				{"middle": s_pitch * 0.04, "rich": s_pitch}, {"2": 1.0 - three_r, "3": three_r}, 1.3,
				_coverings(roofs, 0.4, 1.0, pitched_forms, false), {}, _walls_plaster(f) if framed else _walls_timber(f),
				{"timber": 1.0 if framed else 0.0})
		elif top != "timber" and w >= 0.5 and wealth >= 0.3:
			out["great house"] = _type(f, "the square house of the well-off, under a hipped roof", &"mediterranean",
				{"middle": s_pitch * 0.04, "rich": s_pitch}, {"2": 1.0 - three_r, "3": three_r}, 1.35,
				_coverings(roofs, 0.4, 1.0, ["gable", "hipped"], false), {"hipped": 1.0},
				_walls_stone(f) if top == "stone" else _walls_earth(f), {"parapet": 0.0, "veranda": 0.3 * float(f["openness"])})
	if out.is_empty():
		# a place that asked for nothing buildable still has somewhere to live
		out["house"] = _type(f, "the house", &"cottage", {"poor": 1.0, "middle": 1.0, "rich": 1.0}, {"1": 1.0}, 0.9,
			_coverings(roofs, 0.0, 1.0, pitched_forms), {}, _walls_earth(f), {"timber": 0.0})
	# a house type whose covering list came back empty cannot be built
	for tid in out.keys():
		if (out[tid]["roofs"] as Array).is_empty():
			out.erase(tid)
	if out.is_empty():
		# features that contradict each other (every house round, every roof
		# flat) still leave somewhere to live: the plainest house the place's
		# coverings allow
		if roofs.has("flat") and _coverings(roofs, 0.0, 1.0, pitched_forms).is_empty():
			out["house"] = _type(f, "the house", &"mediterranean", {"poor": 1.0, "middle": 1.0, "rich": 1.0},
				{"1": 1.0}, 0.9, ["flat"], {}, _walls_earth(f), {"parapet": 1.0, "veranda": 0.0, "dormers": 0.0})
		else:
			if _coverings(roofs, 0.0, 1.0, pitched_forms).is_empty():
				# no covering an ordinary roof can wear: it is thatched
				roofs["thatch"] = {"w": 0.06, "types": {"gable": 1.0}, "material": "thatch", "pitch": [0.9, 1.2],
					"colours": [_c("straw", 1.0, ["a28e5e", "8c794e"])]}
			out["house"] = _type(f, "the house", &"cottage", {"poor": 1.0, "middle": 1.0, "rich": 1.0},
				{"1": 1.0}, 0.9, _coverings(roofs, 0.0, 1.0, pitched_forms), {}, _walls_earth(f), {"timber": 0.0})
	# tiers as shares a person can read; a planned place keeps only its main types
	var best := 0.0
	for tid in out:
		for tier in out[tid]["tiers"]:
			best = maxf(best, float(out[tid]["tiers"][tier]))
	for tid in out.keys():
		var top_w := 0.0
		for tier in (out[tid]["tiers"] as Dictionary).keys():
			var share := float(out[tid]["tiers"][tier]) / maxf(best, 1e-9)
			if share < lerpf(0.02, 0.2, order):
				out[tid]["tiers"].erase(tier)
			else:
				out[tid]["tiers"][tier] = snappedf(share, 0.001)
				top_w = maxf(top_w, share)
		if (out[tid]["tiers"] as Dictionary).is_empty():
			out.erase(tid)
	return out


## One house type row. The look is what the climate and the purse lay over
## the chassis, then what the caller's `extra` says of this type in
## particular; only keys the chassis has survive (a look is a patch).
static func _type(f: Dictionary, label: String, style: StringName, tiers: Dictionary, storeys: Dictionary,
		area: float, covers: Array, roof_types: Dictionary, walls: Array, extra: Dictionary,
		purposes: Dictionary = {}, trades: Dictionary = {}) -> Dictionary:
	var w := warmth(f)
	var up := float(f["upkeep"])
	var decay := 1.0 - up
	var orn := float(f["ornament"])
	var base: Dictionary = HouseSpec.STYLES.get(style, {})
	var look := {
		# a fire for the cold, none where the cooking is done outside
		"chimney": clampf(1.25 - 1.5 * w, 0.0, 1.0) if float(base.get("chimney", 0.0)) > 0.0 else 0.0,
		"chimney_style": "stepped" if orn >= 0.6 and w < 0.5 else "straight",
		# shutters against the sun and against the wind; the first thing to fall off
		"shutters": clampf((0.25 + 0.6 * maxf(smoothstep(0.5, 0.75, w), 0.6 * float(f["colour"])) + 0.2 * orn)
			* (0.3 + 0.7 * up), 0.0, 1.0),
		"porch": clampf((0.15 + 0.5 * float(f["rain"]) * (1.0 - w) + 0.3 * float(f["openness"])) * float(base.get("porch", 0.0) > 0.0), 0.0, 1.0),
		"veranda": clampf(float(f["openness"]) * 0.9, 0.0, 1.0),
		"dormers": clampf(orn * (1.0 - w) * 0.9 * float(f["height"]) * 1.5, 0.0, 0.9),
		"bargeboards": clampf((0.3 + 0.7 * orn) * (0.5 + 0.5 * up), 0.0, 1.0) if float(base.get("bargeboards", 0.0)) > 0.0 else 0.0,
		"braces": clampf(0.3 + 0.5 * (1.0 - orn), 0.0, 1.0),
		"rail": clampf(0.3 + 0.6 * orn, 0.0, 1.0),
		# a wet place lifts its sills
		"plinth": [snappedf(lerpf(0.25, 0.5, float(f["rain"])), 0.01), snappedf(lerpf(0.4, 0.8, float(f["rain"])), 0.01)],
		# what lies about a house nobody tidies
		"clutter": [snappedf(clampf(0.3 + 0.5 * decay, 0.0, 1.0), 0.01), snappedf(clampf(0.6 + 0.4 * decay, 0.0, 1.0), 0.01)],
	}
	for k in extra:
		look[k] = extra[k]
	var row := {"label": label, "style": String(style), "tiers": tiers.duplicate(), "storeys": _storeys(style, storeys),
		"area": snappedf(clampf(area, 0.4, 2.5), 0.01), "roofs": covers.duplicate(), "walls": walls.duplicate(true),
		"look": VillageVernacular._prune(style, look)}
	if not roof_types.is_empty():
		row["roof_types"] = roof_types.duplicate()
	if not purposes.is_empty():
		row["purposes"] = purposes.duplicate()
	if not trades.is_empty():
		row["trades"] = trades.duplicate()
	return row


## Storey weights a chassis can honour: a townhouse and a rich house never
## one storey, no weight under a hundredth.
static func _storeys(style: StringName, storeys: Dictionary) -> Dictionary:
	var out := {}
	var low := int(HouseSpec.STYLES.get(style, {}).get("min_storeys", 1))
	for s in storeys:
		if int(String(s)) >= low and float(storeys[s]) >= 0.01:
			out[String(s)] = snappedf(float(storeys[s]), 0.01)
	if out.is_empty():
		out[str(low)] = 1.0
	return out


## The type a shop is built as: the street's house where there is one, else
## the commonest house of the middling.
static func _shop_type(f: Dictionary, houses: Dictionary) -> String:
	var best := ""
	var best_w := -1.0
	for tid in houses:
		var score := float(houses[tid]["tiers"].get("middle", 0.0)) + 0.01
		if String(tid).ends_with("town house") or String(tid) == "shop-house":
			score += 2.0
		# a shop wants a front and a counter: a round hut, a hall and a
		# great house are the last things it is kept in
		if String(houses[tid]["style"]) in ["roundhouse", "longhall", "rich"]:
			score *= 0.001
		if score > best_w + 1e-9:
			best_w = score
			best = String(tid)
	return best


# ---- the rest of the village

static func _landmark(f: Dictionary, walls: Array, roofs: Dictionary) -> Dictionary:
	var wall: Dictionary = walls[0]
	for c in walls:
		if float(c["w"]) > float(wall["w"]):
			wall = c
	var roof_hex: Array = ["5c4230", "3d2b1e"]
	var best := -1.0
	for rid in roofs:
		var cost := float(ROOF_COST.get(String(rid), 0.5))
		# the dearest covering the place has goes on its church
		if String(roofs[rid]["material"]) != "earth" and cost > best:
			best = cost
			roof_hex = roofs[rid]["colours"][0]["hex"]
	var sacred := String(f["sacred"])
	var look := {"wall": [String(wall["hex"][0]), String(wall["hex"][1])],
		"roof": [String(roof_hex[0]), String(roof_hex[1])]}
	if sacred == "dome" and float(f["whitewash"]) >= 0.5:
		look["roof"] = HUES[String(_hues(f)[0])]["trim"]
	return {"church": String(SACRED[sacred]), "look": look}


static func _plants(f: Dictionary) -> Dictionary:
	var w := warmth(f)
	var rain := float(f["rain"])
	var kept := float(f["upkeep"]) * (0.4 + 0.6 * float(f["ornament"]))
	var edge: Array = []
	var green: Array = []
	var hedge: Array = []
	var ground: Array = []
	if w < 0.42 or float(f["altitude"]) > 0.55:
		edge = ["Wild_Pine_*", "Nature_BirchTree_*"]
		green = ["Nature_BirchTree_*"]
		hedge = ["Nature_Bush_Small", "Nature_Bush"]
		ground = ["Wild_Grass_Wispy_*", "Wild_Rock_Medium_*", "Wild_Fern_1"]
	elif rain < 0.3:
		edge = ["Wild_CommonTree_*"]
		green = ["Wild_CommonTree_*"]
		hedge = ["Wild_Plant_1*", "Wild_Plant_7*"]
		ground = ["Wild_Pebble_Square_*", "Wild_Rock_Medium_*", "Wild_Grass_Wispy_Short"]
	elif w > 0.7 and rain > 0.7:
		edge = ["Wild_CommonTree_*", "Nature_MapleTree_*"]
		green = ["Wild_CommonTree_*"]
		hedge = ["Wild_Plant_1*", "Wild_Plant_7*", "Wild_Bush_Common"]
		ground = ["Wild_Fern_1", "Wild_Grass_Common_Tall", "Wild_Grass_Wispy_Tall"]
	elif w > 0.58:
		edge = ["Wild_CommonTree_*"]
		green = ["Wild_CommonTree_*"]
		hedge = ["Nature_Bush_Small", "Wild_Plant_1*"]
		ground = ["Wild_Grass_Wispy_Short", "Wild_Pebble_Round_*"]
	else:
		edge = ["Wild_CommonTree_*", "Nature_MapleTree_*"]
		green = ["Wild_CommonTree_*"]
		hedge = ["Wild_Bush_Common"]
		ground = ["Wild_Grass_Common_*", "Wild_Clover_*"]
	if float(f["swept_roof"]) >= 0.5:
		edge = ["Wild_Pine_*", "Nature_MapleTree_*"]
		green = ["Nature_MapleTree_*"]
	# a cared-for place flowers; a neglected wet one grows fungus
	if kept >= 0.45 and rain >= 0.25:
		hedge.append("Nature_Bush_Small_Flowers")
		hedge.append("Wild_Bush_Common_Flowers")
		ground.append("Nature_Flower_*_Clump")
	if float(f["upkeep"]) < 0.35 and rain >= 0.5:
		ground.append("Wild_Mushroom_*")
	var wild: Array = ["Nature_DeadTree_1"]
	if float(f["upkeep"]) < 0.5:
		wild.append("Nature_DeadTree_2")
	return {"edge": edge, "green": green, "hedge": hedge, "ground": ground, "wild": wild}


static func _ground(f: Dictionary) -> Dictionary:
	var w := warmth(f)
	var rain := float(f["rain"])
	var dry := smoothstep(0.45, 0.8, 1.0 - rain)
	var jungle := smoothstep(0.65, 0.85, w) * smoothstep(0.6, 0.85, rain)
	var cold := (1.0 - smoothstep(0.3, 0.5, w)) * (1.0 - dry)
	var green := maxf(1.0 - dry - jungle - cold, 0.0)
	var weights := {"dry": dry, "jungle": jungle, "cold": cold, "green": green}
	var total := dry + jungle + cold + green
	var out := {}
	for surface in GROUND["green"]:
		var c := Color(0, 0, 0, 1)
		for k in weights:
			var a := Color(String(GROUND[k][surface]))
			var share := float(weights[k]) / maxf(total, 1e-9)
			c = Color(c.r + a.r * share, c.g + a.g * share, c.b + a.b * share, 1.0)
		# trodden bare where nobody mends the paths
		out[surface] = c.to_html(false)
	return out


## What a village of the place is held to: only what follows from the row
## with certainty (a covering the row has no recipe for is never worn) and
## the landmark. The shares a feature moves are measured by `vplace`.
static func _signature(row: Dictionary) -> Array:
	var out: Array = []
	var names: Array = []
	for c in row["walls"]:
		names.append(String(c["name"]))
	out.append({"id": "walls", "say": "walls of the place's own materials", "measure": "walls", "clusters": names, "min": 0.9})
	var materials := {}
	var forms := {}
	for tid in row["houses"]:
		var t: Dictionary = row["houses"][tid]
		for rid in t["roofs"]:
			var r: Dictionary = row["roofs"][String(rid)]
			materials[String(r["material"])] = true
			for form in t.get("roof_types", r["types"]):
				forms[String(form)] = true
	var absent: Array = []
	for m in ["thatch", "tile", "slate", "shingle", "earth"]:
		if not materials.has(m):
			absent.append(m)
	if not absent.is_empty():
		out.append({"id": "no_foreign_roofs", "say": "no roof of %s" % ", ".join(PackedStringArray(absent)),
			"measure": "roof_material", "materials": absent, "max": 0.0})
	if not forms.has("flat"):
		out.append({"id": "pitched", "say": "no flat roofs", "measure": "roof_form", "types": ["flat"], "max": 0.0})
	elif forms.size() == 1:
		out.append({"id": "flat", "say": "every roof flat", "measure": "roof_form", "types": ["flat"], "min": 0.9})
	var tall := false
	for tid in row["houses"]:
		tall = tall or (row["houses"][tid]["storeys"] as Dictionary).has("3")
	if not tall:
		out.append({"id": "low", "say": "never three storeys", "measure": "storeys", "storeys": [3], "max": 0.0})
	out.append({"id": "church", "say": "a %s landmark" % String(row["place"]["features"]["sacred"]),
		"measure": "landmark", "church": String(row["landmark"]["church"])})
	return out


# ============================================================ the village

## The region id a place is registered under, made from what was stated: the
## same place is the same region in every process.
static func region_id(stated: Dictionary, like := "") -> StringName:
	if not like.is_empty() and stated == preset(like):
		return StringName("place_" + like)
	return StringName("place_%08x" % (hash(_canonical(stated)) & 0xffffffff))


static func _canonical(stated: Dictionary) -> String:
	var keys: Array = stated.keys()
	keys.sort()
	var parts := PackedStringArray()
	for k in keys:
		var v: Variant = stated[k]
		parts.append("%s=%s" % [String(k), ("%.4f" % float(v)) if (v is float or v is int) else str(v)])
	return "|".join(parts)


## Make sure the place's region row is registered, and say its id and what is
## wrong with it: {"id", "errors"}. Synthesised once per place per run.
static func ensure(place: Variant) -> Dictionary:
	var p := parse(place)
	if not (p["errors"] as Array).is_empty():
		return {"id": &"", "errors": p["errors"]}
	var id := region_id(p["features"], p["like"])
	if _cache.has(id):
		return {"id": id, "errors": []}
	var row := synthesise(p["features"], p["like"])
	var errs := VillageVernacular.register(id, row)
	var out: Array[String] = []
	for e in errs:
		out.append("place: the features made a row the builders refuse -- %s" % String(e))
	if out.is_empty():
		_cache[id] = true
	return {"id": id, "errors": out}


## The row a place makes, registered; {} when the place is wrong.
static func region(place: Variant) -> Dictionary:
	var e := ensure(place)
	return VillageVernacular.region(e["id"]) if (e["errors"] as Array).is_empty() else {}


## The settings of the VILLAGE a place states, beyond its houses: only what
## was stated or follows from a stated feature is here, so a request's own
## value stands wherever the place is silent.
##   {wealth?, upkeep, decoration_level, water?, purpose?, enclosure?}
## `population` is the people who would man a wall: the CIVIC population when
## the caller implies more than it shows (`VillageSpec.civic_population`).
## `purpose` is the village's own, which stands where the place states none:
## a garrison mans its wall however few it is.
static func settings(place: Variant, population := 40, purpose := &"") -> Dictionary:
	var p := parse(place)
	var stated: Dictionary = p["features"]
	var f := derive(stated)
	var out := {"upkeep": snappedf(float(f["upkeep"]), 0.01),
		"decoration_level": snappedf(clampf(0.5 + (float(f["ornament"]) * float(f["upkeep"]) - 0.35) * 0.9, 0.1, 0.95), 0.01)}
	if stated.has("wealth"):
		out["wealth"] = float(f["wealth"])
	if not String(f["water"]).is_empty():
		out["water"] = StringName(String(f["water"]))
	if not String(f["purpose"]).is_empty():
		out["purpose"] = StringName(String(f["purpose"]))
	if float(f["defence"]) >= 0.0:
		var d := float(f["defence"])
		var enclosure: StringName = &"none" if d < 0.25 else (&"hedge" if d < 0.5 else (&"palisade" if d < 0.8 else &"wall"))
		var manned_by: StringName = out.get("purpose", purpose)
		if enclosure == &"wall" and population < VillageSpec.WALL_MIN_POPULATION and manned_by != &"garrison":
			enclosure = &"palisade"   # too few to build and man a wall
		out["enclosure"] = enclosure
	return out


## Lay a spec's place over the spec: the village settings the place states,
## and the spec's own wealth into a place that states none (so the request's
## wealth slider still moves a place village). Nothing happens to a spec
## with no place. Call before `spec.valid()`. A wall is manned by the civic
## population, and a garrison mans one at any size; a place that turns a
## small garrison into something else leaves it a palisade.
static func apply(spec: VillageSpec) -> void:
	if not spec.vernacular.has("place"):
		return
	var place: Variant = spec.vernacular["place"]
	if place is String or place is StringName:
		place = {"like": String(place)}
	if not place is Dictionary:
		return
	var p := parse(place)
	if not (p["errors"] as Array).is_empty():
		return
	if not (p["features"] as Dictionary).has("wealth"):
		place = (place as Dictionary).duplicate(true)
		place["wealth"] = snappedf(spec.wealth, 0.01)
		spec.vernacular = spec.vernacular.duplicate(true)
		spec.vernacular["place"] = place
	var garrison_before := spec.purpose == &"garrison"
	var s := settings(place, spec.civic_population(), spec.purpose)
	if s.has("wealth"):
		spec.wealth = float(s["wealth"])
	spec.upkeep = minf(spec.upkeep, float(s["upkeep"]))
	if is_equal_approx(spec.decoration_level, 0.5):
		spec.decoration_level = float(s["decoration_level"])
	if s.has("water"):
		spec.water = s["water"]
	if s.has("purpose"):
		spec.purpose = s["purpose"]
	if s.has("enclosure"):
		spec.enclosure = s["enclosure"]
	# a place that names another purpose takes away the garrison that manned
	# the wall; too few people to man it keep a palisade instead, rather than
	# leaving a spec that refuses itself
	if garrison_before and spec.purpose != &"garrison" and spec.enclosure == &"wall" \
			and spec.civic_population() < VillageSpec.WALL_MIN_POPULATION:
		spec.enclosure = &"palisade"


## A village request for a place: `BuildingRequest.village` with the place in
## its vernacular. The place's wealth, water, purpose and defence reach the
## village when it is generated (`apply`).
static func request(p_seed: int, population: int, place: Variant) -> BuildingRequest:
	var p := parse(place)
	var f := derive(p["features"])
	var purpose := StringName(String(f["purpose"])) if not String(f["purpose"]).is_empty() else &"farming"
	var out := BuildingRequest.village(p_seed, population, &"english", purpose, float(f["wealth"]))
	if place is String or place is StringName:
		place = {"like": String(place)}
	out.vernacular = {"place": (place as Dictionary).duplicate(true) if place is Dictionary else {}}
	return out


## The ground a place stands on, for a caller that builds from a spec
## (`spec.terrain`): a slope as steep as the relief with a little roll in
## it, and the sea, lake or river at its foot. The public request carries no
## ground yet, so this is for tools and hosts that own the spec.
static func terrain(place: Variant, rect := Rect2(-400, -400, 800, 800), cell_m := 5.0) -> VillageTerrain:
	var f := derive(parse(place)["features"])
	var slope := lerpf(0.0, 0.5, float(f["relief"]))
	var roll := lerpf(0.5, 4.0, float(f["relief"]))
	var base := 20.0 + float(f["altitude"]) * 100.0
	var sampler := func(x: float, z: float) -> float:
		return base - slope * z + roll * sin(x * 0.021) * cos(z * 0.017)
	var water := NAN
	if String(f["water"]) in ["coast", "lake"]:
		# the water stands where the slope has fallen to the foot of the site
		water = base - slope * (rect.end.y * 0.55) - 1.0 if slope > 0.02 else NAN
	return VillageTerrain.from_sampler(sampler, rect, cell_m, water)


# ================================================================ publishing

## The feature set for a person or a UI: every feature, its group, range and
## meaning; every preset with its stated features; the paints, tongues and
## landmark forms a place may name.
static func describe() -> Dictionary:
	var features: Array[Dictionary] = []
	for k in FEATURES:
		var row: Dictionary = FEATURES[k]
		var d := {"id": String(k), "group": row["group"], "kind": row["kind"], "say": row["say"],
			"derived": bool(row.get("derived", false))}
		for extra in ["low", "high", "default"]:
			if row.has(extra):
				d[extra] = row[extra]
		if String(k) == "tongue":
			d["names"] = TONGUES.keys()
		elif String(k) == "hues":
			d["names"] = HUES.keys()
		elif row.has("names"):
			d["names"] = row["names"]
		features.append(d)
	var presets: Array[Dictionary] = []
	for id in PRESETS:
		presets.append({"id": String(id), "label": PRESETS[id]["label"], "summary": PRESETS[id]["summary"],
			"features": preset(id)})
	return {"schema": SCHEMA, "groups": GROUPS, "features": features, "presets": presets}
