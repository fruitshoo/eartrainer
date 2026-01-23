class_name ChordLibrary
extends RefCounted

## ChordLibrary
## 로마자 표기법(Roman Numerals)을 실제 반음 간격(Intervals)으로 변환하는 정적 라이브러리.
## 예: "V7" -> [7, 11, 14, 17] (Root 7 + Major 3rd + Perfect 5th + Minor 7th)

# 로마자 -> 반음 간격 변환
static func get_chord_intervals(roman: String) -> Array[int]:
	# 1. 텍스트 정제
	var raw = roman.strip_edges()
	if raw == "|" or raw == "":
		return [] # 쉼표/마디
	
	# 2. 루트(Root) 분석 (I, II, III, IV, V, VI, VII)
	var root_semitone := _parse_roman_root(raw)
	
	# 3. 퀄리티(Quality) 분석 (Major, Minor, 7, dim, etc.)
	var chord_intervals := _parse_chord_quality(raw)
	
	# 4. 루트만큼 이동 (Transposition)
	var final_intervals: Array[int] = []
	for interval in chord_intervals:
		final_intervals.append(interval + root_semitone)
		
	return final_intervals

# 내부 헬퍼: 로마자 루트 파싱
static func _parse_roman_root(roman: String) -> int:
	# 접두사(Accidental) 처리: b(Flat), #(Sharp)
	var offset := 0
	var clean_roman := roman
	
	if roman.begins_with("b"):
		offset = -1
		clean_roman = roman.substr(1)
	elif roman.begins_with("#"):
		offset = 1
		clean_roman = roman.substr(1)
		
	# 대소문자 무시하고 루트 찾기 (일단 루트 숫자만 찾음)
	# 파싱을 위해 앞부분의 로마자만 추출해야 함. (예: "V7" -> "V", "ivm" -> "iv")
	# 정규식 대신 간단한 매칭 사용
	var root_val := 0
	var upper = clean_roman.to_upper()
	
	if upper.begins_with("VII"): root_val = 11
	elif upper.begins_with("VI"): root_val = 9
	elif upper.begins_with("IV"): root_val = 5
	elif upper.begins_with("V"): root_val = 7
	elif upper.begins_with("III"): root_val = 4
	elif upper.begins_with("II"): root_val = 2
	elif upper.begins_with("I"): root_val = 0
	else: root_val = 0 # Default I
	
	return root_val + offset

# 내부 헬퍼: 코드 퀄리티 파싱
static func _parse_chord_quality(roman: String) -> Array[int]:
	var lower = roman.to_lower()
	
	# 기본: Major Triad
	var base := [0, 4, 7]
	
	# 1. 마이너 감지 (소문자 로마자 or 'm')
	# 로마자가 소문자로 시작하면 마이너가 기본 (예: ii, vi)
	# 단, 'I', 'V' 등 대문자는 메이저.
	# 복잡성을 줄이기 위해 명시적 접미사('m', 'dim', 'aug') 우선 확인 후,
	# 로마자 대소문자 컨벤션 적용.
	
	var is_minor_roman := false
	# 첫 글자가 소문자(i, v)인지 확인 (b, # 제외하고 봐야 함)
	var core_roman_start_screen := roman
	if roman.begins_with("b") or roman.begins_with("#"):
		core_roman_start_screen = roman.substr(1)
	
	if core_roman_start_screen.length() > 0:
		var first_char = core_roman_start_screen[0]
		if first_char >= 'a' and first_char <= 'z':
			is_minor_roman = true
			
	if is_minor_roman:
		base = [0, 3, 7] # Minor Triad default
	
	# 2. 세븐스 및 텐션 파싱
	if "maj7" in lower:
		base = [0, 4, 7, 11] # Major 7 (Note: Usually applied to Major base)
		if is_minor_roman: base = [0, 3, 7, 11] # mM7
	elif "m7b5" in lower or "half-dim" in lower:
		base = [0, 3, 6, 10]
	elif "dim7" in lower:
		base = [0, 3, 6, 9]
	elif "dim" in lower: # dim triad
		base = [0, 3, 6]
	elif "aug" in lower:
		base = [0, 4, 8]
	elif "sus4" in lower:
		base = [0, 5, 7]
	elif "sus2" in lower:
		base = [0, 2, 7]
	elif "7" in lower: # Dominant 7 or Minor 7
		if is_minor_roman:
			base = [0, 3, 7, 10] # m7
		else:
			base = [0, 4, 7, 10] # Dom7
	elif "m" in lower and not is_minor_roman: # 대문자인데 뒤에 m이 붙은 경우 (Im)
		base = [0, 3, 7]
		
	return base