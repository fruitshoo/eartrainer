# modal_manager.gd
# 모달/패널의 토글 및 배타성을 중앙 관리하는 싱글톤 (트윈 애니메이션 포함)
extends Node

# ============================================================
# SIGNALS
# ============================================================
signal modal_opened(modal_id: String)
signal modal_closed(modal_id: String)

# ============================================================
# CONFIG
# ============================================================
const TWEEN_DURATION := 0.2
const TWEEN_EASE := Tween.EASE_OUT
const TWEEN_TRANS := Tween.TRANS_CUBIC

# ============================================================
# STATE
# ============================================================
# 등록된 모달: {"id": {"node": Node, "anim_node": Node, "group": String, "tween": Tween}}
var _modals: Dictionary = {}

# 배타성 그룹: 같은 그룹 내에서는 하나만 열림
var _exclusivity_groups: Dictionary = {
	"sidebar": [],
	"overlay": []
}

# ============================================================
# PUBLIC API
# ============================================================

## 모달 등록
func register_modal(modal_id: String, node: Node, group: String = "") -> void:
	# CanvasLayer는 modulate가 없으므로 첫 번째 Control 자식을 찾음
	var anim_node: Node = _get_animatable_node(node)
	
	_modals[modal_id] = {
		"node": node,
		"anim_node": anim_node,
		"group": group,
		"tween": null
	}
	
	if group != "" and _exclusivity_groups.has(group):
		if not modal_id in _exclusivity_groups[group]:
			_exclusivity_groups[group].append(modal_id)
	
	# 초기 상태는 숨김
	node.visible = false
	if anim_node:
		anim_node.modulate.a = 0.0
	
	print("[ModalManager] Registered: %s (group: %s)" % [modal_id, group])

## 모달 열기 (배타성 적용 + 트윈)
func open(modal_id: String) -> void:
	if not _modals.has(modal_id):
		push_warning("[ModalManager] Unknown modal: %s" % modal_id)
		return
	
	var modal_data = _modals[modal_id]
	var group = modal_data.group
	
	# 배타성: 같은 그룹 내 다른 모달 닫기
	if group != "" and _exclusivity_groups.has(group):
		for other_id in _exclusivity_groups[group]:
			if other_id != modal_id:
				_close_internal(other_id, true)
	
	# 열기
	var node = modal_data.node
	var anim_node = modal_data.anim_node
	if is_instance_valid(node):
		_open_with_tween(modal_id, node, anim_node)

## 모달 닫기
func close(modal_id: String) -> void:
	_close_internal(modal_id, true)

## 모달 토글
func toggle(modal_id: String) -> void:
	if is_open(modal_id):
		close(modal_id)
	else:
		open(modal_id)

## 모달 열림 상태 확인
func is_open(modal_id: String) -> bool:
	if not _modals.has(modal_id):
		return false
	var node = _modals[modal_id].node
	return is_instance_valid(node) and node.visible

## 모달 등록 해제 (씬 언로드 시)
func unregister_modal(modal_id: String) -> void:
	if _modals.has(modal_id):
		var group = _modals[modal_id].group
		if group != "" and _exclusivity_groups.has(group):
			_exclusivity_groups[group].erase(modal_id)
		_modals.erase(modal_id)

# ============================================================
# INTERNAL HELPERS
# ============================================================

## CanvasLayer면 첫 번째 Control 자식 반환, 아니면 자기 자신
func _get_animatable_node(node: Node) -> Node:
	if node is CanvasLayer:
		for child in node.get_children():
			if child is Control:
				return child
		return null
	elif node is Control:
		return node
	return null

# ============================================================
# TWEEN ANIMATIONS
# ============================================================
func _open_with_tween(modal_id: String, node: Node, anim_node: Node) -> void:
	_kill_existing_tween(modal_id)
	
	node.visible = true
	
	if anim_node:
		anim_node.modulate.a = 0.0
		
		var tween = create_tween().set_ease(TWEEN_EASE).set_trans(TWEEN_TRANS)
		_modals[modal_id].tween = tween
		
		tween.tween_property(anim_node, "modulate:a", 1.0, TWEEN_DURATION)
		tween.finished.connect(func():
			modal_opened.emit(modal_id)
		)
	else:
		# 애니메이션 불가 시 즉시 표시
		modal_opened.emit(modal_id)

func _close_internal(modal_id: String, with_tween: bool = false) -> void:
	if not _modals.has(modal_id):
		return
	
	var modal_data = _modals[modal_id]
	var node = modal_data.node
	var anim_node = modal_data.anim_node
	
	if not is_instance_valid(node) or not node.visible:
		return
	
	if with_tween and anim_node:
		_close_with_tween(modal_id, node, anim_node)
	else:
		node.visible = false
		if anim_node:
			anim_node.modulate.a = 0.0
		modal_closed.emit(modal_id)

func _close_with_tween(modal_id: String, node: Node, anim_node: Node) -> void:
	_kill_existing_tween(modal_id)
	
	var tween = create_tween().set_ease(TWEEN_EASE).set_trans(TWEEN_TRANS)
	_modals[modal_id].tween = tween
	
	tween.tween_property(anim_node, "modulate:a", 0.0, TWEEN_DURATION)
	
	tween.finished.connect(func():
		node.visible = false
		modal_closed.emit(modal_id)
	)

func _kill_existing_tween(modal_id: String) -> void:
	if _modals.has(modal_id) and _modals[modal_id].tween:
		var existing_tween = _modals[modal_id].tween
		if is_instance_valid(existing_tween):
			existing_tween.kill()
		_modals[modal_id].tween = null
