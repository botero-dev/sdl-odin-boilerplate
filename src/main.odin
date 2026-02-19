
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

    if (!SDL.Init({.VIDEO, .JOYSTICK, .GAMEPAD})) {
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

    return .CONTINUE
}

wheel_delta: [2]f32
app_event :: proc (appstate: rawptr, event: ^SDL.Event) -> SDL.AppResult {
	retval := SDL.AppResult.CONTINUE

	SDL.ConvertEventToRenderCoordinates(renderer, event)
	//log.info("sdl event:", event.type)
	#partial switch event.type {
	case .MOUSE_MOTION :
			clay.SetPointerState({event.motion.x, event.motion.y}, (event.motion.state & SDL.BUTTON_LMASK) != {} )
	case .MOUSE_BUTTON_DOWN:
			if event.button.button == SDL.BUTTON_LEFT {
				clay.SetPointerState({event.button.x, event.button.y}, true)
			}
	case .MOUSE_BUTTON_UP:
			if event.button.button == SDL.BUTTON_LEFT {
				clay.SetPointerState({event.button.x, event.button.y}, false)
			}
	case .MOUSE_WHEEL:
		wheel_data := event.wheel
		wheel_delta += {wheel_data.x, wheel_data.y}
	case .QUIT:
		retval = .SUCCESS
	case .WINDOW_RESIZED:
		win_size = {event.window.data1, event.window.data2}
		log.info("window resized logical:", win_size)
		//ui_dirty = true

	case .WINDOW_PIXEL_SIZE_CHANGED:
		win_size = {event.window.data1, event.window.data2}
		log.info("window resized physical:", win_size)
		clay.SetLayoutDimensions({f32(win_size.x), f32(win_size.y)})
		ui_dirty = true
	case .WINDOW_DISPLAY_SCALE_CHANGED:
		win_event := event.window
		win := SDL.GetWindowFromID(win_event.windowID)
		dpi_window = SDL.GetWindowDisplayScale(win)
		DPI_set(dpi_user * dpi_window)

		ui_dirty = true
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

//	case:
//		fmt.println("event.type:", event.type)

	}
    return retval
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
running: bool = true

app_tick :: proc (dt: f64) {
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
		render_commands := create_layout()

		SDL.SetRenderTarget(renderer, nil)
		SDL.SetRenderDrawColorFloat(renderer, 0, 0, 0, 0)
		SDL.RenderClear(renderer)

		clay.UpdateScrollContainers(false, {wheel_delta.x, wheel_delta.y}, 0.01)
		wheel_delta = {}
		render_layout(&render_commands)
		print_render_commands = false

		if false {
			// code I used for drawing some pixels to a buffer and then draw them huge with nearest filtering
			// todo: refactor into a proper texture inspector

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

		CLOCK_SIZE := DPI_mult(200)
		CLOCK_OFFSET := DPI_mult(40)

		draw_set_draw_rect(renderer, {f32(win_size.x) - CLOCK_SIZE-CLOCK_OFFSET, CLOCK_OFFSET}, {CLOCK_SIZE, CLOCK_SIZE})
		draw_set_view_rect({-1.2, 1.2}, {1.2, -1.2})

		LINE_SCALE :: 0.02
		draw_set_line_scale(0.02)

		draw_circle(renderer, {0, 0}, 1.1, {0, 0, 0, 0.8})


		vert_pos := vec2{1, 0}

		segments := 12
		delta_angle := (math.TAU) / f32(segments)
		mat_cos := math.cos(delta_angle)
		mat_sin := math.sin(delta_angle)

		draw_line(renderer, vert_pos * 0.8, vert_pos, 2)
		draw_line(renderer, vert_pos * (0.8 + LINE_SCALE * 0.5), vert_pos*(1-LINE_SCALE*0.5), 1, {0,0,0,1})
		for idx in 0..<segments {
			vert_pos = {
				vert_pos.x * mat_cos - vert_pos.y * mat_sin,
				vert_pos.x * mat_sin + vert_pos.y * mat_cos,
			}
			draw_line(renderer, vert_pos * 0.8, vert_pos, 2)
			//draw_line(renderer, vert_pos * (0.8 + LINE_SCALE * 0.5), vert_pos*(1-LINE_SCALE*0.5), 1, {0,0,0,1})

		}


		local_tz, local_load_ok := tz.region_load("local")

		dt_utc, _ := time.time_to_datetime(time.now())
		dt, _ := tz.datetime_to_tz(dt_utc, local_tz)

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

		draw_line(renderer, {0, 0}, {hour_cos, hour_sin} * 0.5, 2)
		draw_line(renderer, {0, 0}, {min_cos, min_sin} * 0.8, 2)
		draw_line(renderer, {0, 0}, {sec_cos, sec_sin} * 0.7, 2, {1, 0, 0, 1})



		draw_clear_view_rect()
		draw_clear_draw_rect(renderer)
		draw_set_line_scale(0)

		SDL.RenderPresent(renderer)
	}
}


ui_dirty: bool = true

text_font_id: u16 = NIL_FONT

// An example function to create your layout tree
create_layout :: proc() -> clay.ClayArray(clay.RenderCommand) {
    // Begin constructing the layout.
	clay.BeginLayout()

	text_config = clay.TextConfig({
		fontId = text_font_id,
		textColor = color_text,
		fontSize = border_policy(16),
		textAlignment = .Center,
	})
	//clay.SetDebugModeEnabled(true)

    // An example of laying out a UI with a fixed-width sidebar and flexible-width main content
    // NOTE: To create a scope for child components, the Odin API uses `if` with components that have children
    if /*clay.UI(clay.ID("OuterContainer"))({
        layout = {
            sizing = { width = clay.SizingGrow({}), height = clay.SizingGrow({}) },
            padding = { 16, 16, 16, 16 },
            childGap = 16,
        },
		backgroundColor = {0, 0, 0, 1}
    })*/ true {

		if len(images) > 0 {

			img_layout := clay.LayoutConfig {
				sizing = {
					width = clay.SizingGrow(),//clay.SizingPercent(1),
					height = clay.SizingGrow(),//clay.SizingPercent(1),
				},
				layoutDirection = .LeftToRight,
			}
			dark_level := f32(0.25)
			back_color_dark := clay.Color{dark_level, dark_level, dark_level, 1}
			back_color := clay.Color{1, 1, 1, 1}
			curr_img_tex := images[current_img_idx].texture
			if clay.UI(clay.ID("BackgroundDark"))({
				floating = {
					attachTo = .Parent,
					attachment = {
						element = .CenterCenter,
						parent = .CenterCenter,
					},
				},
				layout = img_layout,
				backgroundColor = back_color_dark,
				image = {
					imageData = curr_img_tex
				},
				aspectRatio = {f32(curr_img_tex.w) / f32(curr_img_tex.h), .Fill},
			}) {}
			if clay.UI(clay.ID("Background"))({
				floating = {
					attachTo = .Parent,
					attachment = {
						element = .CenterCenter,
						parent = .CenterCenter,
					},
				},
				layout = img_layout,
				backgroundColor = back_color,
				image = {
					imageData = curr_img_tex
				},
				aspectRatio = {f32(curr_img_tex.w) / f32(curr_img_tex.h), .Fit},
			}) {}

			front_color_dark := back_color_dark
			front_color := back_color
			if current_state == .Transitioning {
				progress := current_transition_time / transition_time
				alpha := f32(progress)
				front_color_dark.a = alpha
				front_color.a = alpha
			} else {
				front_color_dark.a = 0
				front_color.a = 0
			}
				next_img_idx := get_next_img_idx(current_img_idx)
				next_img_tex := images[next_img_idx].texture
				if clay.UI(clay.ID("BlendInDark"))({
					floating = {
						attachTo = .Parent,
						attachment = {
							element = .CenterCenter,
							parent = .CenterCenter,
						},
					},
					layout = img_layout,
					backgroundColor = front_color_dark,
					image = {
						imageData = next_img_tex
					},
					aspectRatio = {f32(next_img_tex.w) / f32(next_img_tex.h), .Fill},
				}) { }
				if clay.UI(clay.ID("BlendIn"))({
					floating = {
						attachTo = .Parent,
						attachment = {
							element = .CenterCenter,
							parent = .CenterCenter,
						},
					},
					layout = img_layout,
					backgroundColor = front_color,
					image = {
						imageData = next_img_tex
					},
					aspectRatio = {f32(next_img_tex.w) / f32(next_img_tex.h), .Fit},
				}) { }


		}


        if clay.UI(clay.ID("ToolBar"))(DPI({
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
        })) {

			section_style := DPI(clay.ElementDeclaration {
				layout = {
					layoutDirection = .TopToBottom,
					padding = {4, 4, 4, 4},
					childAlignment = {.Center, .Top}
				},
				cornerRadius = {20, 20, 20, 20},
				backgroundColor = color_frame,
			})

			subsection_style := DPI({
				layout = {
					layoutDirection = .LeftToRight,
					childGap = 4,
				},
			})


			if clay.UI(clay.ID("ToolBarSection"))(section_style) {
				clay.Text(
                    "Gallery Config",
                    text_config,
                )

				if clay.UI()(subsection_style){
					sidebar_item_component("Select Folder", proc(c: rawptr) {
						select_directory()
					})
					sidebar_item_component("Config Online Src")
				}
			}

			if clay.UI(clay.ID("ToolBarSection2"))(section_style) {
				clay.Text(
                    "Slideshow",
                    text_config,
                )
				if clay.UI()(subsection_style){
					sidebar_item_component("First", proc(c: rawptr) { playback_first()})
					sidebar_item_component("Previous", proc(c: rawptr) { playback_previous()})
					sidebar_item_component("Play\nPause", proc(c: rawptr) { playback_playpause()})
					sidebar_item_component("Next", proc(c: rawptr) { playback_next()})
					sidebar_item_component("Last", proc(c: rawptr) { playback_last()})
				}
			}

        }
    }

    // Returns a list of render commands
	result := clay.EndLayout()
	return result
}

text_config: ^clay.TextElementConfig



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
	ctx: runtime.Context,
	data: rawptr,
}

HandleButton :: proc "c" (id: clay.ElementId, pointerData: clay.PointerData, userData: rawptr) {
	if (pointerData.state == .PressedThisFrame) {

		handler_data := (^HandlerInfo)(userData)
		context = handler_data.ctx
		if handler_data.handler != nil {
			handler_data.handler(handler_data.data)
		}
	}
}

color_idle := clay.Color {0.0, 0.0, 0.0, 1}
color_border := clay.Color {1, 1, 1, 0.3}
color_frame := clay.Color {0.2, 0.2, 0.2, 1}
//color_frame := clay.Color {1, 1, 1, 1}
color_hover := clay.Color {0.4, 0.4, 0.4, 1}
color_text := clay.Color {0.8, 0.8, 0.8, 1}

// Re-useable components are just normal procs.
sidebar_item_component :: proc($label: string, callback: ButtonHandlerType = nil, user_data: rawptr = nil) {
    sidebar_item_layout := clay.LayoutConfig {
        sizing = {
            width = clay.SizingFixed(64),
            height = clay.SizingFixed(64),
        },
		childAlignment = {.Center, .Center}
    }

	if clay.UI(clay.ID(label))(DPI({
        layout = sidebar_item_layout,
		cornerRadius = {16, 16, 16, 16},
        backgroundColor = clay.Hovered() ? color_hover : color_idle,
		border = {
			width = {1, 1, 1, 1, 0},
		 	color = color_border,
		},
    })) {

		if callback != nil {
			info := new(HandlerInfo, context.temp_allocator)
			info.handler = callback
			info.ctx = context
			info.data = user_data
			clay.OnHover(HandleButton, info)
		}
		clay.Text(
            label,
            text_config,
        )
	}
}


