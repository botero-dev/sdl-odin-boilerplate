package ui

import SDL "vendor:sdl3"

import evt "../events"
import clay "../clay-odin"


ButtonHandlerSimple :: #type proc()
ButtonHandlerType :: #type proc(userdata: ^HandlerInfo)

HandlerInfo :: struct {
	handler: ButtonHandlerType,
}

HandlerInfoSimple :: struct {
	using base: HandlerInfo,
	callback:     ButtonHandlerSimple,
}

ui_add_button :: proc(label: string, info: ^HandlerInfo = nil) -> NavItemHandle {
	ui_pointer_handler(ui_button_handler, info)
	item_handle := nav_add_item(label, ui_button_handler, info)
	return item_handle
}

ui_button_handler :: proc(event: ^Event, handler_info: rawptr) {
	if event.phase == .Capturing {return}
	commit := false
	if event.sdl_event.type == .MOUSE_BUTTON_DOWN {
		button_event := event.sdl_event.button
		if button_event.button == SDL.BUTTON_LEFT {
			commit = true
		}
	}

	pressed, matches := evt.match_mapping_button(event, nav_confirm)
	if matches && pressed {
		commit = true
	}

	if commit {
		if handler_info != nil {
			handler_data := (^HandlerInfo)(handler_info)
			handler_data.handler(handler_data)
		}
		event.handled = true
	}
}



layout_button :: proc {
	layout_button_callback,
	layout_button_handler,
	layout_button_full,
}

layout_button_callback :: proc(text: string, callback: ButtonHandlerSimple, variant: ^StyleClass = nil) {
	info: ^HandlerInfoSimple
	if callback != nil {
		info = new(HandlerInfoSimple, context.temp_allocator)
		info.handler = _handle_proc_simple
		info.callback = callback
	}
	layout_button_handler(text, info, variant)
}


_handle_proc_simple :: proc(userdata: ^HandlerInfo) {
	data_simple := (^HandlerInfoSimple)(userdata)
	data_simple.callback()
}


layout_button_handler :: proc(text: string, info: ^HandlerInfo = nil, variant: ^StyleClass = nil) {

	style_class := variant
	if style_class == nil {
		style_class = &class_btn
	}
	btn_style := get_current_style(style_class, ButtonStyle)

	
	_layout_create(Layout_Extend{}, )

	if info !=  nil {
		ui_add_button(text, info)
	}
	style: ^BoxStyle = &btn_style.idle_box
	if clay.Hovered() {
		style = &btn_style.hover_box
	}
	
	config_box_style(&clay_elem, style^)

	_layout_open_styled("", style)
	
	text_style: ^TextStyle
	text_style = &btn_style.idle_text
	
	layout_text(text)

	layout_close() // box
}


HandlerInfoGenericHeader :: struct {
	type: typeid,
}

HandlerInfoGeneric :: struct($T: typeid) {
	using base: HandlerInfo,
//	using header: HandlerInfoGenericHeader,
	callback: #type proc(userdata: T),
	user_data: T,
}


create_proc_generic :: proc($T: typeid) -> proc(^HandlerInfo) {
	_handle_proc_generic :: proc(userdata: ^HandlerInfo) {
		handler_info := (^HandlerInfoGeneric(T))(userdata)
		handler_info.callback(handler_info.user_data)
	}
	return _handle_proc_generic
}



layout_button_callback2 :: proc(text: string, callback: ButtonHandlerSimple, variant: ^StyleClass = nil) {
	info: ^HandlerInfoSimple
	if callback != nil {
		info = new(HandlerInfoSimple, context.temp_allocator)
		info.handler = _handle_proc_simple
		info.callback = callback
	}
	layout_button_handler(text, info, variant)
}


layout_button_full :: proc(text: string, user_data: $T, callback: #type proc(T) , variant: ^StyleClass = nil) {

	info := new(HandlerInfoGeneric(T), context.temp_allocator)
	info.handler = create_proc_generic(T)
	info.callback = callback
	info.user_data = user_data

	layout_button_handler(text, info, variant)
}
