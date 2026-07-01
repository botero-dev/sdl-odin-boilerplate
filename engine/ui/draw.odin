package ui

import SDL "vendor:sdl3"

import "../gfx"
import "../math"

draw_box_styled :: proc(rect: math.Rect, style: BoxStyleColored ) {

    corner_radii := border_apply_arr({}, style.corner_radii, 4)
    border_width := border_apply_arr({}, style.border_width, 4)

    gfx.draw_box_filled(rect, corner_radii, style.background)
    gfx.draw_box_border(rect, corner_radii, border_width, style.border_color)
}


