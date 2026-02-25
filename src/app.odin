
package main

import SDL "vendor:sdl3"

import "core:fmt"
import "core:c"
import "core:strings"
import "core:log"

import "base:runtime"

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
	Keyboard,
	Mouse,
	Gamepad,
}

EventMapping :: struct {
	type: EventType,
	data: EventMappingKeyboard,
}

EventMappingKeyboard :: struct {
	scancode: SDL.Scancode,
}

Event :: struct {
	type: EventType,
	handled: bool,
	sdl_event: ^SDL.Event,
}



action_map: [dynamic]EventMapping

EventHandler :: #type proc(event: ^Event)

event_handler_stack: [dynamic]EventHandler



create_keyboard_mapping :: proc (scancode: SDL.Scancode) -> MappingIndex {
	new_mapping := EventMapping {
		type = .Keyboard,
		data = {scancode}
	}
	index := u32(len(action_map))
	append(&action_map, new_mapping)
	return index
}


match_mapping_button_ptr :: proc (event: ^Event, mapping_idx: u32) -> (state: bool, matches: bool) {
	return match_mapping_button_val(event^, mapping_idx)
}

match_mapping_button_val :: proc (event: Event, mapping_idx: u32) -> (state: bool, matches: bool) {
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

app_event_init :: proc() {
	//add_handler(global_handler)
	ui_init()
}

app_add_event_handler :: proc(in_handler: EventHandler) {
	append(&event_handler_stack, in_handler)
}


system_handler :: proc(evt: ^Event) {

	event := evt.sdl_event
	ignored := false
	#partial switch event.type {

	case .QUIT:
		app_quit()
	case .WINDOW_RESIZED:
		logical_win_size := []i32{event.window.data1, event.window.data2}
		log.info("window resized logical:", logical_win_size)
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
	case .WINDOW_SAFE_AREA_CHANGED:
		win_event := event.window
		win := SDL.GetWindowFromID(win_event.windowID)
		rect: SDL.Rect
		success := SDL.GetWindowSafeArea(win, &rect)
		log.info("safe area:", rect)
	case:
		ignored = true
	}

	evt.handled = !ignored
}


app_handle_event :: proc (sdl_event: ^SDL.Event) -> SDL.AppResult {
	event_retval = SDL.AppResult.CONTINUE
	SDL.ConvertEventToRenderCoordinates(renderer, sdl_event)

	event := Event{sdl_event = sdl_event}
	#partial switch sdl_event.type {
		case .KEY_DOWN:
		case .KEY_UP:
		event.type = .Keyboard
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
