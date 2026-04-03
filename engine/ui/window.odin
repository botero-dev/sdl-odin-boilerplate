package ui

import "core:strings"

import SDL "vendor:sdl3"
import TTF "vendor:sdl3/ttf"

import ab ".."

create_window :: proc(name: string, size: [2]i32) -> bool {

	success := SDL.Init({.VIDEO})
    if ! success { return false }

	success = TTF.Init()
    if ! success { return false }

    name_cstring := strings.clone_to_cstring(name, context.temp_allocator)
	renderer: ^SDL.Renderer
	window: ^SDL.Window

	success = SDL.CreateWindowAndRenderer(
		name_cstring,
		size.x,
		size.y,
		{.RESIZABLE, .HIGH_PIXEL_DENSITY},
		&window,
		&renderer,
	)
    if ! success { return false }

   	ab.ui_init()
	ab.gfx_init(renderer, window)
	
    return success;
}