# ui_constants.gd
# UI 스타일 통일을 위한 상수 정의
class_name UIConstants
extends RefCounted

# ============================================================
# MARGINS & SPACING
# ============================================================
const PANEL_MARGIN := 16 # 화면 가장자리 여백
const PANEL_PADDING := 12 # 패널 내부 패딩
const ELEMENT_SPACING := 8 # 요소 간 간격

# ============================================================
# SIZES
# ============================================================
const SIDEBAR_WIDTH := 280 # 사이드바 패널 너비
const BUTTON_MIN_SIZE := Vector2(32, 32) # 최소 버튼 크기
const ICON_BUTTON_SIZE := Vector2(28, 28) # 아이콘 버튼 크기

# ============================================================
# FONT SIZES
# ============================================================
const FONT_SIZE_TITLE := 18
const FONT_SIZE_BODY := 14
const FONT_SIZE_SMALL := 12
