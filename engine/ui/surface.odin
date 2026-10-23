package ui

import "engine:gfx"
import "core:c"
import "core:strings"
import "core:log"

import SDL "vendor:sdl3"
import TTF "vendor:sdl3/ttf"

Surface :: struct {
    sdl_window: ^SDL.Window,
    sdl_renderer: ^SDL.Renderer,
    sdl_textengine: ^TTF.TextEngine,
    pixel_size: [2]i32, // physical pixels
    dpi: f32,
    owner_id: Window_ID,
    subwindows: [dynamic]Window_ID,
    draw_context: gfx.DrawContext,
}

Surface_ID :: distinct int
SURFACE_INVALID :: Surface_ID(-1)

sdl_video_driver := ""

next_surface_id: Surface_ID = 0
surfaces: map[Surface_ID]Surface

sdl_win_to_surface_id: map[^SDL.Window]Surface_ID


// logical_size is in window coordinates (logical pixels). The created
// surface's size is its drawable size in physical pixels.
surface_create :: proc(
    title: Maybe(string) = nil,
    logical_size: [2]f32,
    owner: Window_ID,
) -> Surface_ID {

    if sdl_video_driver == "" {
        r := SDL.Init({.VIDEO})
        assert(r == true)
        sdl_video_driver = string(SDL.GetCurrentVideoDriver())
    }

    // on x11 or windows, we need to ask for physical pixels, in other backends we pass logical pixels
    scale := f32(1)
    switch sdl_video_driver {
    case "x11", "windows":
        display := SDL.GetPrimaryDisplay()
        if display != 0 {
            content_scale := SDL.GetDisplayContentScale(display)
            if content_scale > 0 {
                scale = content_scale
            }
        }
    }

    creation_size := scaling_logical_to_pixels(logical_size, scale)

    title_cstring: cstring = nil
    if title != nil {
        title_cstring = strings.clone_to_cstring(title.?, context.temp_allocator)
    }

    sdl_window := SDL.CreateWindow(
        title_cstring,
        creation_size.x, creation_size.y,
    	{.RESIZABLE, .HIGH_PIXEL_DENSITY},
    )

    if sdl_window == nil {
        log.error(SDL.GetError())
        return SURFACE_INVALID
    }

    surface := Surface{}
    surface.owner_id = owner
    surface.sdl_window = sdl_window

    surface.dpi = SDL.GetWindowDisplayScale(surface.sdl_window)
    if surface.dpi == 0 {
        surface.dpi = 1
    }

   	surface.sdl_renderer = SDL.CreateGPURenderer(nil, surface.sdl_window)

    assert(surface.sdl_renderer != nil)

    pixel_width, pixel_height: c.int
    success := SDL.GetWindowSizeInPixels(surface.sdl_window, &pixel_width, &pixel_height)
    assert(success)
    surface.pixel_size = {i32(pixel_width), i32(pixel_height)}

   	surface.sdl_textengine = TTF.CreateRendererTextEngine(surface.sdl_renderer)

    surface.draw_context = gfx.drawcontext_create(surface.sdl_renderer)

    surface_id := next_surface_id
    next_surface_id += 1

    surfaces[surface_id] = surface
    sdl_win_to_surface_id[surface.sdl_window] = surface_id

    return surface_id
}

surface_update_from_window :: proc(sdl_window: ^SDL.Window) {
    surface_id, ok := sdl_win_to_surface_id[sdl_window]
    if !ok {
        return
    }

    surface := &surfaces[surface_id]
    surface.dpi = SDL.GetWindowDisplayScale(sdl_window)
    if surface.dpi == 0 {
        surface.dpi = 1
    }

    pixel_width, pixel_height: c.int
    if SDL.GetWindowSizeInPixels(sdl_window, &pixel_width, &pixel_height) {
        surface.pixel_size = {i32(pixel_width), i32(pixel_height)}
    }

    window := &windows[surface.owner_id]
    window.logical_size = scaling_pixels_to_logical(surface.pixel_size, surface.dpi)
}

