package ui

import SDL "vendor:sdl3"

import evt "../events"


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

ui_button_handler :: proc(event: ^PointerEvent, handler_info: rawptr) {
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


// Registers the button's navigation item and returns its handle, without
// creating a layout item yet. Use this when the handle is needed before laying
// out the button (e.g. to push a layout modifier driven by navigation focus),
// then create the item with layout_button_begin_registered.
layout_button_nav :: proc(text: string, info: ^HandlerInfo = nil) -> NavItemHandle {
	return nav_add_item(text, ui_button_handler, info)
}

// Creates the button's layout item, registers it for pointer and navigation
// input, and opens its styled box. Complete it with layout_button_end, or with
// layout_text + layout_close if something needs to be laid out inside the box.
layout_button_begin :: proc(text: string, info: ^HandlerInfo = nil, variant: ^StyleClass = nil) -> NavItemHandle {
	return _layout_button_open(text, info, variant, nil, true)
}

// Creates the button's layout item for a navigation item previously registered
// with layout_button_nav.
layout_button_begin_registered :: proc(text: string, info: ^HandlerInfo, nav_item: NavItemHandle, variant: ^StyleClass = nil) -> NavItemHandle {
	return _layout_button_open(text, info, variant, nav_item, false)
}

layout_button_end :: proc(text: string) {
	layout_text(text)
	layout_close() // box
}

_layout_button_open :: proc(text: string, info: ^HandlerInfo, variant: ^StyleClass, nav_item: Maybe(NavItemHandle), register: bool) -> NavItemHandle {
	style_class := variant
	if style_class == nil {
		style_class = &class_btn
	}
	btn_style := get_current_style(style_class, ButtonStyle)

	_layout_create(Layout_Extend{}, )

	item_handle: NavItemHandle
	if registered, ok := nav_item.?; ok {
		ui_pointer_handler(ui_button_handler, info)
		item_handle = registered
	} else if register {
		item_handle = ui_add_button(text, info)
	}

	_layout_open_styled(text, btn_style)

	return item_handle
}

layout_button_handler :: proc(text: string, info: ^HandlerInfo = nil, variant: ^StyleClass = nil) {
	_layout_button_open(text, info, variant, nil, info != nil)
	layout_button_end(text)
}


HandlerInfoGenericHeader :: struct {
	type: typeid,
}

HandlerInfoGeneric :: struct($T: typeid) {
	using base: HandlerInfo,
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

layout_button_full :: proc(text: string, user_data: $T, callback: #type proc(T) , variant: ^StyleClass = nil) {

	info := new(HandlerInfoGeneric(T), context.temp_allocator)
	info.handler = create_proc_generic(T)
	info.callback = callback
	info.user_data = user_data

	layout_button_handler(text, info, variant)
}
