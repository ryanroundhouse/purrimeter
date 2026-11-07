class_name GamePlatform
## Platform facts shared by the responsive interface, the updater and lifecycle handling.
## Responsive platforms share gameplay; native mobile uses floating controls. Only desktop builds replace
## their own executable through the bundled updater.
const PLAY_URL := "https://play.google.com/store/apps/details?id=com.roundhouselabsinc.purrimeter"

const APP_STORE_URL := "https://apps.apple.com/app/id6831635489"

static func android() -> bool:
	return OS.has_feature("android")

static func ios() -> bool:
	return OS.has_feature("ios")

static func native_mobile() -> bool:
	return android() or ios()

static func native_mobile_controls() -> bool:
	return native_mobile() or "--android-ui-test" in OS.get_cmdline_user_args() or "--ios-ui-test" in OS.get_cmdline_user_args()

static func ui_scale() -> float:
	if ios(): return maxf(1.0,DisplayServer.screen_get_scale())
	if android(): return clampf(DisplayServer.screen_get_dpi()/160.0,1.0,4.0)
	return 1.0

static func store_name() -> String:
	return "the App Store" if ios() else "Google Play"

static func safe_area_in(control: Control) -> Rect2:
	var pixels := Rect2(DisplayServer.get_display_safe_area())
	if not pixels.has_area(): return Rect2(Vector2.ZERO,control.size)
	# iOS embeds subwindows, so get_screen_transform() omits the root
	# viewport's stretch. Include it when converting physical safe-area pixels.
	var transform := control.get_screen_transform()
	if ios(): transform=control.get_viewport().get_final_transform()*control.get_global_transform_with_canvas()
	return transform.affine_inverse()*pixels

static func responsive() -> bool:
	return OS.has_feature("web") or native_mobile_controls() or "--mobile-test" in OS.get_cmdline_user_args()

static func touch() -> bool:
	return BrowserPlatform.touch() or (native_mobile() and DisplayServer.is_touchscreen_available())

static func open_store() -> void:
	OS.shell_open(APP_STORE_URL if ios() else PLAY_URL)

# Convert Android sp through TypedValue so Android 14's nonlinear font scaling is
# preserved. Cache sizes: JNI must not run for every label on every rendered frame.
static var font_sizes: Dictionary = {}
static func ui_font_size(base: int) -> int:
	if not android(): return base
	if font_sizes.has(base): return font_sizes[base]
	var size := base
	if Engine.has_singleton("AndroidRuntime") and Engine.has_singleton("JavaClassWrapper"):
		var runtime = Engine.get_singleton("AndroidRuntime")
		var wrapper = Engine.get_singleton("JavaClassWrapper")
		var metrics = runtime.getApplicationContext().getResources().getDisplayMetrics()
		var typed_value = wrapper.wrap("android.util.TypedValue")
		var pixels = typed_value.applyDimension(2,float(base),metrics) # COMPLEX_UNIT_SP
		if wrapper.get_exception()==null and pixels is float:
			size=maxi(1,roundi(pixels/clampf(DisplayServer.screen_get_dpi()/160.0,1.0,4.0)))
	font_sizes[base]=size
	return size

static func apply_font(control: Control, base: int) -> void:
	control.set_meta("android_font_base",base)
	control.add_theme_font_size_override("font_size",ui_font_size(base))

static func refresh_fonts(node: Node) -> void:
	if node is Control and node.has_meta("android_font_base"):
		apply_font(node,node.get_meta("android_font_base"))
	for child in node.get_children(): refresh_fonts(child)
