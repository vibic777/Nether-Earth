# Контрибьютор: vibic777
# Справочник: оглавление слева, статья справа. Shift+F1 или «?».
class_name HelpWindow
extends PanelContainer

var _list: ItemList
var _text: RichTextLabel
var _ids: Array[String] = []

func _ready() -> void:
	custom_minimum_size = Vector2(980, 620)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.06, 0.07, 0.07, 0.97)
	st.border_color = Color("3f8f58")
	st.set_border_width_all(2)
	st.set_content_margin_all(14)
	add_theme_stylebox_override("panel", st)
	var v := VBoxContainer.new()
	add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var title := Label.new()
	title.text = "📖 Справочник"
	title.add_theme_font_size_override("font_size", 24)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := Button.new()
	close.text = "✕ Закрыть"
	close.pressed.connect(func() -> void: visible = false)
	head.add_child(close)
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	_list = ItemList.new()
	_list.custom_minimum_size = Vector2(300, 0)
	row.add_child(_list)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text.add_theme_font_size_override("normal_font_size", 18)
	_text.add_theme_font_size_override("bold_font_size", 18)
	row.add_child(_text)
	var last := ""
	for e in HelpDB.index():
		if e["category"] != last:
			last = e["category"]
			var i := _list.add_item("— %s —" % last)
			_list.set_item_selectable(i, false)
			_list.set_item_custom_fg_color(i, Color("c9b06a"))
			_ids.append("")
		_list.add_item("   " + str(e["title"]))
		_ids.append(e["id"])
	_list.item_selected.connect(func(i: int) -> void: _show(_ids[i]))

func open(id: String = "controls") -> void:
	visible = true
	center.call_deferred()
	var i := _ids.find(id)
	if i >= 0:
		_list.select(i)
		_list.ensure_current_is_visible()
	_show(id)

func _show(id: String) -> void:
	if id == "":
		return
	_text.text = "[font_size=26][b]%s[/b][/font_size]\n\n%s" % [HelpDB.title(id), HelpDB.body(id)]


func center() -> void:
	reset_size()
	var vp := get_viewport_rect().size
	position = ((vp - size) * 0.5).floor()
