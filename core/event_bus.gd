# event_bus.gd
# 이벤트 버스 싱글톤 - 모듈 간 느슨한 결합을 위한 중앙 신호 허브
extends Node

# ============================================================
# TILE INTERACTION SIGNALS
# ============================================================
signal tile_clicked(midi_note: int, string_index: int, modifiers: Dictionary)

# ============================================================
# SEQUENCER STATE & SIGNALS
# ============================================================
var is_sequencer_playing: bool = false # 시퀀서 재생 상태 (전역 접근용)

signal sequencer_started
signal sequencer_stopped
signal bar_changed(slot_index: int)
