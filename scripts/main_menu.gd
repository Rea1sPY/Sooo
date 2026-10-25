extends Control
## منوی اصلی با فضای ترسناک: عنوان گلیچی، راهرو تاریک با موجود دوردست و دکمه‌ها.

signal start_game
signal quit_game

const UI = preload("res://scripts/ui.gd")
const Panels = preload("res://scripts/panels.gd")

var _t = 0.0
var _flick = 1.0
var title_a = null
var title_b = null
var cont_btn = null
var _base_x = 0.0


func _ready():
	UI.full_rect(self)
	layout_direction = Control.LAYOUT_DIRECTION_RTL
	var center = CenterContainer.new()
	UI.full_rect(center)
	add_child(center)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	center.add_child(box)
	var tbox = Control.new()
	tbox.custom_minimum_size = Vector2(900, 110)
	box.add_child(tbox)
	title_b = UI.label("یک دقیقه تا مرگ", 92, Color(0.55, 0.0, 0.05))
	title_a = UI.label("یک دقیقه تا مرگ", 92, UI.BONE)
	for t in [title_b, title_a]:
		t.custom_minimum_size = Vector2(900, 110)
		t.add_theme_constant_override("outline_size", 8)
		tbox.add_child(t)
	box.add_child(UI.label("ONE MINUTE TO DIE", 28, UI.RED))
	var sp = Control.new()
	sp.custom_minimum_size = Vector2(0, 14)
	box.add_child(sp)
	var b1 = UI.button("شروع بازی", _on_new)
	var b2 = UI.button("ادامه بازی", _on_continue)
	var b3 = UI.button("دفترچه‌ی سرنخ‌ها", func(): Panels.notebook(self))
	var b4 = UI.button("تنظیمات", func(): Panels.settings(self))
	var b5 = UI.button("راهنمای بازی", func(): Panels.help(self))
	cont_btn = b2
	b2.disabled = not Global.can_continue()
	for b in [b1, b2, b3, b4, b5]:
		b.custom_minimum_size = Vector2(420, 66)
		box.add_child(b)
	var credit = UI.label("ساخته‌شده توسط " + Global.CREATOR, 22, UI.DIM)
	box.add_child(credit)
	var best = "—"
	if Global.stats["best_time"] > 0.0:
		best = Global.fa(snappedf(Global.stats["best_time"], 0.1)) + " ثانیه"
	var meta = UI.label("مرگ‌ها: " + Global.fa(Global.progress["deaths"]) + "   ·   بهترین زمان: " + best + "   ·   نسخه ۱٫۰٫۰", 17, Color(0.42, 0.36, 0.35))
	box.add_child(meta)
	Sound.stop_music()


func _on_new():
	if Global.can_continue():
		Panels.confirm(self, "پیشرفت قبلی پاک می‌شود. مطمئنی؟", _pick_difficulty)
	else:
		_pick_difficulty()


func _pick_difficulty():
	Panels.difficulty(self, _begin_new)


func _begin_new():
	Global.new_game()
	start_game.emit()


func _on_continue():
	if Global.can_continue():
		start_game.emit()


func _process(delta):
	_t += delta
	_flick = 0.85 + 0.15 * sin(_t * 9.0) * sin(_t * 3.1)
	if randf() < 0.03:
		_flick *= 0.5
	if title_a != null and randf() < 0.08:
		title_a.position.x = randf_range(-5.0, 5.0)
		title_b.position.x = randf_range(-9.0, 9.0)
		title_b.position.y = randf_range(-3.0, 3.0)
	elif title_a != null and randf() < 0.3:
		title_a.position.x = 0.0
		title_b.position.x = 4.0
		title_b.position.y = 3.0
	queue_redraw()


func _draw():
	var vs = size
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0.02, 0.01, 0.025))
	# راهرو
	var vp = Vector2(vs.x * 0.5, vs.y * 0.42)
	for i in 8:
		var k = float(i) / 8.0
		var w = lerpf(vs.x * 0.55, vs.x * 0.06, k)
		var h = lerpf(vs.y * 0.9, vs.y * 0.1, k)
		draw_rect(Rect2(vp - Vector2(w, h) * 0.5, Vector2(w, h)), Color(0.5, 0.03, 0.05, 0.05 + 0.03 * _flick * k), false, 2.0)
	# درخشش قرمز
	for i in 6:
		draw_circle(vp, 40.0 + i * 55.0, Color(0.6, 0.02, 0.04, 0.035 * _flick))
	# موجود دوردست
	var eyes = int(_t * 0.8) % 4 != 0
	draw_rect(Rect2(vp.x - 9.0, vp.y - 34.0, 18.0, 44.0), Color(0.0, 0.0, 0.0, 0.95))
	draw_circle(vp + Vector2(0, -26), 8.0, Color(0, 0, 0))
	if eyes:
		draw_circle(vp + Vector2(-3, -27), 1.6, Color(1.0, 0.1, 0.1))
		draw_circle(vp + Vector2(3, -27), 1.6, Color(1.0, 0.1, 0.1))
	# حاشیه تاریک
	draw_rect(Rect2(Vector2.ZERO, Vector2(vs.x, 60)), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(Vector2(0, vs.y - 60), Vector2(vs.x, 60)), Color(0, 0, 0, 0.6))
