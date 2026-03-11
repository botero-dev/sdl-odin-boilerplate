
package main

import SDL "vendor:sdl3"

import clay "clay-odin"


event_retval: SDL.AppResult

app_quit :: proc() {
	event_retval = SDL.AppResult.SUCCESS
}

app_terminate :: proc() {
	event_retval = SDL.AppResult.FAILURE
}


MappingIndex :: u32


EventType :: enum {
	Unknown,
	Keyboard,
	Mouse,
	Gamepad,
}

// Inspired on HTML
EventPhase :: enum {
	Capturing,
	Bubbling,
	// no Target event as events get always triggered.
}

EventMapping :: struct {
	type: EventType,
	data: EventMappingKeyboard,
}

EventMappingKeyboard :: struct {
	scancode: SDL.Scancode,
}

Event :: struct {
	type:      EventType,
	phase:     EventPhase,
	handled:   bool,
	sdl_event: ^SDL.Event,
}


action_map: [dynamic]EventMapping

EventHandler :: #type proc(event: ^Event)

event_handler_stack: [dynamic]EventHandler


create_keyboard_mapping :: proc(scancode: SDL.Scancode) -> MappingIndex {
	if action_map == nil {
		// create empty mapping at index 0
		append(&action_map, EventMapping{})
	}
	new_mapping := EventMapping {
		type = .Keyboard,
		data = {scancode},
	}
	index := u32(len(action_map))
	append(&action_map, new_mapping)
	return index
}


match_mapping_button_ptr :: proc(event: ^Event, mapping_idx: u32) -> (state: bool, matches: bool) {
	return match_mapping_button_val(event^, mapping_idx)
}

match_mapping_button_val :: proc(event: Event, mapping_idx: u32) -> (state: bool, matches: bool) {
	mapping := action_map[mapping_idx]
	if event.type != mapping.type {
		return false, false
	}
	if event.type == .Keyboard {
		key := event.sdl_event.key
		if key.scancode == mapping.data.scancode {
			return key.down, true
		}
	}

	return false, false
}

match_mapping_button :: proc {
	match_mapping_button_val,
	match_mapping_button_ptr,
}


input_fullscreen: MappingIndex
input_quit: MappingIndex
input_inspector: MappingIndex

app_event_init :: proc() {

	input_fullscreen = create_keyboard_mapping(.F11)
	input_quit = create_keyboard_mapping(.ESCAPE)
	input_inspector = create_keyboard_mapping(.F8)

	app_add_event_handler(system_handler)
	app_add_event_handler(nav_handle_input)
	app_add_event_handler(ui_push_pointer_event)
}

app_add_event_handler :: proc(in_handler: EventHandler) {
	append(&event_handler_stack, in_handler)
}


system_handler :: proc(event: ^Event) {

	sdl_event := event.sdl_event
	#partial switch sdl_event.type {

	case .QUIT:
		event.handled = true
		app_quit()

	case .WINDOW_PIXEL_SIZE_CHANGED:
		event.handled = true
		window_event := sdl_event.window
		win_size = {window_event.data1, window_event.data2}
		clay.SetLayoutDimensions({f32(win_size.x), f32(win_size.y)})
		ui_dirty = true

	case .WINDOW_DISPLAY_SCALE_CHANGED:
		event.handled = true
		window_event := sdl_event.window
		window := SDL.GetWindowFromID(window_event.windowID)
		dpi_window = SDL.GetWindowDisplayScale(window)
		DPI_set(dpi_user * dpi_window)
		ui_dirty = true
	}

	if pressed, matches := match_mapping_button(event, input_fullscreen); matches && pressed {
		event.handled = true
		current_fullscreen := (SDL.GetWindowFlags(window) & SDL.WINDOW_FULLSCREEN) != {}
		SDL.SetWindowFullscreen(window, !current_fullscreen)
	}

	if pressed, matches := match_mapping_button(event, input_quit); matches && pressed {
		event.handled = true
		app_quit()
	}

	if pressed, matches := match_mapping_button(event, input_inspector); matches && pressed {
		event.handled = true
		clay.SetDebugModeEnabled(true)
	}
}


app_handle_event :: proc(sdl_event: ^SDL.Event) -> SDL.AppResult {
	event_retval = SDL.AppResult.CONTINUE
	SDL.ConvertEventToRenderCoordinates(renderer, sdl_event)

	event := Event {
		sdl_event = sdl_event,
	}
	#partial switch sdl_event.type {
	case .KEY_DOWN, .KEY_UP:
		event.type = .Keyboard
	case .MOUSE_MOTION, .MOUSE_BUTTON_DOWN, .MOUSE_BUTTON_UP, .MOUSE_WHEEL:
		event.type = .Mouse
	}

	system_handler(&event)

	if event.handled {
		return event_retval
	}

	#reverse for handler in event_handler_stack {
		handler(&event)
		if event.handled {
			break
		}
	}

	return event_retval
}
