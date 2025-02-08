extends "res://addons/GDDataForge/source/data_loader.gd"

## 数据类型处理器
var _parsers : Dictionary[String, Callable] = {
	"string": _parse_string,
	"int": _parse_int,
	"float": _parse_float,
	"bool": _parse_bool,
	"vector2": _parse_vector2,
	"resource": _parse_resource,
	"dictionary": _parse_dictionary,
}
## 支持的数据校验类型
var _validation_types : Array[String] = ["required", "unique", "primary", "min", "max", "range", "enum", "foreign", "custom"]

## 重写加载单一数据表，这里对CSV文件数据行格式化
func load_datatable(table_path: StringName) -> Dictionary:
	var file := FileAccess.open(table_path, FileAccess.READ)
	var ok := FileAccess.get_open_error()
	if ok != OK: 
		push_error("未能正确打开文件！")
	var file_data : Dictionary = {}
	# CSV数据解析
	var data_names : PackedStringArray = file.get_csv_line(",")					# 第1行是数据名称字段
	var validation_rules : PackedStringArray = file.get_csv_line(",")			# 第2行是数据验证规则
	var data_types : PackedStringArray = file.get_csv_line(",")					# 第3行是数据类型字段
	
	# 解析验证规则
	var field_rules = {}
	for index in data_names.size():
		var field_name = data_names[index]
		if not field_name.is_empty() and not validation_rules[index].is_empty():
			field_rules[field_name] = _parse_validation_rules(validation_rules[index])
	
	while not file.eof_reached():
		var row : PackedStringArray = file.get_csv_line(",")				# 每行的数据，如果为空则跳过
		if row.is_empty(): continue
		var row_data := {}
		for index: int in row.size():
			# 遍历当前行的每一列
			var data_name : StringName = data_names[index]
			if data_name.is_empty(): continue
			var data_type : StringName = data_types[index]
			if data_type.is_empty(): continue
			row_data[data_name] = _parse_value(row[index], data_type)
		
		# 验证数据
		if not row_data.is_empty() and not row_data.ID.is_empty():
			file_data[StringName(row_data.ID)] = row_data
	return {
		"data": file_data,
		"validation_rules": field_rules
	}

## 注册数据类型处理器
func register_parser(type: StringName, parser: Callable) -> void:
	_parsers[type] = parser

## 注销数据类型处理器
func unregister_parser(type: StringName) -> void:
	_parsers.erase(type)

## 清空数据类型处理器
func clear_parsers() -> void:
	_parsers.clear()

## 数据格式化
func _parse_value(value: String, type: String) -> Variant:
	# 检查是否是数组类型
	if type.ends_with("[]"):
		var base_type = type.substr(0, type.length() - 2)  # 移除 "[]" 后缀
		return _parse_array(value, base_type)
	elif _parsers.has(type):
		return _parsers[type].call(value)
	else:
		push_error("未知的数据类型：{0} in _parsers: {1}".format([type, _parsers]))
		return null

## 通用数组处理函数
func _parse_array(value: String, base_type: String) -> Variant:
	if value.is_empty():
		return []
	
	var elements = value.split("*")
	var result = []
	
	# 根据基础类型处理每个元素
	if _parsers.has(base_type):
		for element in elements:
			result.append(_parsers[base_type].call(element))
	else:
		push_error("未知的数组基础类型：" + base_type)
		return []
	
	return result

## 处理字符串
func _parse_string(v: String) -> String:
	return v

## 处理整数
func _parse_int(v: String) -> int:
	return v.to_int()

## 处理浮点数
func _parse_float(v: String) -> float:
	return v.to_float()

## 处理布尔值
func _parse_bool(v: String) -> bool:
	return bool(v.to_int())

## 处理向量
func _parse_vector2(v: String) -> Vector2:
	var vs : Array[float]
	for element in v.split(","):
		vs.append(element.to_float())
	return Vector2(vs[0], vs[1])

## 处理资源
func _parse_resource(v: String) -> Resource:
	if v.is_empty():
		return null
	if ResourceLoader.exists(v):
		return ResourceLoader.load(v)
	else:
		var error_info: String = "未知的资源类型：" + v
		if OS.has_feature("release"):
			push_error(error_info)
		return null

## 处理字典
func _parse_dictionary(v: String) -> Dictionary:
	var dict : Dictionary
	var kv_pairs = v.split(",")
	for pair in kv_pairs:
		var kv = pair.split(":")
		if kv.size() == 2:
			dict[kv[0].strip_edges()] = kv[1].strip_edges()
	return dict

## 解析验证规则字符串
func _parse_validation_rules(rules_str: String) -> Dictionary:
	var rules = {}
	if rules_str.is_empty():
		return rules
	
	var rule_parts = rules_str.split("|")
	for part in rule_parts:
		if part.is_empty():
			continue
		
		var key_value = part.split(":", 2)
		var rule_name = key_value[0].strip_edges()
		if not rule_name in _validation_types:
			continue
		var rule_params = {} if key_value.size() == 1 else _parse_rule_params(key_value[1])

		rules[rule_name] = {
			"type": rule_name,
			"params": rule_params
		}

	return rules

## 解析规则参数
func _parse_rule_params(params_str: String) -> Variant:
	if params_str.contains("-"):  # 范围参数
		var parts = params_str.split("-")
		return {"min": parts[0].to_float(), "max": parts[1].to_float()}
	return params_str.strip_edges()
