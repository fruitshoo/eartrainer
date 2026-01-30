class_name ThemeManager
extends Node

# ============================================================
# THEME DEFINITIONS
# ============================================================
const THEMES = {
	"Default": {
		"root": Color(1.0, 0.8, 0.2), # Golden Yellow
		"third": Color(1.0, 0.6, 0.2), # Orange
		"fifth": Color(0.3, 0.8, 1.0), # Sky Blue
		"seventh": Color(0.4, 1.0, 0.6), # Mint Green
		"scale": Color(0.4, 0.4, 0.4), # Grey
		"avoid": Color(0.05, 0.05, 0.05) # Dark Grey
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
