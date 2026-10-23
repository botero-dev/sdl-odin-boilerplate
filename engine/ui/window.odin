package ui


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
    size: [2]i32, // this is in pixels
}

Window_ID :: distinct int
WINDOW_INVALID :: Window_ID(-1)


next_win_id: Window_ID = 0
windows: map[Window_ID]Window


// size is assumed to be pixels for now
window_create :: proc(
    title: Maybe(string) = nil,
    size: Maybe([2]i32) = nil,
    surface_id: Maybe(Surface_ID) = nil, // if not nil, a surface is created
) -> Window_ID {

    window := Window{}
    window.size = size.? or_else {1280, 720}
    
    window_id := next_win_id

    if surface_id == nil {
        window.surface_id = surface_create(title, window.size, window_id)
    } else {
        window.surface_id = surface_id.?
        surface := &surfaces[window.surface_id]
        append(&surface.subwindows, window_id)
    }

    if window.surface_id == SURFACE_INVALID {
        return WINDOW_INVALID
    }


    // commit changes
    windows[window_id] = window
    next_win_id += 1

    return window_id
}
