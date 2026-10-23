package ui

import "engine:gfx"
import "core:strings"
import "core:log"

import SDL "vendor:sdl3"
import TTF "vendor:sdl3/ttf"

Surface :: struct {
    sdl_window: ^SDL.Window,
    sdl_renderer: ^SDL.Renderer,
    sdl_textengine: ^TTF.TextEngine,
    size: [2]i32, // this is in pixels
    dpi: f32,
    owner_id: Window_ID,
    subwindows: [dynamic]Window_ID,
    draw_context: gfx.DrawContext,
}

Surface_ID :: distinct int
SURFACE_INVALID :: Surface_ID(-1)

sdl_video_init := false


next_surface_id: Surface_ID = 0
surfaces: map[Surface_ID]Surface

sdl_win_to_surface_id: map[^SDL.Window]Surface_ID

surface_create :: proc(
    title: Maybe(string) = nil,
    size: [2]i32,
    owner: Window_ID,
) -> Surface_ID {

    if !sdl_video_init {
        r := SDL.Init({.VIDEO})
        assert(r == true)
        sdl_video_init = true
    }

    surface := Surface{}
    surface.size = size

    title_cstring: cstring = nil // not stored as pointer may get invalid
    if title != nil {
        title_cstring = strings.clone_to_cstring(title.?, context.temp_allocator)
    }

    surface.sdl_window = SDL.CreateWindow(
        title_cstring,
        surface.size.x, surface.size.y, 
    	{.RESIZABLE, .HIGH_PIXEL_DENSITY},
    )

    if surface.sdl_window == nil {
        log.error(SDL.GetError())
        return SURFACE_INVALID
    }

    surface.dpi = SDL.GetWindowDisplayScale(surface.sdl_window)


   	surface.sdl_renderer = SDL.CreateGPURenderer(nil, surface.sdl_window)

    assert(surface.sdl_renderer != nil)

   	surface.sdl_textengine = TTF.CreateRendererTextEngine(surface.sdl_renderer)

    surface.draw_context = gfx.drawcontext_create(surface.sdl_renderer)

    surface_id := next_surface_id
    next_surface_id += 1

    surfaces[surface_id] = surface
    sdl_win_to_surface_id[surface.sdl_window] = surface_id

    return surface_id
}
