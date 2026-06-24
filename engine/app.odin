
package engine

import "engine:ui"
import SDL "vendor:sdl3"

import clay "clay-odin"
import evt "events"


event_retval: SDL.AppResult

app_quit :: proc() {
	event_retval = SDL.AppResult.SUCCESS
}

app_terminate :: proc() {
	event_retval = SDL.AppResult.FAILURE
}





Event :: evt.Event
MappingIndex :: evt.MappingIndex
EventHandler :: evt.EventHandler

event_handler_stack: [dynamic]EventHandler

input_fullscreen: MappingIndex
input_quit: MappingIndex
input_inspector: MappingIndex

app_event_init :: proc() {

	input_fullscreen = evt.create_keyboard_mapping(.F11)
	input_quit = evt.create_keyboard_mapping(.ESCAPE)
	input_inspector = evt.create_keyboard_mapping(.F8)

	app_add_event_handler(system_handler)
	app_add_event_handler(ui.nav_handle_input)
	app_add_event_handler(ui.ui_push_pointer_event)
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
		//ui_dirty = true

	case .WINDOW_DISPLAY_SCALE_CHANGED:
		event.handled = true
		window_event := sdl_event.window
		window := SDL.GetWindowFromID(window_event.windowID)
		dpi_window = SDL.GetWindowDisplayScale(window)
		DPI_set(dpi_user * dpi_window)
		//ui_dirty = true
	}

	if pressed, matches := evt.match_mapping_button(event, input_fullscreen); matches && pressed {
		event.handled = true
		current_fullscreen := (SDL.GetWindowFlags(window) & SDL.WINDOW_FULLSCREEN) != {}
		SDL.SetWindowFullscreen(window, !current_fullscreen)
	}

	if pressed, matches := evt.match_mapping_button(event, input_quit); matches && pressed {
		event.handled = true
		app_quit()
	}

	if pressed, matches := evt.match_mapping_button(event, input_inspector); matches && pressed {
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
	case .PINCH_BEGIN, .PINCH_UPDATE, .PINCH_END:
		event.type = .Mouse
	case .PEN_PROXIMITY_IN, .PEN_PROXIMITY_OUT, .PEN_BUTTON_UP, .PEN_BUTTON_DOWN,
		.PEN_DOWN, .PEN_UP, .PEN_MOTION, .PEN_AXIS:
		event.type = .Pen
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
