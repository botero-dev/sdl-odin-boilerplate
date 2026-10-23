
package engine

import SDL "vendor:sdl3"


import "core:log"

import "gfx"
import "ui"


draw_present :: proc() {

	ui.debugger_draw()

	if len(gfx.draw_state_stack) != 0 {
		log.warn("Draw State Stack should be empty when presenting.")
	}

	last_error := SDL.GetError()
	if last_error != nil {
		data := ([^]byte) ( rawptr(last_error))
		if data[0] != 0 {
			log.error(last_error)
		}
		
	}

	for surface_id, surface in ui.surfaces {
		SDL.RenderPresent(surface.sdl_renderer)
	}
	
}


