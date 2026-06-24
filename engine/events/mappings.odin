package events
import SDL "vendor:sdl3"

MappingIndex :: u32

EventMapping :: struct {
	type: EventType,
	data: EventMappingKeyboard,
}

EventMappingKeyboard :: struct {
	scancode: SDL.Scancode,
}


action_map: [dynamic]EventMapping

EventHandler :: #type proc(event: ^Event)



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

