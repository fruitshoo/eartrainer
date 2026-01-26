# event_bus.gd
# 이벤트 버스 싱글톤 - 모듈 간 느슨한 결합을 위한 중앙 신호 허브
extends Node

# ============================================================
# TILE INTERACTION SIGNALS
# ============================================================
signal tile_clicked(midi_note: int, string_index: int, modifiers: Dictionary)

# ============================================================
# UI SIGNALS
# ============================================================
signal request_toggle_settings
signal settings_visibility_changed(is_visible: bool)


# ============================================================
# SEQUENCER STATE & SIGNALS
# ============================================================
var is_sequencer_playing: bool = false # 시퀀서 재생 상태 (전역 접근용)

signal sequencer_started
signal sequencer_stopped
signal sequencer_playing_changed(is_playing: bool) # 재생 상태 변경 알림
signal request_toggle_playback # 재생/일시정지 토글 요청
signal request_stop_playback # 정지 및 리셋 요청
signal bar_changed(slot_index: int)
signal beat_pulsed # 메트로놈 비트 펄스
signal sequencer_step_beat_changed(step: int, beat: int) # [New]
signal beat_updated(beat_index: int, total_beats: int) # 박자 진행 정보
