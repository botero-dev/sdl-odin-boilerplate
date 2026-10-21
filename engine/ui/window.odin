package ui

import "core:strings"
import "core:log"

import SDL "vendor:sdl3"

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
    sdl_window: ^SDL.Window,
    size: [2]i32, // this is in pixels
    dpi: f32,
}

Window_ID :: distinct int

WINDOW_INVALID :: Window_ID(-1)

next_win_id: Window_ID = 0
windows: map[Window_ID]Window

// size is assumed to be pixels for now
window_create :: proc(
    title: Maybe(string) = nil,
    size: Maybe([2]i32) = nil,
    dpi: Maybe(f32) = nil
) -> Window_ID {

    window := Window{}
    window.size = size.? or_else {1280, 720}
    window.dpi = dpi.? or_else 1
    
    title_cstring: cstring = nil // not stored as pointer may get invalid
    if title != nil {
        title_cstring = strings.clone_to_cstring(title.?, context.temp_allocator)
    }

    window.sdl_window = SDL.CreateWindow(
        title_cstring,
        window.size.x, window.size.y, 
    	{.RESIZABLE, .HIGH_PIXEL_DENSITY},
    )

    if window.sdl_window == nil {
        log.error(SDL.GetError())
        return WINDOW_INVALID
    }
    
    window_id := next_win_id
    next_win_id += 1

    windows[window_id] = window

    return window_id
}