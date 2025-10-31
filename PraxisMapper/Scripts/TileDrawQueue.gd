extends Node2D

#This handles drawing tiles one at a time, to ensure we never overlap drawing tiles
#May need a whole scene attached, as FullSingleTile does.

var busy = false
var tilesToDraw = []
var drawerPL = preload("res://PraxisMapper/FullOffline/FullSingleTile.tscn")
var drawer

signal tile_done(code, image)

func _ready() -> void:
	drawer = drawerPL.instantiate()
	drawer.alwaysDrawNewTile = false
	add_child(drawer)

func _process(delta):
	if busy == false and tilesToDraw.size() > 0:
		busy = true
		await DrawTile(tilesToDraw.pop_back())
		busy = false

func AddToQueue(code):
        _prewarm_data(code)
        if !tilesToDraw.has(code):
                tilesToDraw.push_back(code)

func DrawTile(code):
        var img = await drawer.GetAndProcessData(code)
        tile_done.emit(code, img)
        return img

func _prewarm_data(code):
        var pending = {}
        var cell6 = code.substr(0,6)
        pending[cell6] = true
        for neighbor in PlusCodes.GetNearbyCells(code, 1):
                if neighbor == null:
                        continue
                var trimmed = neighbor.substr(0,6)
                pending[trimmed] = true

        for key in pending.keys():
                PraxisOfflineData.PrepareDataAsync(key)
