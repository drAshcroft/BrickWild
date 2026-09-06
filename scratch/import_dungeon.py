import io, os, shutil

SRC = r"C:/Projects/itch_assets/quaternius/dungeon kit/FBX-20260809T001824Z-1-001/FBX"
DST = r"C:/Projects/BigGlade/assets/props/dungeon"

# The DRESSING of the Dungeon Kit, not its modular architecture: the builders
# emit their own walls, floors and arches, so a wall tile is of no use here.
# Columns and rails are in because a free-standing column and an altar rail are
# furniture as far as a nave is concerned.
WANTED = [
    "Statue_Fox", "Statue_Stag",
    "Flag_Wall", "Flag_Wall2", "Flag_GothicArch", "Flag_RoundArch",
    "Rail_Straight", "Rail_Corner", "Rail_Divider",
    "Candles_1", "Candles_2", "Torch",
    "Bookcase_Empty", "Bookcase_Full",
    "Chest", "Chest_Gold", "Barrel", "Crate",
    "Pot1", "Pot2", "Pot3", "Pot1_Broken", "Pot2_Broken", "Pot3_Broken",
    "Cart",
    "Column_Round", "Column_Round_Short", "Column_Square",
    "Skull", "BearTrap_Closed", "BearTrap_Open",
    "Brick", "Bricks", "Trapdoor",
]

os.makedirs(DST, exist_ok=True)
missing = []
for name in WANTED:
    src = os.path.join(SRC, name + ".fbx")
    if not os.path.exists(src):
        missing.append(name)
        continue
    # Prefixed on disk so a key is globally unique: this pack has a Barrel, a
    # Crate and a Chest, and so does the one already imported.
    shutil.copy2(src, os.path.join(DST, "Dungeon_" + name + ".fbx"))

lic = r"C:/Projects/itch_assets/quaternius/dungeon kit/License.txt"
shutil.copy2(lic, os.path.join(DST, "License.txt"))
print("copied %d, missing %s" % (len(WANTED) - len(missing), missing))
