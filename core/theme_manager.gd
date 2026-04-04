class_name ThemeManager
extends Node

# ============================================================
# THEME DEFINITIONS
# ============================================================
const THEMES = {
	"Default": {
		"root": Color("#efd76b"), # Soft warm yellow
		"third": Color("#d7a15a"), # Muted amber
		"fifth": Color("#84c8dc"), # Calm blue-cyan
		"seventh": Color("#9be0c2"), # Soft mint
		"scale": Color("#b9bec8"), # Quiet cool gray
		"avoid": Color("#2b313a") # Deep slate
	},
	"Solarized": {
		"root": Color("#b58900"), # Yellow (Base)
		"third": Color("#cb4b16"), # Orange (Accents)
		"fifth": Color("#268bd2"), # Blue   (Accents)
		"seventh": Color("#2aa198"), # Cyan   (Accents)
		"scale": Color("#586e75"), # Base01 (Content)
		"avoid": Color("#002b36") # Base03 (Background)
	},
	"Gruvbox": {
		"root": Color("#fabd2f"), # Yellow
		"third": Color("#fe8019"), # Orange
		"fifth": Color("#83a598"), # Blue
		"seventh": Color("#8ec07c"), # Aqua
		"scale": Color("#928374"), # Gray
		"avoid": Color("#282828") # Bg
	},
	"Pastel": { # Monument Valley Style
		"root": Color("#FF9AA2"), # Salmon
		"third": Color("#FFB7B2"), # Peach
		"fifth": Color("#B5EAD7"), # Mint
		"seventh": Color("#C7CEEA"), # Periwinkle
		"scale": Color("#E2F0CB"), # Pale Lime
		"avoid": Color("#EAE7DC") # Warm Grey (Not Black)
	}
}

# ============================================================
# UTILITIES
# ============================================================
static func get_color(theme_name: String, role: String) -> Color:
	var theme = THEMES.get(theme_name)
	if not theme:
		theme = THEMES["Default"]
	
	return theme.get(role, Color.MAGENTA) # Fallback Magenta to spot errors
