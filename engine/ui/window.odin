package ui

import "../gfx"

// a priori, a window is just a container that can render stuff. .

// a window could have children windows. the child windows can have their own
// defined bounds, they draw their own render target, and then get rendered to
// main view.

// ok, thinking a bit furhter, we can have these:

// Window: is a rect with a given size and position that draws content

// Surface: is a os-provided rectangle to draw content

// a surface could draw its main content (a window itself) but could also draw
// sub-windows in case we don't want to use multiple system surfaces (like
// mobile or web)

Window :: struct {
    surface_id: Surface_ID,
    logical_size: [2]f32, // logical pixels
}

Window_ID :: distinct int
WINDOW_INVALID :: Window_ID(-1)


next_win_id: Window_ID = 0
windows: map[Window_ID]Window


// logical_size is in logical pixels.
window_create :: proc(
    title: Maybe(string) = nil,
    logical_size: Maybe([2]f32) = nil,
    surface_id: Maybe(Surface_ID) = nil,
) -> Window_ID {

    requested_logical_size := logical_size.? or_else [2]f32{1280, 720}

    window_id := next_win_id
    result_surface_id := surface_id.? or_else surface_create(title, requested_logical_size, window_id)

    if result_surface_id == SURFACE_INVALID {
        return WINDOW_INVALID

    }

    surface := surfaces[result_surface_id]
    window := Window{}
    window.surface_id = result_surface_id

    if surface_id == nil {
        // if we were creating a new surface:
        // The OS may have given us a different size, we recalculate logical size
        window.logical_size = scaling_pixels_to_logical(surface.pixel_size, surface.dpi)
    } else { // if surface_id != nil
        // we were adding a window to a surface
        window.logical_size = requested_logical_size

        append(&surface.subwindows, window_id)
    } 

    // commit changes
    windows[window_id] = window
    next_win_id += 1

    // activate window
   	gfx.drawcontext_activate(surface.draw_context)

    return window_id
}

window_pixel_size :: proc(window_id: Window_ID) -> [2]i32 {
    window := windows[window_id]
    surface := surfaces[window.surface_id]

    if surface.owner_id == window_id {
        return surface.pixel_size
    }

    return scaling_logical_to_pixels(window.logical_size, surface.dpi)
}
