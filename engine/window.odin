package engine

import "core:strings"

import SDL "vendor:sdl3"
import TTF "vendor:sdl3/ttf"

import "ui"


create_window :: proc(name: string, size: [2]i32) -> bool {

	success := SDL.Init({.VIDEO})
    if ! success { return false }

	success = TTF.Init()
    if ! success { return false }

    name_cstring := strings.clone_to_cstring(name, context.temp_allocator)

	window_id := ui.window_create(name, size, 1)


	window := ui.windows[window_id]
	renderer := SDL.CreateRenderer(window.sdl_window, nil)
	
	// device := SDL.CreateGPUDevice({.SPIRV})
	// renderer := SDL.CreateGPURenderer(window.sdl_window)
	
	assert(renderer != nil, "Failed to create SDL renderer.")

   	ui_init()
	gfx_init(renderer, window.sdl_window)
	
    return success;
}