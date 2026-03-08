
package main

import SDL "vendor:sdl3"
import IMG "vendor:sdl3/image"
import TTF "vendor:sdl3/ttf"


import "core:fmt"
import "core:c"
import "core:strings"
import "core:log"
import "core:math"
import "core:math/linalg"
import "core:time"
import tz "core:time/timezone"

import "base:runtime"


import clay "clay-odin"


window: ^SDL.Window
renderer: ^SDL.Renderer
engine: ^TTF.TextEngine

clay_memory: []byte

win_size: [2]i32 = {1280, 720}


clay_error_handler :: proc "c" (errorData: clay.ErrorData) {
    context = get_global_context()
    fmt.println(errorData)
}


GalleryImage :: struct {
	img_path: string,
	bytes: []byte,
	texture: ^SDL.Texture,
}

images: [dynamic]GalleryImage = {}

parse_files :: proc (result: RequestResult) {
	bytes := result.bytes
    file := string(bytes)

    for path in strings.split_iterator(&file, "\n") {
		image := GalleryImage {
			img_path = path
		}
		ImgPath :: struct {
			index: uint
		}
		img_idx := uint(len(images))

        append(&images, image) // crash on web
        full_path := fmt.tprintf("gallery/%s", path)

		c_path := strings.clone_to_cstring(full_path)

		img_path := new(ImgPath)
		img_path^ = {img_idx}
		request_data(c_path, img_path, proc(result: RequestResult) {
			img_path := (^ImgPath)(result.user_data)
			bytes := result.bytes
			io := SDL.IOFromConstMem(&bytes[0], len(bytes))
			image := &images[img_path.index]
			image.texture = IMG.LoadTexture_IO(renderer, io, false)
		})
    }
}

assign_font :: proc (result: RequestResult) {

	bytes := result.bytes
    if len(bytes) == 0 {
		return
	}
	io := SDL.IOFromConstMem(&bytes[0], len(bytes))

	text_font_id = load_font_io(io)
}

app_init :: proc (appstate: ^rawptr, argc: i32, argv: [^]cstring) -> SDL.AppResult {
	log.info("app_init")
    _ = SDL.SetAppMetadata("Example", "1.0", "com.example")

	when ODIN_OS == .Linux && !(ODIN_PLATFORM_SUBTARGET == .Android) {
		SDL.SetHint(SDL.HINT_VIDEO_DRIVER, "wayland,x11");
	}

    if (!SDL.Init({.VIDEO})) {
        return .FAILURE
    }
	SDL.SetJoystickEventsEnabled(true)
	SDL.SetGamepadEventsEnabled(true)

    if !TTF.Init() {
        fmt.println("Failed to initialize TTF engine")
        return .FAILURE
    }

    if (!SDL.CreateWindowAndRenderer("examples", win_size.x, win_size.y, {.RESIZABLE, .HIGH_PIXEL_DENSITY}, &window, &renderer)){
        return .FAILURE
    }

	pixel_density := SDL.GetWindowDisplayScale(window)
	if pixel_density != 0 {
		dpi_window = pixel_density
		DPI_set(dpi_user * dpi_window)
	}

    engine = TTF.CreateRendererTextEngine(renderer)

    request_data("Play-Regular.ttf", nil, assign_font)
    request_data("gallery/files.txt", nil, parse_files)

    min_size := clay.MinMemorySize()

    clay_memory = make([]byte, min_size)
    clay_arena := clay.CreateArenaWithCapacityAndMemory(uint(min_size), &clay_memory[0])
    clay.Initialize(clay_arena, {f32(win_size.x), f32(win_size.y)}, { handler = clay_error_handler })
    clay.SetMeasureTextFunction(clay_measure_text, nil)

	gfx_init()

	input_fullscreen = create_keyboard_mapping(.F11)
	input_quit = create_keyboard_mapping(.ESCAPE)
	input_inspector = create_keyboard_mapping(.F8)

	app_add_event_handler(app_event)

    return .CONTINUE
}

input_fullscreen: MappingIndex
input_quit: MappingIndex
input_inspector: MappingIndex

app_event :: proc (evt: ^Event) {

	if pressed, matches := match_mapping_button(evt, input_fullscreen); matches {
		if pressed {
			evt.handled = true
			current_fullscreen := (SDL.GetWindowFlags(window) & SDL.WINDOW_FULLSCREEN) != {}
			SDL.SetWindowFullscreen(window, !current_fullscreen)
		}
	}

	if pressed, matches := match_mapping_button(evt, input_quit); matches {
		if pressed {
			evt.handled = true
			app_quit()
		}
	}

	if pressed, matches := match_mapping_button(evt, input_inspector); matches && pressed {
		clay.SetDebugModeEnabled(true)
		evt.handled = true
	}

	nav_handle_input(evt)

	ui_push_pointer_event(evt)

	event := evt.sdl_event
	#partial switch event.type {


	case .PEN_PROXIMITY_IN, .PEN_PROXIMITY_OUT:
		log.info(event.pproximity)
	case .PEN_DOWN, .PEN_UP:
		log.info(event.ptouch)
	case .PEN_BUTTON_DOWN, .PEN_BUTTON_UP:
		log.info(event.pbutton)
	case .PEN_MOTION:
		log.info(event.pmotion)
	case .PEN_AXIS:
		log.info(event.paxis)

	case .JOYSTICK_AXIS_MOTION:
		log.info(event.jaxis)
	case .JOYSTICK_UPDATE_COMPLETE:
		log.info(event.jdevice)
	//case:
	//	fmt.println("event.type:", event.type)

	}
}


last_ticks : u64 = 0

desired_delay_ticks: u64 = 1_000_000_000 / 60

next_iterate_ticks: u64 = 0


app_iterate :: proc (appstate: rawptr) -> SDL.AppResult {
	current_ticks := SDL.GetTicksNS()
	missing_ticks: i64 = i64(next_iterate_ticks) - i64(current_ticks)

	if missing_ticks > 0 {
		SDL.DelayNS(u64(missing_ticks))
	}

	actual_ticks := SDL.GetTicksNS()
	delta_ticks := actual_ticks - last_ticks
	last_ticks = actual_ticks
	next_iterate_ticks = actual_ticks + desired_delay_ticks

	delta_time := f64(delta_ticks) / 1000000000.0

	app_tick(delta_time)

	ui_dirty = true

	app_draw()
	return .CONTINUE
}

SlideState :: enum {
	Showing,
	Transitioning,
}

current_state: SlideState

current_show_time: f64
max_show_time: f64 = 5.0

current_transition_time: f64
transition_time: f64 = 1.0

current_img_idx := 0

app_time: f64= 0
app_dt: f64= 0
running: bool = true

app_tick :: proc (dt: f64) {
	app_dt = dt
	if running {
		app_time += dt
	}
	if current_state == .Showing {
		current_show_time += dt
		if current_show_time >= max_show_time {
			current_transition_time = 0
			current_state = .Transitioning
		}
	} else if current_state == .Transitioning {
		current_transition_time += dt
		ui_dirty = true
		if current_transition_time >= transition_time {
			current_state = .Showing
			current_show_time = 0
			current_img_idx = get_next_img_idx(current_img_idx)
		}
	}
	num_joys: c.int
	joys := SDL.GetJoysticks(&num_joys)
	for joy_idx in 0..<num_joys {
		joy_id := joys[joy_idx]
		joystick := SDL.GetJoystickFromID(joy_id)
		//log.info(joystick)
		if !SDL.JoystickConnected(joystick) {
			SDL.OpenJoystick(joy_id)
		}
		axes := SDL.GetNumJoystickAxes(joystick)
		// log.info("axes:", axes)
		if axes == -1 {
			// log.info("error:", SDL.GetError())
		}
		for axis_idx in 0..<axes {
			// axis := SDL.GetJoystickAxis(joystick, axis_idx)
			// log.info("has joystick:", axis_idx, axis)
		}

	}

}

get_next_img_idx :: proc(idx: int) -> int {
	if images != nil {
		return (idx + 1) % len(images)
	}
	return 0
}


render_target: ^SDL.Texture


app_draw :: proc () {
	if ui_dirty {
		ui_dirty = false

		free_all(context.temp_allocator)

		ui_idle(app_dt)
		render_commands := create_layout()

		SDL.SetRenderTarget(renderer, nil)
		SDL.SetRenderDrawColorFloat(renderer, 0, 0, 0, 0)
		SDL.RenderClear(renderer)

		render_layout(&render_commands)

		// draw_debug_texture()

		draw_present()
	}
}

// code I used for drawing some pixels to a buffer and then draw them huge with nearest filtering
// todo: refactor into a proper texture inspector
draw_debug_texture :: proc() {

	vertices_buf: [1000]vec2
	uvs_buf: [1000]vec2
	indices_buf: [2000]u8

	buffer := DrawBuffer {
		0, 0,
		vertices_buf[:],
		uvs_buf[:],
		nil,
		indices_buf[:],
	}

	pos := [2]f32{30, 30}
	yy, xx := math.sincos(f32(app_time) * 0.3)
	//pos  += {xx, yy}
	end := [2]f32{8, 0}
	width := f32(3)
	//buffer_line(&buffer, pos, pos+end, width)
	buffer_circle(&buffer, pos, 20)

	SIZE :: 64

	if render_target == nil {
		render_target = SDL.CreateTexture(renderer, .RGBA32, .TARGET, SIZE, SIZE)
	} {

		SDL.SetTextureScaleMode(render_target, .NEAREST)
		SDL.SetTextureBlendMode(render_target, {.BLEND_PREMULTIPLIED})
		SDL.SetRenderTarget(renderer, render_target)
		SDL.SetRenderDrawColorFloat(renderer, 0,0,0,0)
		SDL.RenderClear(renderer)
		//color := [4]f32{0.5, 0.5, 0.5, 0.5}
		color := [4]f32{1, 1, 1, 1}
		//color := [4]f32{200, 200, 200, 1}
		draw_buffer(renderer, &buffer, color)
		SDL.SetRenderTarget(renderer, nil)
	}

	rect := SDL.FRect{0, 0, SIZE, SIZE}

	origin :: vec2{20, 20}
	target_pos := SDL.FPoint{origin.x, origin.y}
	SCALE :: 32
	target_right := SDL.FPoint{target_pos.x + SIZE * SCALE,target_pos.y}
	target_down := SDL.FPoint{target_pos.x, target_pos.y + SIZE * SCALE}

	SDL.RenderTextureAffine(renderer, render_target, &rect, &target_pos, &target_right, &target_down)

	line_color := [4]f32{1,0.3,0.3,0.3}
	for idx_int in 0..=SIZE {
		idx := f32(idx_int)

		draw_line(renderer, {0, idx} * SCALE + origin, {SIZE, idx} * SCALE + origin, 1, line_color)
		draw_line(renderer, {idx, 0} * SCALE + origin, {idx, SIZE} * SCALE + origin, 1, line_color)
	}

	tx :: proc (vert: vec2) -> vec2 { return (vert * SCALE + origin) }

	for idx in 0..<buffer.num_vertices {
		vert := buffer.vertices[idx]
		uv := buffer.uvs[idx]
		pos := vert * SCALE + {target_pos.x, target_pos.y}
		pos.x = math.round(pos.x)
		pos.y = math.round(pos.y)

		draw_circle(renderer, pos, 3)

		text := fmt.ctprintf("%.6f\n%.6f", uv.x, uv.y)
		SDL.SetRenderDrawColorFloat(renderer, 1,0,0,0.5)
		//SDL.RenderDebugText(renderer, pos.x, pos.y, text)

		text2 := fmt.ctprintf("%.6f\n%.6f", vert.x, vert.y)
		SDL.SetRenderDrawColorFloat(renderer, 0,1,0,0.5)
		//SDL.RenderDebugText(renderer, pos.x, pos.y+10, text2)
	}
	for idx in 0..<buffer.num_indices {
		if idx % 3 == 0 {
			a := buffer.indices[idx]
			b := buffer.indices[idx+1]
			c := buffer.indices[idx+2]
			draw_line(renderer, tx(buffer.vertices[a]), tx(buffer.vertices[b]), 1, line_color)
			draw_line(renderer, tx(buffer.vertices[b]), tx(buffer.vertices[c]), 1, line_color)
			draw_line(renderer, tx(buffer.vertices[c]), tx(buffer.vertices[a]), 1, line_color)
		}
	}
}


clock_render_data := CustomRenderData {
	callback = draw_clock,
//	User_data = nil
}

layout_clock :: proc() {

	CLK_SIZE :: 240
	CLK_OFFSET :: 20

	clay.UI(clay.ID("clock"))(DPI({
		layout = {
			layoutDirection = .LeftToRight,
			sizing = { width = clay.SizingFixed(CLK_SIZE), height = clay.SizingFixed(CLK_SIZE) },
			childGap = 16,
		},
		floating = {
			attachTo = .Parent,
			attachment = {
				element = .RightTop,
				parent = .RightTop,
			},
			offset = {-CLK_OFFSET, CLK_OFFSET},
		},
		backgroundColor = {1,1,1,1},
		custom = { &clock_render_data },
	}))

	ui_pointer_handler()
}

draw_clock :: proc (render_data: ^CustomRenderData, render_command: ^clay.RenderCommand) {
	box := render_command.boundingBox

	draw_push_state()

	angle := f32(1) + f32(app_time * 0.2)
	axis := [3]f32{0, 0, 1}
	axis = linalg.normalize(axis)
	mat: matrix[3,3]f32 = 1
	mat *= linalg.matrix3_rotate(angle, axis)
	mat *= {1.2, 0, 0, 0, 1, 0, 0, 0, 1}
	mat *= linalg.matrix3_rotate(-angle, axis)

	mata := matrix[3,3]f32{
		1, 0, 0,
		0, 1, 0,
		0, 0, 1,
	}

	draw_set_draw_rect(renderer, {i32(box.x), i32(box.y)}, {i32(box.width), i32(box.height)})
	draw_set_view_rect({-1.2, 1.2}, {1.2, -1.2})

	LINE_SCALE :: 0.02
	draw_set_line_scale(0.02)

	draw_circle(renderer, {0, 0}, 1.1, {0, 0, 0, 0.8})

	vert_pos := vec2{1, 0}

	segments := 12
	delta_angle := (math.TAU) / f32(segments)
	mat_cos := math.cos(delta_angle)
	mat_sin := math.sin(delta_angle)

	draw_set_matrix(mat)

	for idx in 0..<segments {
		vert_pos = {
			vert_pos.x * mat_cos - vert_pos.y * mat_sin,
			vert_pos.x * mat_sin + vert_pos.y * mat_cos,
		}
		draw_line(renderer, vert_pos * 0.8, vert_pos, 2)
	}

	time_now := time.now()
	dt_utc, _ := time.time_to_datetime(time_now)
	dt := dt_utc

	local_tz, local_load_ok := tz.region_load("local")
	if local_load_ok {
		dt, _ = tz.datetime_to_tz(dt_utc, local_tz)
	} else {
		// in android the tz doesn't work at the moment
		secs := time.time_to_unix(time_now)
		secs -= (5 * 60 * 60) // colombia time
		adj_time := time.unix(secs, i64(dt.nano))
		dt, _ = time.time_to_datetime(adj_time)
	}

	h := dt.time.hour
	m := dt.time.minute
	s := dt.time.second

	frac := f32(dt.time.nano) / 1e9

	frac = math.min(1, frac * 15)

	t_1 := frac-1
	t_1_2 := t_1 * t_1
	t_1_3 := t_1_2 * t_1
	k := f32(2.5)
	sec_offset := 1 + (k+1)*(t_1_3) + k*(t_1_2)

	ss := f32(s) + sec_offset// + (f32(ns) / 1e9)
	mm := f32(m) + ss/60
	hh := f32(h) + mm/60

	hour_sin, hour_cos := math.sincos((0.25 - hh/12) * math.TAU)
	min_sin, min_cos := math.sincos((0.25 - mm/60) * math.TAU)
	sec_sin, sec_cos := math.sincos((0.25 - ss/60) * math.TAU)

	hour_dir := vec2 {hour_cos, hour_sin}
	min_dir := vec2 {min_cos, min_sin}
	sec_dir := vec2 {sec_cos, sec_sin}

	draw_line(renderer, -0.1 * hour_dir, 0.5 * hour_dir, 2)
	draw_line(renderer, -0.15 * min_dir, 0.75 * min_dir, 2)
	draw_line(renderer, -0.15 * sec_dir, 0.7 * sec_dir, 2, {1, 0, 0, 1})
	draw_clear_matrix()

	draw_pop_state()
}


ui_dirty: bool = true

text_font_id: u16 = NIL_FONT

main_nav: NavigationScope


hide_ui_timeout := f32(5)
hide_ui_time: f64

toolbar_last_interaction_is_mouse := false

main_handler :: proc(event: ^Event, user_data: rawptr) {
	if event.type == .Keyboard {
		//log.info(event)

	}

	if event.type == .Mouse || event.type == .Keyboard {
		if event.phase == .Capturing {
			hide_ui_time = app_time + f64(hide_ui_timeout)
		}
		toolbar_last_interaction_is_mouse = event.type == .Mouse
	}
}


text_config: ^clay.TextElementConfig

// An example function to create your layout tree
create_layout :: proc() -> clay.ClayArray(clay.RenderCommand) {

	// Begin constructing the layout.
	text_config = clay.TextConfig({
		fontId = text_font_id,
		textColor = color_text,
		fontSize = border_policy(16),
		textAlignment = .Center,
	})

	clay.BeginLayout()

	{
		ui_reset_handler_buffer()
		ui_pointer_handler(main_handler)

		clear(&main_nav.contents)
		//navigation_scope.wrap = true
		main_nav.direction = .Vertical

		nav_scope(&main_nav, main_handler)

		{
			nav_add_item("center")
		}

		layout_gallery()
		layout_toolbar()

		layout_clock()
	}
	nav_finish()

	// Returns a list of render commands
	result := clay.EndLayout()
	return result

}

gallery_render_data := CustomRenderData {
	render_gallery
}

layout_gallery :: proc () {
	clay.UI(clay.ID("gallery"))({
		layout = {
			sizing = {
				width = clay.SizingPercent(1),
				height = clay.SizingPercent(1),
			},
		},
		custom = {&gallery_render_data},
	})
}

AspectRatioFitMode :: enum {
	Fit,
	FillX,
	FillY,
	Fill,
}

// returns a smaller rect that would fit while keeping aspect ratio
rect_aspect_fit :: proc(rect: SDL.FRect, aspect: f32) -> SDL.FRect {
	current := rect.w / rect.h
	out := rect
	if current > aspect {
		// current is wider, trim horizontal
		out.x += out.w  * 0.5
		out.w = out.h * aspect
		out.x -= out.w * 0.5
	} else {
		// current is taller, trim vertical
		out.y += out.h  * 0.5
		out.h = out.w / aspect
		out.y -= out.h * 0.5
	}
	return out
}

draw_tex_rect_aspect :: proc(rect: SDL.FRect, tex: ^SDL.Texture, fill: bool, color: [4]f32) {

	img_aspect :=  f32(tex.w) / f32(tex.h)
	box_aspect := rect.w / rect.h

	dstrect := rect
	srcrect := SDL.FRect{0, 0, f32(tex.w), f32(tex.h)}
	if fill {
		srcrect = rect_aspect_fit(srcrect, box_aspect)
	} else {
		dstrect = rect_aspect_fit(dstrect, img_aspect)
	}

	SDL.SetTextureBlendMode(tex, {.BLEND})
	SDL.SetTextureColorModFloat(tex, color[0], color[1], color[2])
	SDL.SetTextureAlphaModFloat(tex, color[3])
	SDL.RenderTexture(renderer, tex, &srcrect, &dstrect)
}

render_gallery :: proc (render_data: ^CustomRenderData, render_command: ^clay.RenderCommand) {
	in_rect := render_command.boundingBox

	if len(images) <= 0 {
		return
	}

	dark_level := f32(0.25)
	back_color_dark := clay.Color{dark_level, dark_level, dark_level, 1}
	back_color := clay.Color{1, 1, 1, 1}
	curr_img_tex := images[current_img_idx].texture

	rect := SDL.FRect{in_rect.x, in_rect.y, in_rect.width, in_rect.height}
	draw_tex_rect_aspect(rect, curr_img_tex, true, back_color_dark)
	draw_tex_rect_aspect(rect, curr_img_tex, false, back_color)

	if current_state == .Transitioning {
		front_color_dark := back_color_dark
		front_color := back_color
		progress := current_transition_time / transition_time
		alpha := f32(progress)
		front_color_dark.a = alpha
		front_color.a = alpha
		next_img_idx := get_next_img_idx(current_img_idx)
		next_img_tex := images[next_img_idx].texture
		draw_tex_rect_aspect(rect, next_img_tex, true, front_color_dark)
		draw_tex_rect_aspect(rect, next_img_tex, false, front_color)
	}
}



toolbar_decl := clay.ElementDeclaration {
    layout = {
        layoutDirection = .LeftToRight,
        sizing = { width = clay.SizingFit(), height = clay.SizingFit() },
        childGap = 16,
    },
	floating = {
		attachTo = .Parent,
		attachment = {
			element = .CenterBottom,
			parent = .CenterBottom,
		},
		offset = {0, -16},
	},
}

section_decl := clay.ElementDeclaration {
	layout = {
		layoutDirection = .TopToBottom,
		padding = {4, 4, 4, 4},
		childAlignment = {.Center, .Top}
	},
	cornerRadius = {20, 20, 20, 20},
	backgroundColor = color_frame,
}

subsection_decl := clay.ElementDeclaration {
	layout = {
		layoutDirection = .LeftToRight,
		childGap = 4,
	},
}


toolbar_opacity: f32
toolbar_nav: NavigationScope

idle_toolbar :: proc(dt: f64) {

	mouse_activity_visible := hide_ui_time > app_time
	navigation_focused := false
	toolbar_visible := mouse_activity_visible || navigation_focused

	if toolbar_visible {
		if toolbar_opacity != 1.0 {
			fadein_time :: 0.1 // seconds
			toolbar_opacity += f32(dt / fadein_time)
			toolbar_opacity = math.min(1.0, toolbar_opacity)
		}
	} else {
		if toolbar_opacity != 0.0 {
			fadeout_time :: 0.2
			toolbar_opacity -= f32(dt / fadeout_time)
			toolbar_opacity = math.max(0.0, toolbar_opacity)
		}
	}
}


opacity_modifier: UIModifierModulate

layout_toolbar :: proc() {

	idle_toolbar(app_dt)


	clear(&toolbar_nav.contents)
	toolbar_nav.direction = .Horizontal

	nav_scope(&toolbar_nav)

	if toolbar_opacity == 0 {
		return
	}

	opacity_modifier = ui_modifier_modulate({1,1,1,toolbar_opacity})

	toolbar_style := DPI(toolbar_decl)
	section_style := DPI(section_decl)
	subsection_style := DPI(subsection_decl)

    clay.UI(clay.ID("ToolBar"))(toolbar_style)
	ui_pointer_handler()

	ui_modifier(&opacity_modifier)


	{
		clay.UI(clay.ID("ToolBarSection"))(section_style)
		clay.Text("Gallery Config", text_config)
		clay.UI()(subsection_style)
		sidebar_item_component("Select Folder", proc(c: rawptr) { select_directory() })
		sidebar_item_component("Config Online Src")
	}

	{
		clay.UI(clay.ID("ToolBarSection2"))(section_style)
		clay.Text("Slideshow", text_config)
		clay.UI()(subsection_style)
		sidebar_item_component("First", proc(c: rawptr) { playback_first()})
		sidebar_item_component("Previous", proc(c: rawptr) { playback_previous()})
		sidebar_item_component("Play\nPause", proc(c: rawptr) { playback_playpause()})
		sidebar_item_component("Next", proc(c: rawptr) { playback_next()})
		sidebar_item_component("Last", proc(c: rawptr) { playback_last()})
    }
}


select_directory :: proc() {
	fmt.println("select_directory")
	//ShowOpenFolderDialog         :: proc(callback: DialogFileCallback, userdata: rawptr, window: ^Window, default_location: cstring, allow_many: bool) ---
	SDL.ShowOpenFolderDialog(select_directory_callback, nil, window, nil, true)

	//ShowOpenFileDialog           :: proc(callback: DialogFileCallback, userdata: rawptr, window: ^Window, filters: [^]DialogFileFilter, nfilters: c.int, default_location: cstring, allow_many: bool) ---
	//SDL.ShowOpenFileDialog(select_directory_callback, nil, window, nil, 0, nil, false)

}

select_directory_callback: SDL.DialogFileCallback : proc "c" (userdata: rawptr, filelist: [^]cstring, filter: c.int) {
	context = get_global_context()
	if filelist == nil {
		error := SDL.GetError()
		fmt.println("got error:", error)
		return
	}
	idx := 0
	file := filelist[idx]
	if file == nil {
		fmt.println("got no files, user cancelled input")
		return
	}
	for file != nil {
		fmt.println("got file idx:", idx, file)
		idx += 1
		file = filelist[idx]
	}

}

playback_first :: proc() {
	fmt.println("first")
	print_render_commands = true
}

playback_previous :: proc() {
	fmt.println("previous")
}
playback_playpause :: proc() {
	fmt.println("playpause")
	running = !running
}

playback_next :: proc() {
	fmt.println("next")
}


dpi_index := 2
dpi_user := f32(1)
dpi_window := f32(1)
dpi_levels := []f32 {
	0.5,
	0.8,
	1,
	1.5,
	2,
	3,
	4,
}
playback_last :: proc() {
	fmt.println("last")
	dpi_index = (dpi_index + 1) % len(dpi_levels)
	dpi_user = dpi_levels[dpi_index]
	DPI_set(dpi_user * dpi_window)
}



// ClayButtonHandlerType :: #type proc(id: clay.ElementId, pointerData: clay.PointerData, userdata: rawptr)
ButtonHandlerType :: #type proc(userdata: rawptr)

HandlerInfo :: struct {
	handler: ButtonHandlerType,
	data: rawptr,
}

color_idle := clay.Color {0.0, 0.0, 0.0, 1}
color_border := clay.Color {1, 1, 1, 0.3}
color_frame := clay.Color {0.2, 0.2, 0.2, 1}
//color_frame := clay.Color {1, 1, 1, 1}
color_hover := clay.Color {0.4, 0.4, 0.4, 1}
color_text := clay.Color {0.8, 0.8, 0.8, 1}


rotate_modifier: UIModifierTransform

// Re-useable components are just normal procs.
sidebar_item_component :: proc($label: string, callback: ButtonHandlerType = nil, user_data: rawptr = nil) {

	item_style := clay.ElementDeclaration {
		layout = {
			sizing = {
				width = clay.SizingFixed(64),
				height = clay.SizingFixed(64),
			},
			childAlignment = {.Center, .Center}
		},
		cornerRadius = {16, 16, 16, 16},
		border = {
			width = {1, 1, 1, 1, 0},
			color = color_border,
		},
	}

	info: ^HandlerInfo
	if callback != nil {
		info = new(HandlerInfo, context.temp_allocator)
		info.handler = callback
		info.data = user_data
	}

	clay.UI(clay.ID(label))
	item_handle := nav_add_item(label, ui_button_handler, info)

	is_focused := false
	if toolbar_last_interaction_is_mouse {
		is_focused = clay.Hovered()
	} else {
		is_focused = nav_get_focused(item_handle)
	}

	rotate_modifier = ui_modifier_transform(
		linalg.matrix3_rotate(math.sin(f32(app_time*3)) * 0.2, [3]f32{0,0,1}),
		{0.5, 0.0},
	)

	if is_focused {
		ui_modifier_push(&rotate_modifier)
	}

	item_style.backgroundColor = is_focused ? color_hover : color_idle

	config_proc := clay.UI()

	config_proc(DPI(item_style))
	ui_pointer_handler(ui_button_handler, info)

	clay.Text(
        label,
        text_config,
    )

	if is_focused {
		ui_modifier_pop(&rotate_modifier)
	}

}


ui_button_handler :: proc (event: ^Event, handler_info: rawptr) {
	if event.phase == .Capturing { return }
	commit := false
	if event.sdl_event.type == .MOUSE_BUTTON_DOWN {
		button_event := event.sdl_event.button
		if button_event.button == SDL.BUTTON_LEFT {
			commit = true
		}
	}

	pressed, matches := match_mapping_button(event, nav_confirm)
	if matches && pressed {
		commit = true
	}

	if commit {
		if handler_info != nil {
			handler_data := (^HandlerInfo)(handler_info)
			handler_data.handler(handler_data.data)
		}
		event.handled = true
	}
}
