class_name TimberHallSpec
extends RefCounted
## Plan data for the timber hall family (WLD-008).

var kind: StringName = &"great_hall"
var seed := 0
var width := 34.0
var length := 18.0
var height := 20.0
var orientation: float = 0.0
var period: int = 1200
var platform_h := 0.8
var wall_t := 0.45
var column_r := 0.42
var column_h := 9.0
var roof_overhang := 2.4
var roof_rise := 10.0
var dais_h := 0.8
var image_h := 4.0
var columns: Array[Dictionary] = []
var windows: Array[Dictionary] = []
var wings := false
var wing_w := 12.0
var water: Rect2 = Rect2()
var variant_name := ""
