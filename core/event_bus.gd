# event_bus.gd
# 이벤트 버스 싱글톤 - 모듈 간 느슨한 결합을 위한 중앙 신호 허브
extends Node

# ============================================================
# TILE INTERACTION SIGNALS
# ============================================================
signal tile_clicked(midi_note: int, string_index: int, modifiers: Dictionary)

# ============================================================
# SEQUENCER SIGNALS (향후 확장용)
# ============================================================
signal sequencer_started
signal sequencer_stopped
signal bar_changed(slot_index: int)
