class_name WeaponLoadout
extends RefCounted

signal ammo_changed(current: int, reserve: int)
signal weapon_changed(definition: WeaponDefinition, slot: int)

var _definitions: Array[WeaponDefinition] = []
var _ammo: Array[int] = []
var _reserve: Array[int] = []
var _current_index := 0
var _fire_cooldown := 0.0
var _reload_cooldown := 0.0

func initialize(definitions: Array[WeaponDefinition] = WeaponCatalog.all()) -> void:
	_definitions = definitions.duplicate()
	_ammo.clear()
	_reserve.clear()
	_current_index = 0
	_fire_cooldown = 0.0
	_reload_cooldown = 0.0
	for definition in _definitions:
		_ammo.append(definition.magazine_size)
		_reserve.append(definition.initial_reserve)
	_emit_current()

func tick(delta: float) -> void:
	_fire_cooldown = maxf(0.0, _fire_cooldown - delta)
	_reload_cooldown = maxf(0.0, _reload_cooldown - delta)

func current_index() -> int:
	return _current_index

func current_definition() -> WeaponDefinition:
	if _definitions.is_empty():
		return null
	return _definitions[clampi(_current_index, 0, _definitions.size() - 1)]

func current_ammo() -> int:
	if _ammo.is_empty():
		return 0
	return _ammo[_current_index]

func current_reserve() -> int:
	if _reserve.is_empty():
		return 0
	return _reserve[_current_index]

func switch_weapon(index: int) -> bool:
	if index < 0 or index >= _definitions.size() or index == _current_index:
		return false
	_current_index = index
	_reload_cooldown = 0.0
	weapon_changed.emit(current_definition(), _current_index + 1)
	ammo_changed.emit(current_ammo(), current_reserve())
	return true

func consume_shot() -> bool:
	var definition := current_definition()
	if definition == null or _fire_cooldown > 0.0 or _reload_cooldown > 0.0:
		return false
	if current_ammo() <= 0:
		return false
	_ammo[_current_index] -= 1
	_fire_cooldown = 1.0 / definition.fire_rate
	ammo_changed.emit(current_ammo(), current_reserve())
	return true

func try_reload() -> bool:
	var definition := current_definition()
	if definition == null or _reload_cooldown > 0.0:
		return false
	if current_ammo() >= definition.magazine_size or current_reserve() <= 0:
		return false
	var needed := definition.magazine_size - current_ammo()
	var amount := mini(needed, current_reserve())
	_ammo[_current_index] += amount
	_reserve[_current_index] -= amount
	_reload_cooldown = definition.reload_seconds
	ammo_changed.emit(current_ammo(), current_reserve())
	return true

func grant_ammo(amount: int) -> void:
	var definition := current_definition()
	if definition == null:
		return
	_reserve[_current_index] = mini(
		definition.reserve_cap,
		_reserve[_current_index] + maxi(0, amount)
	)
	ammo_changed.emit(current_ammo(), current_reserve())

func is_reloading() -> bool:
	return _reload_cooldown > 0.0

func _emit_current() -> void:
	var definition := current_definition()
	if definition == null:
		return
	weapon_changed.emit(definition, _current_index + 1)
	ammo_changed.emit(current_ammo(), current_reserve())
