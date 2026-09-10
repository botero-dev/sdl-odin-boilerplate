
package main

import SDL "vendor:sdl3"
import IMG "vendor:sdl3/image"


import "core:c"
import "core:fmt"
import "core:log"
import "core:math"
import "core:math/linalg"
import "core:strings"
import "core:time"
import tz "core:time/timezone"

import "core:sync/chan"
import "core:thread"



import "base:runtime"

import ab "engine:."
import gfx "engine:gfx"
import "engine:ui"

when ODIN_PLATFORM_SUBTARGET == .Android {
	@(export)
	SDL_main :: proc "c" (argc: i32, argv: [^]cstring) -> i32 {
		context = runtime.default_context()
		context.logger = runtime.Logger {
			procedure = ab.sdl_log_proc,
		}
		log.info("android SDL_main")
		ab.app_init(nil, init, iterate)
		return 0
	}
} else {
	main :: proc() {
		fmt.println("hello world")
		ab.app_init(nil, init, iterate)
	}
}

on_gallery_loaded :: proc(result: ab.RequestResult) {
	bytes := result.bytes
	file := string(bytes)

	for path in strings.split_iterator(&file, "\n") {
		image := GalleryImage {
			img_path = path,
		}

		img_idx := uint(len(images))
		append(&images, image)
		log.info("loading image:", img_idx)
		full_path := fmt.tprintf("gallery/%s", path)

		c_path := strings.clone_to_cstring(full_path)

		img_path := new(ImgPath)
		img_path^ = {}
		img_path.index = img_idx
		ab.request_data_async(
			c_path,
			img_path,
			proc(result: ab.RequestResult) {
				img_path := (^ImgPath)(result.user_data)
				img_path.data = result.bytes
				unpack_texture(img_path)
				//unpack_tex_thread(img_path)
			},
		)
	}
}



unpack_texture :: proc(data: ^ImgPath) {
	log.info("unpacking texture", data.index, len(data.data))
	//r := SDL.CreateThread(unpack_tex_thread, "unpacktex", data)
	thread.run_with_data(data, unpack_tex_thread)
}


unpack_tex_thread :: proc(in_data: rawptr) {
	context = ab.ctx

	img_path := (^ImgPath)(in_data)
	bytes := img_path.data
	io := SDL.IOFromConstMem(&bytes[0], len(bytes))

	log.info("unpacking texture thread", img_path.index, len(img_path.data))
	surface := IMG.Load_IO(io, false)
	log.info("unpacked  texture thread", img_path.index, len(img_path.data))
	img_path.surface = surface

	finish_img_load(img_path)

}


handle_queued_loads :: proc() {
	data: ^ImgPath
	ok := chan.try_recv_raw(channel, &data)
	if ok {
		finish_img_load_main_thread(data)
	}
}


finish_img_load :: proc(img_path: ^ImgPath) {
	if SDL.GetCurrentThreadID() == ab.main_thread {
		finish_img_load_main_thread(img_path)
	} else {
		img_path_copy := img_path
		_ = chan.send_raw(channel, &img_path_copy)
	}
}



channel: ^chan.Raw_Chan

ImgPath :: struct {
	index:   uint,
	data:    []byte,
	surface: ^SDL.Surface,
}


init :: proc() {
	log.info("init")

	success := ab.create_window("Gallery", {1280, 720})
	assert(success)

	err: runtime.Allocator_Error
	channel, err = chan.create_raw(size_of(^ImgPath), align_of(^ImgPath), 1, context.allocator)
	if err != .None {
		ab.app_status = .FAILURE
		return
	}

	ab.request_data_async("gallery/files.txt", nil, on_gallery_loaded)

}


last_ticks: u64 = 0
desired_delay_ticks: u64 = 1_000_000_000 / 60
next_iterate_ticks: u64 = 0

iterate :: proc() {

	handle_queued_loads()


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

app_time: f64 = 0
app_dt: f64 = 0
running: bool = true

app_tick :: proc(dt: f64) {
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
	for joy_idx in 0 ..< num_joys {
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
		for _ in 0 ..< axes {
			// axis := SDL.GetJoystickAxis(joystick, axis_idx)
			// log.info("has joystick:", axis_idx, axis)
		}

	}

}

images: [dynamic]GalleryImage = {}



GalleryImage :: struct {
	img_path: string,
	bytes:    []byte,
	texture:  ^SDL.Texture,
}

finish_img_load_main_thread :: proc(img_path: ^ImgPath) {
	log.info("finishing:", img_path.index)
	texture := SDL.CreateTextureFromSurface(ab.renderer, img_path.surface)
	log.info("finished: ", img_path.index)
	image := &images[img_path.index]
	image.texture = texture

	images[img_path.index].texture = texture
}


get_next_img_idx :: proc(idx: int) -> int {
	if images != nil {
		return (idx + 1) % len(images)
	}
	return 0
}

app_draw :: proc() {
	if ui_dirty {
		ui_dirty = false

		free_all(context.temp_allocator)

		ui.ui_idle(app_dt)
		create_layout()

		ui.layout_draw()
		ab.draw_present()
	}
}

layout_clock :: proc() {

	CLK_SIZE :: 240
	CLK_OFFSET :: 20

	ui.layout_overlay_child({.End, .Begin})
	ui.layout_custom({
		calc_fitsize = proc() -> [2]f32 { return {CLK_SIZE, CLK_SIZE}},
		callback_render = proc(layout: ui.LayoutState, index: int) {
			computed := layout.items_tree[index].layout_rect
			comm := ab.RenderCommand { boundingBox = computed }
			draw_clock(nil, &comm)
		}
	})


	ui.ui_pointer_handler()
}

draw_clock :: proc(render_data: ^ab.CustomRenderData, render_command: ^ab.RenderCommand) {
	box := render_command.boundingBox

	ab.draw_push_state()

	angle := f32(1) + f32(app_time * 0.2)
	axis := [3]f32{0, 0, 1}
	axis = linalg.normalize(axis)
	mat: matrix[3, 3]f32 = 1
	mat *= linalg.matrix3_rotate(angle, axis)
	mat *= {1.2, 0, 0, 0, 1, 0, 0, 0, 1}
	mat *= linalg.matrix3_rotate(-angle, axis)

	ab.draw_set_draw_rect(ab.renderer, {i32(box.x), i32(box.y)}, {i32(box.w), i32(box.h)})
	ab.draw_set_view_rect({-1.2, 1.2}, {1.2, -1.2})

	LINE_SCALE :: 0.02
	ab.draw_set_line_scale(0.02)

	gfx.draw_circle_basic({0, 0}, 1.1, {0, 0, 0, 0.8})

	vert_pos := [2]f32{1, 0}

	segments := 12
	delta_angle := (math.TAU) / f32(segments)
	mat_cos := math.cos(delta_angle)
	mat_sin := math.sin(delta_angle)

	ab.draw_set_matrix(mat)

	for _ in 0 ..< segments {
		vert_pos = {
			vert_pos.x * mat_cos - vert_pos.y * mat_sin,
			vert_pos.x * mat_sin + vert_pos.y * mat_cos,
		}
		gfx.draw_line(ab.renderer, vert_pos * 0.8, vert_pos, 2)
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

	t_1 := frac - 1
	t_1_2 := t_1 * t_1
	t_1_3 := t_1_2 * t_1
	k := f32(2.5)
	sec_offset := 1 + (k + 1) * (t_1_3) + k * (t_1_2)

	ss := f32(s) + sec_offset // + (f32(ns) / 1e9)
	mm := f32(m) + ss / 60
	hh := f32(h) + mm / 60

	hour_sin, hour_cos := math.sincos((0.25 - hh / 12) * math.TAU)
	min_sin, min_cos := math.sincos((0.25 - mm / 60) * math.TAU)
	sec_sin, sec_cos := math.sincos((0.25 - ss / 60) * math.TAU)

	hour_dir := [2]f32{hour_cos, hour_sin}
	min_dir := [2]f32{min_cos, min_sin}
	sec_dir := [2]f32{sec_cos, sec_sin}

	gfx.draw_line(ab.renderer, -0.1 * hour_dir, 0.5 * hour_dir, 2)
	gfx.draw_line(ab.renderer, -0.15 * min_dir, 0.75 * min_dir, 2)
	gfx.draw_line(ab.renderer, -0.15 * sec_dir, 0.7 * sec_dir, 2, {1, 0, 0, 1})
	ab.draw_clear_matrix()

	ab.draw_pop_state()
}


ui_dirty: bool = true


main_nav := ui.NavigationScope {
	direction = .Vertical
}


hide_ui_timeout := f32(5)
hide_ui_time: f64

toolbar_last_interaction_is_mouse := false

main_handler :: proc(event: ^ab.Event, user_data: rawptr) {
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



// An example function to create your layout tree
create_layout :: proc() {
	// Begin constructing the layout.

	ui.layout_begin({f32(gfx.win_size.x), f32(gfx.win_size.y)}, ab.dpi)

	{
		//ui.ui_reset_handler_buffer()
		ui.ui_pointer_handler(main_handler)

		ui.nav_scope(&main_nav, main_handler)

		{
			ui.nav_add_item("center")
		}

		layout_gallery()
		layout_toolbar()

		layout_clock()
	}
	ui.nav_finish()

	// Returns a list of render commands
	ui.layout_end()
}


layout_gallery :: proc() {
	ui.layout_overlay_child({.Fill, .Fill})
	ui.layout_custom({
		callback_render = proc(layout: ui.LayoutState, index: int) {
			computed := layout.items_tree[index].layout_rect
			comm := ab.RenderCommand { boundingBox = computed }
			render_gallery(nil, &comm)
		}
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
		out.x += out.w * 0.5
		out.w = out.h * aspect
		out.x -= out.w * 0.5
	} else {
		// current is taller, trim vertical
		out.y += out.h * 0.5
		out.h = out.w / aspect
		out.y -= out.h * 0.5
	}
	return out
}

draw_tex_rect_aspect :: proc(rect: SDL.FRect, tex: ^SDL.Texture, fill: bool, color: [4]f32) {

	if tex == nil {
		return
	}

	img_aspect := f32(tex.w) / f32(tex.h)
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
	SDL.RenderTexture(ab.renderer, tex, &srcrect, &dstrect)
}

render_gallery :: proc(render_data: ^ab.CustomRenderData, render_command: ^ab.RenderCommand) {
	in_rect := render_command.boundingBox

	if len(images) <= 0 {
		return
	}

	dark_level := f32(0.1)
	back_color_dark := gfx.f32x4{dark_level, dark_level, dark_level, 1}
	back_color := gfx.f32x4{1, 1, 1, 1}
	curr_img_tex := images[current_img_idx].texture

	//log.info("curr tex: ", curr_img_tex)

	rect := SDL.FRect{in_rect.x, in_rect.y, in_rect.w, in_rect.h}
	draw_tex_rect_aspect(rect, curr_img_tex, true, back_color_dark)
	draw_tex_rect_aspect(rect, curr_img_tex, false, back_color)

	next_img_idx := get_next_img_idx(current_img_idx)
	if (next_img_idx == current_img_idx) {
		return;
	}

	if current_state == .Transitioning {
		front_color_dark := back_color_dark
		front_color := back_color
		progress := current_transition_time / transition_time
		alpha := f32(progress)
		front_color_dark.a = alpha
		front_color.a = alpha
		next_img_tex := images[next_img_idx].texture
		draw_tex_rect_aspect(rect, next_img_tex, true, front_color_dark)
		draw_tex_rect_aspect(rect, next_img_tex, false, front_color)
	}
}


toolbar_opacity: f32
toolbar_nav: ui.NavigationScope

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


opacity_modifier: ab.UIModifierModulate

layout_toolbar :: proc() {

	idle_toolbar(app_dt)


	clear(&toolbar_nav.contents)
	toolbar_nav.direction = .Horizontal

	ui.nav_scope(&toolbar_nav)

	if toolbar_opacity == 0 {
		return
	}

	opacity_modifier = ab.ui_modifier_modulate({1, 1, 1, toolbar_opacity})

		@static init := false
		style_panel := ui.style_class("panel")
		if !init {
			init = true
			ui.push_style(&style_panel, ui.ContainerLinearStyle {
				box_style = ui.BoxStyleColored {
					background = {0.3, 0.3, 0.3, 1},
					border_color = {0.5, 0.5, 0.5, 1},
					border_width = {1, 1, 1, 1}
				},
				padding = {20,20,8,8},
				separation = 12
				
			})
		}


	{
		// overlay on top of root node
		ui.layout_overlay_child({.Middle, .End})
		ui.container_horizontal(separation = 20, offsets = ui.BoxOffsets{30, 30, 30, 30})
	
		//ui.ui_pointer_handler()
		ab.ui_modifier(&opacity_modifier)
		{
			ui.container_vertical(&style_panel)

			ui.layout_linear_child({across = .Center})
			ui.layout_text("Gallery Config")

			{ 
				ui.layout_linear_child({height = ui.Sizing{type = .Weight, amount = 1}})
				ui.container_horizontal(separation=12)
	
				toolbar_button("Select Folder", select_directory)
				toolbar_button("Config Online Src")
			}
		}
		
		{
			ui.container_vertical(&style_panel)
	
			ui.layout_linear_child({across = .Center})
			ui.layout_text("Slideshow")
	
			{
				//ui.layout_linear_child({height = ui.Sizing{type = .Weight, amount = 1}})
				ui.container_horizontal(separation=12)
				toolbar_button("First", playback_first)
				toolbar_button("Previous", playback_previous)
				toolbar_button("Play\nPause", playback_playpause)
				toolbar_button("Next", playback_next)
				toolbar_button("Last", playback_last)
			}
			
		}
		
	}
	
}


select_directory :: proc() {
	SDL.ShowOpenFolderDialog(select_directory_callback, nil, ab.window, nil, true)
}

select_directory_callback: SDL.DialogFileCallback : proc "c" (
	userdata: rawptr,
	filelist: [^]cstring,
	filter: c.int,
) {
	context = ab.get_global_context()
	if filelist == nil {
		error := SDL.GetError()
		log.info("got error:", error)
		return
	}
	idx := 0
	file := filelist[idx]
	if file == nil {
		log.info("got no files, user cancelled input")
		return
	}
	for file != nil {
		log.info("got file idx:", idx, file)
		idx += 1
		file = filelist[idx]
	}

}

playback_first :: proc() {
	log.info("first")
	ab.print_render_commands = true
}

playback_previous :: proc() {
	log.info("previous")
}
playback_playpause :: proc() {
	log.info("playpause")
	running = !running
}

playback_next :: proc() {
	log.info("next")
}


dpi_index := 2
dpi_levels := []f32{0.5, 0.8, 1, 1.5, 2, 3, 4}
playback_last :: proc() {
	log.info("last")
	dpi_index = (dpi_index + 1) % len(dpi_levels)
	ab.dpi_user = dpi_levels[dpi_index]
	ab.DPI_set(ab.dpi_user * ab.dpi_window)
}


color_idle := gfx.f32x4{0.0, 0.0, 0.0, 1}
color_border := gfx.f32x4{1, 1, 1, 0.3}
color_frame := gfx.f32x4{0.2, 0.2, 0.2, 1}
//color_frame := gfx.f32x4 {1, 1, 1, 1}
color_hover := gfx.f32x4{0.4, 0.4, 0.4, 1}
color_text := gfx.f32x4{0.8, 0.8, 0.8, 1}


rotate_modifier: ab.UIModifierTransform

// Re-useable components are just normal procs.
toolbar_button :: proc {
	toolbar_button_handlerinfo,
	toolbar_button_proc,
}

toolbar_button_proc :: proc($label: string, callback: ui.ButtonHandlerSimple) {
	info: ^ui.HandlerInfoSimple
	if callback != nil {
		info = new(ui.HandlerInfoSimple, context.temp_allocator)
		info.handler = handle_proc_simple
		info.callback = callback
	}
	toolbar_button_handlerinfo(label, info)
}

handle_proc_simple :: proc(userdata: ^ui.HandlerInfo) {
	data_simple := (^ui.HandlerInfoSimple)(userdata)
	data_simple.callback()
}


toolbar_button_handlerinfo :: proc($label: string, info: ^ui.HandlerInfo = nil) {

	//clay.UI(clay.ID(label))
	item_handle := ui.ui_add_button(label, info)

	is_focused := false
	if toolbar_last_interaction_is_mouse {
		//is_focused = clay.Hovered()
	} else {
		is_focused = ui.nav_get_focused(item_handle)
	}

	color := color_idle
	if is_focused {
		rotate_modifier = ab.ui_modifier_transform(
			linalg.matrix3_rotate(math.sin(f32(app_time * 3)) * 0.1, [3]f32{0, 0, 1}),
			{0.5, 0.5},
		)
		ab.ui_modifier_push(&rotate_modifier)
		color = color_hover
	}

	ui.layout_button(label)

	//ui.layout_text(label)

	if is_focused {
		ab.ui_modifier_pop(&rotate_modifier)
	}

}
