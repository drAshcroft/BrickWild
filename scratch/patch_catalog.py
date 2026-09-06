import io, re
p = "src/house/prop_catalog.gd"
s = io.open(p, encoding="utf-8").read()

def sub(old, new):
    global s
    assert s.count(old) == 1, ("anchor not unique: " + old[:60])
    s = s.replace(old, new)

# ---- barrels: the barrel on its stand ----
sub(
'\t"Barrel_Apples": {"cat": "barrel", "tags": [CORNER], "zone": 0.0, "affinity": {"away_from_doors": true, "near": ["counter"]}},\n',
'\t"Barrel_Apples": {"cat": "barrel", "tags": [CORNER], "zone": 0.0, "affinity": {"away_from_doors": true, "near": ["counter"]}},\n'
'\t"Barrel_Holder": {"cat": "barrel", "tags": [CORNER], "zone": 0.0, "affinity": {"away_from_doors": true, "near": ["counter"]}},\n')

# ---- trade fittings: the pickaxe is a tool nobody sets on a table ----
sub(
'\t"Anvil_Log": {"cat": "anvil", "tags": [], "zone": 0.9, "affinity": {"near": ["hearth"]}},\n',
'\t"Anvil_Log": {"cat": "anvil", "tags": [], "zone": 0.9, "affinity": {"near": ["hearth"]}},\n'
'\t# A pickaxe is a metre of haft: it leans in a corner, and the "tool" category\n'
'\t# is placed ON a surface, so it cannot go there.\n'
'\t"Pickaxe_Bronze": {"cat": "big_tool", "tags": [CORNER], "zone": 0.0, "affinity": {"away_from_doors": true}},\n')

# ---- wall furniture: the hanging cloth banners ----
sub(
'\t"Banner_2": {"cat": "banner", "tags": [WALL_MOUNTED], "zone": 0.0, "face": PI},\n',
'\t"Banner_2": {"cat": "banner", "tags": [WALL_MOUNTED], "zone": 0.0, "face": PI},\n'
'\t"Banner_1_Cloth": {"cat": "banner", "tags": [WALL_MOUNTED], "zone": 0.0, "face": PI},\n'
'\t"Banner_2_Cloth": {"cat": "banner", "tags": [WALL_MOUNTED], "zone": 0.0, "face": PI},\n')

# ---- the floor candelabrum: a light that stands rather than hangs ----
sub(
'\t"Chandelier": {"cat": "chandelier", "tags": [CEILING, LIGHT], "zone": 0.0, "affinity": {"over": ["table"]}},\n',
'\t"Chandelier": {"cat": "chandelier", "tags": [CEILING, LIGHT], "zone": 0.0, "affinity": {"over": ["table"]}},\n'
'\t# Its own category: a candelabrum is a metre and a third of standing iron, so\n'
'\t# it cannot join "candle", which every recipe places ON a table.\n'
'\t"CandleStick_Stand": {"cat": "candelabrum", "tags": [LIGHT], "zone": 0.0},\n')

# ---- temple/church fittings: more coils of rope ----
sub(
'\t"Rope_1": {"cat": "chain", "tags": [CORNER], "zone": 0.0, "affinity": {"away_from_doors": true}},\n',
'\t"Rope_1": {"cat": "chain", "tags": [CORNER], "zone": 0.0, "affinity": {"away_from_doors": true}},\n'
'\t"Rope_2": {"cat": "chain", "tags": [CORNER], "zone": 0.0, "affinity": {"away_from_doors": true}},\n'
'\t"Rope_3": {"cat": "chain", "tags": [CORNER], "zone": 0.0, "affinity": {"away_from_doors": true}},\n')

# ---- things that live on a surface ----
sub(
'\t"Table_Plate": {"cat": "tableware", "tags": [ON_SURFACE], "zone": 0.0},\n',
'\t"Table_Plate": {"cat": "tableware", "tags": [ON_SURFACE], "zone": 0.0},\n'
'\t"Table_Fork": {"cat": "tableware", "tags": [ON_SURFACE], "zone": 0.0},\n'
'\t"Table_Spoon": {"cat": "tableware", "tags": [ON_SURFACE], "zone": 0.0},\n'
'\t"Pot_1_Lid": {"cat": "tableware", "tags": [ON_SURFACE], "zone": 0.0},\n')

sub(
'\t"CandleStick_Triple": {"cat": "candle", "tags": [ON_SURFACE, LIGHT], "zone": 0.0},\n',
'\t"CandleStick_Triple": {"cat": "candle", "tags": [ON_SURFACE, LIGHT], "zone": 0.0},\n'
'\t"Candle_2": {"cat": "candle", "tags": [ON_SURFACE, LIGHT], "zone": 0.0},\n')

sub(
'\t"Scroll_1": {"cat": "books", "tags": [ON_SURFACE], "zone": 0.0},\n',
'\t"Book_5": {"cat": "books", "tags": [ON_SURFACE], "zone": 0.0},\n'
'\t"Book_7": {"cat": "books", "tags": [ON_SURFACE], "zone": 0.0},\n'
'\t"Book_Simplified_Single": {"cat": "books", "tags": [ON_SURFACE], "zone": 0.0},\n'
'\t"BookGroup_Small_2": {"cat": "books", "tags": [ON_SURFACE], "zone": 0.0},\n'
'\t"BookGroup_Small_3": {"cat": "books", "tags": [ON_SURFACE], "zone": 0.0},\n'
'\t"BookGroup_Medium_1": {"cat": "books", "tags": [ON_SURFACE], "zone": 0.0},\n'
'\t"BookGroup_Medium_2": {"cat": "books", "tags": [ON_SURFACE], "zone": 0.0},\n'
'\t"BookGroup_Medium_3": {"cat": "books", "tags": [ON_SURFACE], "zone": 0.0},\n'
'\t"Scroll_1": {"cat": "books", "tags": [ON_SURFACE], "zone": 0.0},\n'
'\t"Scroll_2": {"cat": "books", "tags": [ON_SURFACE], "zone": 0.0},\n')

sub(
'\t"SmallBottles_1": {"cat": "alchemy", "tags": [ON_SURFACE], "zone": 0.0},\n',
'\t"SmallBottles_1": {"cat": "alchemy", "tags": [ON_SURFACE], "zone": 0.0},\n'
'\t"SmallBottle": {"cat": "alchemy", "tags": [ON_SURFACE], "zone": 0.0},\n'
'\t"Potion_4": {"cat": "alchemy", "tags": [ON_SURFACE], "zone": 0.0},\n')

sub(
'\t"Coin_Pile": {"cat": "trinket", "tags": [ON_SURFACE], "zone": 0.0},\n',
'\t"Coin_Pile": {"cat": "trinket", "tags": [ON_SURFACE], "zone": 0.0},\n'
'\t"Coin_Pile_2": {"cat": "trinket", "tags": [ON_SURFACE], "zone": 0.0},\n'
'\t"Coin": {"cat": "trinket", "tags": [ON_SURFACE], "zone": 0.0},\n'
'\t"Key_Gold": {"cat": "trinket", "tags": [ON_SURFACE], "zone": 0.0},\n'
'\t"Pouch_Large": {"cat": "trinket", "tags": [ON_SURFACE], "zone": 0.0},\n')

io.open(p, "w", encoding="utf-8", newline="\n").write(s)
print("patched")
