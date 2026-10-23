package engine


import SDL "vendor:sdl3"

import "ui"
import "gfx"


create_window :: proc(name: string, logical_size: [2]f32) {

	window_id := ui.window_create(name, logical_size)

	ui.init()
}

