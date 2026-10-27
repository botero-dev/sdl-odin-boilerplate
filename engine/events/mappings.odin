package events
import SDL "vendor:sdl3"

MappingIndex :: u32


KeyboardEventModifiers :: bit_set[KeyboardEventModifier]
KeyboardEventModifier :: enum {
	Shift,
	Control,
	Alt,
}

EventMappingKeyboard :: struct {
	scancode: SDL.Scancode,
	modifiers: KeyboardEventModifiers,
}

EventMapping :: union {
	EventMappingKeyboard,
}

action_map: [dynamic]EventMapping

EventHandler :: #type proc(event: ^Event)



create_keyboard_mapping :: proc(scancode: SDL.Scancode, modifiers: KeyboardEventModifiers = {}) -> MappingIndex {
	if action_map == nil {
		// create empty mapping at index 0
		append(&action_map, EventMapping{})
	}
	new_mapping := EventMapping(EventMappingKeyboard {
		scancode  = scancode,
		modifiers = modifiers,
	})
	index := u32(len(action_map))
	append(&action_map, new_mapping)
	return index
}


match_mapping_button_ptr :: proc(event: ^Event, mapping_idx: u32) -> (state: bool, matches: bool) {
	return match_mapping_button_val(event^, mapping_idx)
}

match_mapping_button_val :: proc(event: Event, mapping_idx: u32) -> (state: bool, matches: bool) {
	mapping := action_map[mapping_idx]
	sdl_evt_type := event.sdl_event.type
	switch m in mapping {
		case EventMappingKeyboard:

			if sdl_evt_type == .KEY_DOWN || sdl_evt_type == .KEY_UP {
				key := event.sdl_event.key
				modifiers: KeyboardEventModifiers = {}
				if .LSHIFT in key.mod || .RSHIFT in key.mod {
					modifiers += {.Shift}
				}
				if .LCTRL in key.mod || .RCTRL in key.mod {
					modifiers += {.Control}
				}
				if .LALT in key.mod || .RALT in key.mod {
					modifiers += {.Alt}
				}

				// a mapping that declares no modifiers ignores them, so plain bindings
				// keep working while modifiers are held down
				if key.scancode == m.scancode && (m.modifiers == {} || m.modifiers == modifiers) {
					return key.down, true
				}
			}
	}

	return false, false
}

match_mapping_button :: proc {
	match_mapping_button_val,
	match_mapping_button_ptr,
}

