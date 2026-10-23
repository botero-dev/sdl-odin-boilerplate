package engine


import SDL "vendor:sdl3"

import "ui"
import "gfx"


create_window :: proc(name: string, size: [2]i32) {


	window_id := ui.window_create(name, size)

	window := ui.windows[window_id]
	surface := ui.surfaces[window.surface_id]
	renderer := surface.sdl_renderer

	assert(renderer != nil, "Failed to create SDL renderer.")

	ui.init()
	gfx.drawcontext_activate(surface.draw_context)
}

