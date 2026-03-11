
package main

import "core:fmt"
import "core:log"
import "core:math"
import "core:c"
import "core:strings"

import SDL "vendor:sdl3"
import TTF "vendor:sdl3/ttf"

import clay "clay-odin"

vec2 :: [2]f32


dpi := f32(1.0)
DPI_set :: proc(new_dpi: f32) {
	dpi = new_dpi
	log.info("set dpi to:", dpi)
}

DPI_mult :: proc "contextless" (value: f32) -> f32 {
	return value * dpi
}

border_policy :: proc "contextless" (border: $T) -> u16 {
	return u16(math.round(f32(border) * dpi)) // could also be ceil or floor
}

DPI_ElementDeclaration :: proc "contextless" (decl: clay.ElementDeclaration) -> clay.ElementDeclaration {
	result := decl
	result.cornerRadius = DPI_CornerRadius(decl.cornerRadius)
	result.border.width = DPI_BorderWidth(result.border.width)
	result.layout.padding = DPI_Padding(result.layout.padding)
	result.layout.childGap = border_policy(result.layout.childGap)
	result.floating.offset.x *= dpi
	result.floating.offset.y *= dpi

	if result.layout.sizing.width.type == .Fixed {
		result.layout.sizing.width.constraints.sizeMinMax.min *= dpi
		result.layout.sizing.width.constraints.sizeMinMax.max *= dpi
	}
	if result.layout.sizing.height.type == .Fixed {
		result.layout.sizing.height.constraints.sizeMinMax.min *= dpi
		result.layout.sizing.height.constraints.sizeMinMax.max *= dpi
	}

	return result
}

DPI :: DPI_ElementDeclaration

DPI_BorderWidth :: proc "contextless" (input: clay.BorderWidth) -> clay.BorderWidth {
	return clay.BorderWidth {
		border_policy(input.left),
		border_policy(input.right),
		border_policy(input.top),
		border_policy(input.bottom),
		border_policy(input.betweenChildren),
	}
}

DPI_CornerRadius :: proc "contextless" (radii: clay.CornerRadius) -> clay.CornerRadius {
	return clay.CornerRadius {
		dpi * (radii.topLeft),
		dpi * (radii.topRight),
		dpi * (radii.bottomLeft),
		dpi * (radii.bottomRight),
	}
}

DPI_Padding :: proc "contextless" (padding: clay.Padding) -> clay.Padding {
	return clay.Padding {
		border_policy(padding.left),
		border_policy(padding.right),
		border_policy(padding.top),
		border_policy(padding.bottom),
	}
}

print_render_commands: bool




render_layout :: proc(render_commands: ^clay.ClayArray(clay.RenderCommand)) {
	for idx in 0..<i32(render_commands.length) {
        render_command := clay.RenderCommandArray_Get(render_commands, idx)

		box := transmute(Rect)render_command.boundingBox

        switch render_command.commandType {
        case .Rectangle:
			if print_render_commands {
				log.info("cmd:", idx, render_command, render_command.renderData.rectangle)
			}

            rect := render_command.renderData.rectangle
			corners := rect.cornerRadius
			if corners == {0, 0, 0, 0} {
				//fmt.println(render_command)
				color := rect.backgroundColor
				SDL.SetRenderDrawColorFloat(renderer, color[0], color[1], color[2], color[3])
				SDL.SetRenderDrawBlendMode(renderer, {.BLEND})
				rect2 := transmute(SDL.FRect)box
				SDL.RenderFillRect(renderer, &rect2)
			} else {
				corners := transmute(CornerRadii) rect.cornerRadius
				color := transmute(Color) rect.backgroundColor
				draw_box_filled(box, corners, color)
			}

		case .Border:
			if print_render_commands {
				log.info("cmd:", idx, render_command, render_command.renderData.border)
			}

			border := render_command.renderData.border
			radii := transmute(CornerRadii) border.cornerRadius
			borders := BorderWidths {
				f32(border.width.left),
				f32(border.width.right),
				f32(border.width.top),
				f32(border.width.bottom),
			}
			color := transmute(Color)border.color
			draw_box_border(box, radii, borders, color)

		case .Text:
            //fmt.println(render_command)
            text_data := render_command.renderData.text
            string_slice := text_data.stringContents
            color := transmute([4]f32) text_data.textColor
			if print_render_commands {
				str_to_draw := strings.string_from_ptr(string_slice.chars, int(string_slice.length))
				log.info("cmd:", idx, render_command, render_command.renderData.text)
				log.info("text:", str_to_draw)
			}


			text := get_text_with_font_size(text_data.fontId, text_data.fontSize)

			if text != nil {
				color *= draw_state.modulate
				TTF.SetTextColor(text, u8(color[0]*255), u8(color[1]*255), u8(color[2]*255), u8(color[3]*255))
                TTF.SetTextString(text, cstring(string_slice.chars), uint(string_slice.length))
                TTF.SetTextWrapWidth(text, 0)
                TTF.DrawRendererText(text, math.round(box.x), math.round(box.y))
            }

		case .Image:
			if print_render_commands {
				log.info("cmd:", idx, render_command, render_command.renderData.image)
			}

			image := render_command.renderData.image
            color := image.backgroundColor

			tex := (^SDL.Texture)(image.imageData)
            SDL.SetTextureColorModFloat(tex, color[0], color[1], color[2])
			SDL.SetTextureAlphaModFloat(tex, color[3])
			SDL.SetTextureBlendMode(tex, {.BLEND})

            rect2 := transmute(SDL.FRect) box
            SDL.RenderTexture(renderer, tex, nil, &rect2)

			corners := image.cornerRadius
			if corners != {0, 0, 0, 0} {
				log.info("image unhandled case!")
			}
		case .ScissorStart:
			clip_rect := SDL.Rect {i32(box.x), i32(box.y), i32(box.w), i32(box.h)}
            SDL.SetRenderClipRect(renderer, &clip_rect);
		case .ScissorEnd:
            SDL.SetRenderClipRect(renderer, nil);
		case .None:
			fmt.println("unhandled render command type: None", render_command.commandType, render_command)
		case .Custom:
			bounding_box := render_command.boundingBox

			custom_render_data: clay.CustomRenderData = render_command.renderData.custom
			background_color := custom_render_data.backgroundColor
			corner_radius := custom_render_data.cornerRadius

			custom_data := (^CustomRenderData)(custom_render_data.customData)
			custom_data.callback(custom_data, render_command)
        }
    }
}

CustomRenderCallback :: #type proc (render_data: ^CustomRenderData, render_command: ^clay.RenderCommand)

CustomRenderData :: struct {
	callback: CustomRenderCallback,
}



FontData :: struct {
	font_io: ^SDL.IOStream,
	sizes: map[u16]^TTF.Font,
}

loaded_fonts: u16 = 0 // we reserve fontid=0 for null font
fonts: [dynamic]FontData

load_font_io :: proc(io: ^SDL.IOStream) -> u16 {
	new_font := FontData {
		font_io = io
	}
	loaded_font_id := loaded_fonts
	log.info("set font io:", loaded_font_id)
	append(&fonts, new_font)
	loaded_fonts += 1
	return loaded_font_id
}

// TextElementConfig :: struct {
// 	userData:           rawptr,
// 	textColor:          Color,
// 	fontId:             u16,
// 	fontSize:           u16,
// 	letterSpacing:      u16,
// 	lineHeight:         u16,
// 	wrapMode:           TextWrapMode,
// 	textAlignment:      TextAlignment,
// }

// StringSlice :: struct {
// 	length: c.int32_t,
// 	chars:  [^]c.char,
// 	baseChars:  [^]c.char,
// }


clay_measure_text :: proc "c" (
    text: clay.StringSlice,
    config: ^clay.TextElementConfig,
    userData: rawptr,
) -> clay.Dimensions {
	context = ctx
	font := get_font_with_size(config.fontId, config.fontSize)
	if font == nil {
		log.info("unable to calculate font size")
		return {}
	}
	size := [2]c.int{}
	success := TTF.GetStringSize(font, cstring(text.chars), uint(text.length), &size.x, &size.y)
    return {
        width = f32(size.x),
        height = f32(size.y),
    }
}

NIL_FONT :: ~u16(0)

get_font_with_size :: proc(font_id: u16, size: u16) -> ^TTF.Font {
	if font_id == NIL_FONT {
		return nil
	}
	if int(font_id) >= len(fonts) {
		log.info("invalid font id, for null font use NIL_FONT")
		return nil
	}
	font := &fonts[font_id]
	font_size, ok := font.sizes[size]
	if !ok {
		font_size = TTF.OpenFontIO(font.font_io, false, f32(size))
		font.sizes[size] = font_size
	}
	return font_size
}


// single text object gets reused
single_text: ^TTF.Text

get_text_with_font_size :: proc(font_id: u16, size: u16) -> ^TTF.Text {
	//log.info("get_text_with_size")
	font := get_font_with_size(font_id, size)
	if font == nil {
		return nil
	}
	if single_text == nil {
		single_text = TTF.CreateText(engine, font, "My Text", 0)
	}
	TTF.SetTextFont(single_text, font)
	return single_text
}

nav_left: MappingIndex
nav_right: MappingIndex
nav_up: MappingIndex
nav_down: MappingIndex

// tab and shift-tab
nav_next: MappingIndex
nav_previous: MappingIndex

// select may be spacebar, where in a list may toggle mark, where enter key
// could be confirm selection
nav_select: MappingIndex
nav_confirm: MappingIndex
nav_cancel: MappingIndex


ui_init :: proc() {
	nav_left = create_keyboard_mapping(.LEFT)
	nav_right = create_keyboard_mapping(.RIGHT)
	nav_up = create_keyboard_mapping(.UP)
	nav_down = create_keyboard_mapping(.DOWN)

	nav_next = create_keyboard_mapping(.TAB)
	nav_previous = create_keyboard_mapping(.TAB) // TODO: use shift+tab

	nav_select = create_keyboard_mapping(.SPACE)
	nav_confirm = create_keyboard_mapping(.RETURN)
	nav_cancel = create_keyboard_mapping(.ESCAPE)


	min_size := clay.MinMemorySize()
    clay_memory = make([]byte, min_size)
    clay_arena := clay.CreateArenaWithCapacityAndMemory(uint(min_size), &clay_memory[0])
    clay.Initialize(clay_arena, {f32(win_size.x), f32(win_size.y)}, { handler = clay_error_handler })
    clay.SetMeasureTextFunction(clay_measure_text, nil)

}


NavigationDirection :: enum {
	Horizontal, // left/right
	Vertical, // up/down
	Logical, // previous/next
	User, // L1/R1 or some user bindings
}


NavigationItem :: struct {
	label: string,
	handler: PointerHandler,
	user_data: rawptr,
	scope: ^NavigationScope,
	owner: NavItemHandle
}

NavigationScope :: struct {
	direction: NavigationDirection,
	reverse: bool, // why would you?
	wrap: bool,
	contents: [dynamic]NavItemHandle,
	current: u32, // index of contents array
}


navigation_scope_stack: [dynamic]^NavigationScope

navigation_scope: ^NavigationScope
nav_scope_handle: NavItemHandle

root_item: NavItemHandle
nav_item_buffer: [dynamic]NavigationItem

NavItemHandle :: u32


ButtonHandlerSimple :: #type proc()
ButtonHandlerType :: #type proc(userdata: ^HandlerInfo)

HandlerInfo :: struct {
	handler: ButtonHandlerType,
}

HandlerInfoSimple :: struct {
	using generic: HandlerInfo,
	target: ButtonHandlerSimple,
}

ui_add_button :: proc(label: string, info: ^HandlerInfo = nil) -> NavItemHandle {
	ui_pointer_handler(ui_button_handler, info)
	item_handle := nav_add_item(label, ui_button_handler, info)
	return item_handle
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
			handler_data.handler(handler_data)
		}
		event.handled = true
	}
}



nav_add_item :: proc(label: string, handler: PointerHandler = nil, user_data: rawptr = nil) -> NavItemHandle {
	id := NavItemHandle(len(nav_item_buffer))
	nav_item := NavigationItem {
		label, handler, user_data, nil, nav_scope_handle,
	}
	append(&nav_item_buffer, nav_item)
	if navigation_scope != nil {
		append(&navigation_scope.contents, id)
		//log.info("appending", id)
	}

	return id
}

// two ways of doing it:
//   - look from the root and follow focus until we reach this child
//   - start from the child and look upwards until we find the parent that isn't focusing us
// we do it with approach 2
nav_get_focused :: proc(in_item_handle: NavItemHandle) -> bool {
	item_handle := in_item_handle
	focused_item := true
	for item_handle != root_item {
		item := nav_item_buffer[item_handle]
		owner := nav_item_buffer[item.owner]
		owner_scope := owner.scope
		if owner_scope.current >= u32(len(owner_scope.contents)) {
			focused_item = false
			break
		}
		if owner_scope.contents[owner_scope.current] != item_handle {
			focused_item = false
			break
		}
		item_handle = item.owner
	}
	return focused_item
}

nav_push_scope :: proc(in_scope: ^NavigationScope, handler: PointerHandler = nil, user_data: rawptr = nil) {
	prev_scope := navigation_scope
	if prev_scope == nil {
		clear(&nav_item_buffer)
	}

	item_handle := nav_add_item("scope", handler, user_data)
	nav_scope_handle = item_handle

	item := &nav_item_buffer[item_handle]
	item.scope = in_scope

	if prev_scope == nil {
		root_item = item_handle
	}

	append(&navigation_scope_stack, navigation_scope)
	navigation_scope = in_scope
}

nav_pop_scope :: proc() {
	navigation_scope = pop(&navigation_scope_stack)
}

nav_finish :: proc() {
	assert(len(navigation_scope_stack) == 0)
	assert(navigation_scope == nil)
}

@(deferred_none = nav_pop_scope)
nav_scope :: proc(in_scope: ^NavigationScope, handler: PointerHandler = nil, user_data: ^HandlerInfo = nil) {
	nav_push_scope(in_scope, handler, user_data)
}


focus_stack: [dynamic]NavItemHandle

_calc_focus_stack :: proc() {
	nav_target_id := root_item
	clear(&focus_stack)
	append(&focus_stack, nav_target_id)

	nav_target := nav_item_buffer[nav_target_id]
	for nav_target.scope != nil {
		target_scope := nav_target.scope
		num_items := len(target_scope.contents)
		if num_items == 0 {
			break
		}
		if target_scope.current >= u32(num_items) {
			// should we "fix" the index?
			break
		}
		nav_target_id = target_scope.contents[target_scope.current]
		nav_target = nav_item_buffer[nav_target_id]
		append(&focus_stack, nav_target_id)
	}
}

nav_handle_input :: proc(event: ^Event) {

	if event.type == .Unknown {
		return
	}
	if event.type == .Mouse {
		return // maybe not entirely correct? if we use mouse buttons for navigation
	}

	nav_target_id := root_item
	if nav_target_id >= u32(len(nav_item_buffer)) {
		log.info("invalid target for input handling")
		return
	}

	_calc_focus_stack()

	event.phase = .Capturing
	for item_idx in focus_stack {
		item := nav_item_buffer[item_idx]
		if item.handler != nil {
			item.handler(event, item.user_data)
			if event.handled {
				break
			}
		}
	}
	if event.handled {
		return
	}
	event.phase = .Bubbling
	#reverse for item_idx in focus_stack {
		item := &nav_item_buffer[item_idx]
		if item.handler != nil {
			item.handler(event, item.user_data)
			if event.handled {
				break
			}
		}

		scope := item.scope
		if scope != nil {
			positive_binding: MappingIndex = 0
			negative_binding: MappingIndex = 0

			switch scope.direction {
			case .Horizontal:
				positive_binding = nav_right
				negative_binding = nav_left
			case .Vertical:
				positive_binding = nav_down
				negative_binding = nav_up
			case .Logical:
				positive_binding = nav_next
				negative_binding = nav_previous
			case .User:
				log.warn("unhandled navigation direction")
			}

			delta: i32 = 0
			pressed, matches: bool
			pressed, matches = match_mapping_button(event, negative_binding)
			if matches && pressed {
				delta -= 1
			}
			pressed, matches = match_mapping_button(event, positive_binding)
			if matches && pressed {
				delta += 1
			}

			if delta != 0 {
				num_items := i32(len(scope.contents))
				new_focused := i32(scope.current) + delta
				if new_focused < 0 {
					if scope.wrap {
						new_focused = num_items - 1
					} else {
						new_focused = 0
					}
				} else if new_focused >= num_items {
					if scope.wrap {
						new_focused = 0
					} else {
						new_focused = num_items - 1
					}
				}
				will_navigate := (scope.current != u32(new_focused))
				if will_navigate {
					scope.current = u32(new_focused)
					event.handled = true
				}
			}
		}
		if event.handled {
			break
		}

	}
}

PointerEvent :: struct {
	using event: Event,
	current: clay.ElementId,
	target: clay.ElementId,
}


PointerHandler :: #type proc(event: ^Event, user_data: rawptr)


PointerHandlerEntry :: struct {
	user_data: rawptr,
	parent_idx: i32,
	handler: PointerHandler,
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
		user_data = user_data,
		parent_idx = current_handler,
		handler = handler,
	}

	handler_idx := i32(len(pointer_handler_buffer))
	append(&pointer_handler_buffer, handler_frame)

	append(&pointer_handler_stack, current_handler)
	current_handler = handler_idx

	entry_handle := rawptr(uintptr(handler_idx))
	clay.OnHover(layout_handle_mouse_input, entry_handle)
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

receiver: i32 = 0

layout_handle_mouse_input :: proc "c" (id: clay.ElementId, pointerData: clay.PointerData, userData: rawptr) {
	receiver = i32(uintptr(userData))
}

current_pointer_handler_stack: [dynamic]i32

finish_handling_mouse_input :: proc(event: ^Event) {
	if receiver == 0 {
		return
	}
	clear(&current_pointer_handler_stack)

	append(&current_pointer_handler_stack, receiver)

	pointer_handler := pointer_handler_buffer[receiver]
	for pointer_handler.parent_idx != 0 {
		append(&current_pointer_handler_stack, pointer_handler.parent_idx)
		pointer_handler = pointer_handler_buffer[pointer_handler.parent_idx]
	}


	event.phase = .Capturing
	#reverse for index in current_pointer_handler_stack {
		handler := pointer_handler_buffer[index]
		if handler.handler != nil {
			handler.handler(event, handler.user_data)
			if event.handled {
				break
			}
		}
	}
	event.phase = .Bubbling
	for index in current_pointer_handler_stack {
		handler := pointer_handler_buffer[index]
		if handler.handler != nil {
			handler.handler(event, handler.user_data)
			if event.handled {
				break
			}
		}
	}
}

wheel_delta: [2]f32

ui_push_pointer_event :: proc(event: ^Event)  {

	sdl_event := event.sdl_event

	if event.type != .Mouse {
		return
	}
	coords := vec2 {}
	receiver = 0
	#partial switch sdl_event.type {
	case .MOUSE_MOTION:
		motion := sdl_event.motion
		coords = {motion.x, motion.y}
	case .MOUSE_BUTTON_DOWN:
		button_event := sdl_event.button
		coords = {button_event.x, button_event.y}
	case .MOUSE_BUTTON_UP:
		button_event := sdl_event.button
		coords = {button_event.x, button_event.y}
	case .MOUSE_WHEEL:
		wheel_data := sdl_event.wheel
		wheel_delta += {wheel_data.x, wheel_data.y}
		coords = {wheel_data.mouse_x, wheel_data.mouse_y}
	}
	clay.SetPointerState({coords.x, coords.y}, false)

	finish_handling_mouse_input(event)

}


ui_idle :: proc(dt: f64) {
	update_scroll(f32(dt))
}

update_scroll :: proc(dt: f32) {
	clay.UpdateScrollContainers(false, {wheel_delta.x, wheel_delta.y}, dt)
	wheel_delta = {}
}

UIModifier :: struct {
	using custom_render_data: CustomRenderData,
	pushed: bool,
	wrap: bool,
	// wrap modifiers are added as parents of modified elements
	// while nowrap are added as siblings
}

UIModifierModulate :: struct {
	using base: UIModifier,
	color: [4]f32,
}

ui_modifier_modulate :: proc(color: [4]f32) -> UIModifierModulate {
	return {
		callback = ui_modifier_modulate_callback,
		wrap = false,
		color = color,
	}
}

ui_modifier_modulate_callback :: proc (render_data: ^CustomRenderData, render_command: ^clay.RenderCommand) {
	modulate := (^UIModifierModulate)(render_data)
	if !modulate.pushed {
		draw_push_state()
		draw_state.modulate *= modulate.color
		modulate.pushed = true
	} else {
		draw_pop_state()
		modulate.pushed = false
	}
}

UIModifierTransform :: struct {
	using base: UIModifier,
	mat: matrix[3,3]f32,
	pivot: vec2
}
ui_modifier_transform :: proc "contextless" (in_mat: matrix[3,3]f32, in_pivot: vec2) -> UIModifierTransform {
	return {
		callback = ui_modifier_transform_callback,
		wrap = true,
		mat = in_mat,
		pivot = in_pivot,
	}
}
ui_modifier_transform_callback :: proc (render_data: ^CustomRenderData, render_command: ^clay.RenderCommand) {
	modifier := (^UIModifierTransform)(render_data)
	if !modifier.pushed {
		draw_push_state()

		box := transmute(Rect)render_command.boundingBox

		mat: matrix[3,3]f32 = 1
		pivot_abs := [3]f32 {
			box.x + (box.w * modifier.pivot.x),
			box.y + (box.h * modifier.pivot.y),
			0,
		}

		pivot_mat: matrix[3,3]f32 = 1
		pivot_mat[2] = -pivot_abs
		pivot_mat[2][2] = 1

		mat *= pivot_mat
		mat = modifier.mat * mat

		pivot_mat[2] = pivot_abs
		pivot_mat[2][2] = 1

		mat = pivot_mat * mat

		draw_set_matrix( mat)

		modifier.pushed = true
	} else {
		draw_pop_state()
		modifier.pushed = false
	}
}

// maybe wraps draw calls that happen inside push/pop into a custom RT and then
// draws the RT to the screen
UIModifierFlatten :: struct {}


current_modifier: ^UIModifier

ui_modifier_push :: proc(modifier: ^UIModifier) {
	if modifier.wrap {
		// only open
		clay._OpenElement()
		clay.ConfigureOpenElement({
			custom = { modifier }
		})

	} else {
		// open and close
		clay.UI()({
			custom = { modifier }
		})
	}
}

ui_modifier_pop :: proc(modifier: ^UIModifier) {
	if modifier.wrap {
		clay._CloseElement()
	}
	clay.UI()({
		custom = { modifier }
	})
}

@(deferred_in=ui_modifier_pop)
ui_modifier :: proc(modifier: ^UIModifier) {
	ui_modifier_push(modifier)
}
