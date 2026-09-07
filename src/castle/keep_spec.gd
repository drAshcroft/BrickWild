class_name KeepSpec
extends HouseSpec
## The inside of a keep, as a house spec (CAS-011).
##
## A keep is stacked storeys of one room each, which is exactly what
## `HouseSpec.storeys` already means -- so the keep borrows the house harness
## whole rather than growing a second one. What it does NOT borrow is the
## house's idea of what belongs on which floor.
##
## That is the reason this class exists at all. `HousePlanCheck`'s
## `upstairs_programme` rule keeps a dwelling's service and public rooms on the
## ground floor: no hall up a stair, one hearth and it is down here where the
## chimney is. Both are right for a farmhouse and both are wrong for a keep,
## whose hall is on the FIRST floor over a blind store and whose lord sleeps
## over that with a fire of his own. The rule exempts any spec that can answer
## `room_program`, the same door a shop and a hotel go through, and answering
## it is the whole of what a KeepSpec adds.

## The storey programme, bottom to top. A keep is entered at its foot into a
## windowless store, holds its hall over that, and puts the lord at the top;
## anything in between is a chamber for the household.
const PROGRAMME := {
	3: [&"store", &"hall", &"lords_chamber"],
	4: [&"store", &"hall", &"parlour", &"lords_chamber"],
}


## What each storey is, bottom to top. Named `room_program` because that is the
## name HousePlanCheck and ShopGenerator already know it by.
func room_program(count: int) -> Array[StringName]:
	var rows: Array = PROGRAMME.get(clampi(count, 3, 4), PROGRAMME[3])
	var out: Array[StringName] = []
	for k in rows:
		out.append(k)
	return out


## The kind on one storey, or &"store" for a level the programme does not name.
func kind_on(storey: int) -> StringName:
	var rows: Array[StringName] = room_program(storeys)
	return rows[storey] if storey >= 0 and storey < rows.size() else &"store"
