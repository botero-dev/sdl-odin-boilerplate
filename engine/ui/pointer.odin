package ui

import "core:fmt"
import evt "../events"

Event :: evt.Event

PointerEvent :: struct {
	using event: ^Event,
	coords: f32x2,
}



PointerHandler :: #type proc(event: ^Event, user_data: rawptr)


PointerHandlerEntry :: struct {
	user_data:  rawptr,
	parent_idx: i32,
	handler:    PointerHandler,
}

pointer_handler_buffer: [dynamic]PointerHandlerEntry
pointer_handler_stack: [dynamic]i32

current_handler: i32

ui_reset_handler_buffer :: proc() {
	clear(&pointer_handler_buffer)
	current_handler = 0
	append(&pointer_handler_buffer, PointerHandlerEntry{}) // ensure always a handler at frame 0
}


// sometimes is called without callback in floating elements so they capture and
// bubble events to parent scope
ui_push_pointer_handler :: proc(handler: PointerHandler = nil, user_data: rawptr = nil) {

	handler_frame := PointerHandlerEntry {
		user_data  = user_data,
		parent_idx = current_handler,
		handler    = handler,
	}

	handler_idx := i32(len(pointer_handler_buffer))
	append(&pointer_handler_buffer, handler_frame)

	append(&pointer_handler_stack, current_handler)
	current_handler = handler_idx

	entry_handle := rawptr(uintptr(handler_idx))

	item_decl := &layout_state.items_decl[new_item_idx]
	item_decl.handler = handler
	item_decl.handler_data = user_data
}

ui_pop_pointer_handler :: proc() {

	current_handler = pop(&pointer_handler_stack)
}

@(deferred_none = ui_pop_pointer_handler)
ui_pointer_handler :: proc(handler: PointerHandler = nil, user_data: rawptr = nil) {
	ui_push_pointer_handler(handler, user_data)
}


// right now we require every visible item to add itself as pointer handler in
// the stack so we can walk back to the root from the hovered item, this way we
// can call mouse handlers from the outermost element to the innermost to allow
// interception, and then bubble back the event to the root.
wheel_delta: [2]f32

coords := f32x2{}
ui_push_pointer_event :: proc(event: ^Event) {

	sdl_event := event.sdl_event

	#partial switch event.type {
		case .Mouse, .Touch, .Pen:
			break;
		case:
			return
	}


	pressed: bool = false

	#partial switch sdl_event.type {
	case .MOUSE_MOTION:
		motion := sdl_event.motion
		coords = {motion.x, motion.y}
		if .LEFT in motion.state {
			pressed = true
		}
	case .MOUSE_BUTTON_DOWN:
		button_event := sdl_event.button
		coords = {button_event.x, button_event.y}
		if button_event.button == 0 {
			pressed = true
		}
	case .MOUSE_BUTTON_UP:
		button_event := sdl_event.button
		coords = {button_event.x, button_event.y}
	case .MOUSE_WHEEL:
		wheel_data := sdl_event.wheel
		wheel_delta += {wheel_data.x, wheel_data.y}
		coords = {wheel_data.mouse_x, wheel_data.mouse_y}
	
	case .PEN_MOTION:
		pen_data := sdl_event.pmotion
		coords = {pen_data.x, pen_data.y}
		//fmt.println("pen motion:", coords)
	case .PEN_DOWN:
		pen_data := sdl_event.ptouch
		coords = {pen_data.x, pen_data.y}

	case .PEN_PROXIMITY_IN:
		pen_data := sdl_event.pproximity
		//coords = {pen_data.x, pen_data.y}

	}

	pointer_event := PointerEvent{event, coords}

	layout_process_event(&pointer_event)

	debugger_process_event(&pointer_event)

	//clay.SetPointerState({coords.x, coords.y}, pressed)

	//finish_handling_mouse_input(event)

}


ui_idle :: proc(dt: f64) {
	update_scroll(f32(dt))
}

update_scroll :: proc(dt: f32) {
	//clay.UpdateScrollContainers(false, {wheel_delta.x, wheel_delta.y}, dt)
	wheel_delta = {}
}