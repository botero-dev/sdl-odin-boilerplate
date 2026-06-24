package ui

import "core:log"
import evt "../events"

NavigationDirection :: enum {
	Horizontal, // left/right
	Vertical, // up/down
	Logical, // previous/next
	User, // L1/R1 or some user bindings
}


NavigationItem :: struct {
	label:     string,
	handler:   PointerHandler,
	user_data: rawptr,
	scope:     ^NavigationScope,
	owner:     NavItemHandle,
}

NavigationScope :: struct {
	direction: NavigationDirection,
	reverse:   bool, // why would you?
	wrap:      bool,
	contents:  [dynamic]NavItemHandle,
	current:   u32, // index of contents array
}

MappingIndex :: evt.MappingIndex
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

_nav_init :: proc() {
   	nav_left = evt.create_keyboard_mapping(.LEFT)
	nav_right = evt.create_keyboard_mapping(.RIGHT)
	nav_up = evt.create_keyboard_mapping(.UP)
	nav_down = evt.create_keyboard_mapping(.DOWN)

	nav_next = evt.create_keyboard_mapping(.TAB)
	nav_previous = evt.create_keyboard_mapping(.TAB) // TODO: use shift+tab

	nav_select = evt.create_keyboard_mapping(.SPACE)
	nav_confirm = evt.create_keyboard_mapping(.RETURN)
	nav_cancel = evt.create_keyboard_mapping(.ESCAPE)
}


navigation_scope_stack: [dynamic]^NavigationScope

navigation_scope: ^NavigationScope
nav_scope_handle: NavItemHandle

root_item: NavItemHandle
nav_item_buffer: [dynamic]NavigationItem

NavItemHandle :: u32



nav_add_item :: proc(
	label: string,
	handler: PointerHandler = nil,
	user_data: rawptr = nil,
) -> NavItemHandle {
	id := NavItemHandle(len(nav_item_buffer))
	nav_item := NavigationItem{label, handler, user_data, nil, nav_scope_handle}
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

nav_push_scope :: proc(
	in_scope: ^NavigationScope,
	handler: PointerHandler = nil,
	user_data: rawptr = nil,
) {
	prev_scope := navigation_scope
	if prev_scope == nil { // if it is root scope, clear nav_items buffer
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
	// clean scope contents as they will get populated again
	clear(&navigation_scope.contents)
}

nav_pop_scope :: proc() {
	navigation_scope = pop(&navigation_scope_stack)
}

nav_finish :: proc() {
	assert(len(navigation_scope_stack) == 0)
	assert(navigation_scope == nil)
}

@(deferred_none = nav_pop_scope)
nav_scope :: proc(
	in_scope: ^NavigationScope,
	handler: PointerHandler = nil,
	user_data: ^HandlerInfo = nil,
) {
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
			pressed, matches = evt.match_mapping_button(event, negative_binding)
			if matches && pressed {
				delta -= 1
			}
			pressed, matches = evt.match_mapping_button(event, positive_binding)
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