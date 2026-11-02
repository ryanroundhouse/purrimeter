class_name GamePlatform
## Platform facts shared by the responsive interface, the updater and lifecycle handling.
## Browser and Android builds share the phone layouts; only desktop builds replace
## their own executable through the bundled updater.
const PLAY_URL := "https://play.google.com/store/apps/details?id=com.roundhouselabsinc.purrimeter"

static func android() -> bool:
	return OS.has_feature("android")

static func responsive() -> bool:
	return OS.has_feature("web") or android() or "--mobile-test" in OS.get_cmdline_user_args()

static func touch() -> bool:
	return BrowserPlatform.touch() or (android() and DisplayServer.is_touchscreen_available())

static func open_store() -> void:
	OS.shell_open(PLAY_URL)
