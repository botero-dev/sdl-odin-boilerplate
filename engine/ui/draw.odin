package ui

import SDL "vendor:sdl3"

import "../gfx"
import "../math"

draw_box_styled :: proc(rect: math.Rect, style: BoxStyleColored ) {

    gfx.draw_box_filled(rect, style.corner_radii, style.background)
    gfx.draw_box_border(rect, style.corner_radii, style.border_width, style.border_color)
}


