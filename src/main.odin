
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

import "base:runtime"


import clay "clay-odin"

ctx: runtime.Context

window: ^SDL.Window
renderer: ^SDL.Renderer
engine: ^TTF.TextEngine

clay_memory: []byte

win_size: [2]i32 = {1900, 640}


clay_error_handler :: proc "c" (errorData: clay.ErrorData) {
    context = ctx
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

	set_font_io(io)
}

sdl_app_init :: proc "c" (appstate: ^rawptr, argc: i32, argv: [^]cstring) -> SDL.AppResult {
    context = ctx
    fmt.println("hello")
    _ = SDL.SetAppMetadata("Example", "1.0", "com.example")

    if (!SDL.Init({.VIDEO, .JOYSTICK, .GAMEPAD})) {
        return .FAILURE
    }
	SDL.SetJoystickEventsEnabled(true)
	SDL.SetGamepadEventsEnabled(true)

    if !TTF.Init() {
        fmt.println("Failed to initialize TTF engine")
        return .FAILURE
    }

    if (!SDL.CreateWindowAndRenderer("examples", win_size.x, win_size.y, {.RESIZABLE}, &window, &renderer)){
        return .FAILURE
    }

    engine = TTF.CreateRendererTextEngine(renderer)


    context = ctx
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


sdl_app_quit :: proc "c" (appstate: rawptr, result: SDL.AppResult) {
	context = ctx
    fmt.println("quit")
}


sdl_app_event :: proc "c" (appstate: rawptr, event: ^SDL.Event) -> SDL.AppResult {
    context = ctx
	retval := SDL.AppResult.CONTINUE
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
	case .QUIT:
		retval = .SUCCESS
	case .WINDOW_RESIZED:
		win_size = {event.window.data1, event.window.data2}
		ui_dirty = true

	case .WINDOW_PIXEL_SIZE_CHANGED:
		win_size = {event.window.data1, event.window.data2}
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




sdl_app_iterate :: proc "c" (appstate: rawptr) -> SDL.AppResult {
    context = ctx

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


app_tick :: proc (dt: f64) {
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

		clay.SetLayoutDimensions({f32(win_size.x), f32(win_size.y)})
		free_all(context.temp_allocator)
		render_commands := create_layout()

		SDL.SetRenderTarget(renderer, nil)
		SDL.SetRenderDrawColor(renderer, 0, 0, 0, 0)
		SDL.RenderClear(renderer)

		render_layout(&render_commands)

		size := f32(64 * 32)
		target_pos := SDL.FRect {50, 50, size, size}

		start := vec2{100, 100}
		end := vec2{200, 100}
		width := f32(9)
		draw_line(renderer, start, end, width)

		SDL.RenderPresent(renderer)
	}
}


ui_dirty: bool = true


// An example function to create your layout tree
create_layout :: proc() -> clay.ClayArray(clay.RenderCommand) {
    // Begin constructing the layout.
    clay.BeginLayout()


	text_config = clay.TextConfig({
		textColor = color_text,
		fontSize = border_policy(16),
		textAlignment = .Center,
	})

    // An example of laying out a UI with a fixed-width sidebar and flexible-width main content
    // NOTE: To create a scope for child components, the Odin API uses `if` with components that have children
    if clay.UI(clay.ID("OuterContainer"))({
        layout = {
            sizing = { width = clay.SizingGrow({}), height = clay.SizingGrow({}) },
            padding = { 16, 16, 16, 16 },
            childGap = 16,
        },
		backgroundColor = {0, 0, 0, 255}
    }) {

		if len(images) > 0 {

			back_color := clay.Color{255, 255, 255, 255}
			curr_img_tex := images[current_img_idx].texture
			if clay.UI(clay.ID("Background"))({
				floating = {
					attachTo = .Parent,
					attachment = {
						element = .CenterCenter,
						parent = .CenterCenter,
					},
				},
				layout = {
					sizing = {
						width = clay.SizingPercent(1),
						height = clay.SizingPercent(1),
					},
				},
				backgroundColor = back_color,
				image = {
					imageData = curr_img_tex
				},
				aspectRatio = {f32(curr_img_tex.w) / f32(curr_img_tex.h)}
			}) {

			}

			if current_state == .Transitioning {
				next_img_idx := get_next_img_idx(current_img_idx)
				next_img_tex := images[next_img_idx].texture
				front_color := clay.Color{255, 255, 255, 255}
				progress := current_transition_time / transition_time
				alpha := f32(progress * 255)
				front_color.a = alpha
				if clay.UI(clay.ID("BlendIn"))({
					floating = {
						attachTo = .Parent,
						attachment = {
							element = .CenterCenter,
							parent = .CenterCenter,
						},
					},
					layout = {
						sizing = {
							width = clay.SizingPercent(1),
							height = clay.SizingPercent(1),
						},
					},
					backgroundColor = front_color,
					image = {
						imageData = next_img_tex
					},
					aspectRatio = {f32(next_img_tex.w) / f32(next_img_tex.h)}
				}) { }

			}
		}


        if clay.UI(clay.ID("ToolBar"))({
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
        }) {

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
    return clay.EndLayout()
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
	context = ctx
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
}
playback_previous :: proc() {
	fmt.println("previous")
}
playback_playpause :: proc() {
	fmt.println("playpause")
}
playback_next :: proc() {
	fmt.println("next")
}
dpi_index := 1
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
	new_dpi := dpi_levels[dpi_index]
	DPI_set(new_dpi)
	log.info("set dpi to:", dpi)
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

color_idle := clay.Color {0, 0, 0, 1}
color_border := clay.Color {0.3, 0.3, 0.3, 1}
color_frame := clay.Color {0.2, 0.2, 0.2, 1}
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
		cornerRadius = {20, 20, 20, 20},
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


