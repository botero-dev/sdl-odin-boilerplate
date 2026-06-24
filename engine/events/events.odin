package events

import SDL "vendor:sdl3"

EventType :: enum {
	Unknown,
	Keyboard,
	Mouse, // would cover both mouse and touchpads
	Touch,
	Pen,
	Gamepad,
}

// Inspired on HTML
EventPhase :: enum {
	Capturing,
	Bubbling,
	// no Target event as events get always triggered.
}

Event :: struct {
	type:      EventType,
	phase:     EventPhase,
	handled:   bool,
	sdl_event: ^SDL.Event,
}
