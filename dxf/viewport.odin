package main

import "core:strings"
import "core:math"
import "core:math/linalg"
import "core:math/rand"


import TTF "vendor:sdl3/ttf"

import ab "engine:."
import "engine:gfx"

import "dxf"


//f64x2 :: [2]f64

ViewportState :: struct {
    // TODO: replace basis_x with span_x?
    // rationale: when panning its useful to know units/100px instead pixels for unit
    basis_x: f64x2,
    basis_y: f64x2,
    origin:  f64x2,
    data: ^Model,

    last_draw_rect: ab.Rect,
}



draw_text :: proc(text: dxf.Entity_Text, color: Color) {
    in_pos := text.pos
    content := text.content
    entity := text.entity
    pos := [3]f32{f32(in_pos.x), f32(in_pos.y), 1}
    new_pos := ab.draw_matrix * pos

    cstr := strings.clone_to_cstring(content, context.temp_allocator)


    in_fwd := [3]f32{ f32(text.end.x), f32(text.end.y), f32(text.end.z)}
    fwd := pos + (in_fwd * f32(text.height))
    pos_fwd := ab.draw_matrix * fwd

    dir_fwd := pos_fwd - new_pos
    
    screen_size := linalg.length(dir_fwd)

    font_size := u16(0)
    for step in font_steps {
        if f32(step) >= screen_size {
            font_size = step
            break
        }
        font_size = step
    }

    sdl_text := ab.get_text_with_font_size(font_id, font_size)

    dir_fwd /= f32(font_size)
    dir_up := linalg.cross(dir_fwd, [3]f32{0, 0, -1})

    if sdl_text != nil {
        
        tx : matrix[3,3]f32 = 1

        tx[0] = { f32(dir_fwd.x), f32(dir_fwd.y), 0}
        tx[1] = { f32(dir_up.x), f32(dir_up.y), 0}

        tx[2] = { f32(new_pos.x), f32(new_pos.y), 1}

        tx = linalg.transpose(tx)

        TTF.SetTextColor(
            sdl_text,
            u8(color[0] * 255),
            u8(color[1] * 255),
            u8(color[2] * 255),
            u8(color[3] * 255),
        )
        TTF.SetTextString(sdl_text, cstr, uint(len(content)))
        TTF.SetTextWrapWidth(sdl_text, 0)
        // math.round(new_pos.x), math.round(new_pos.y)
        TTF.DrawRendererTextTx(sdl_text, 0, 0, &tx[0][0])
    }
}


vp_draw :: proc(vp: ViewportState) {
	ab.draw_set_view_basis(vconv(vp.basis_x), vconv(vp.basis_y), vconv(vp.origin))

    dxf_file := vp.data.dxf

    free_all(context.temp_allocator)

    for text in dxf_file.texts {
        color := entity_style(text, dxf_file).color

        draw_text(text, color)
    }

    for text in dxf_file.mtexts {
        color := entity_style(text, dxf_file).color
        draw_text(text, color)
    }


    for circle in dxf_file.circles {
        gfx.draw_circle(
            {{f32(circle.center.x), f32(circle.center.y)}, f32(circle.radius)},
            {line = entity_style(circle, dxf_file)},
        )
    }

    for arc in dxf_file.arcs {
        /*

Entity_Arc :: struct {
	using entity: DXF_Entity,
	center: f64x3,
	radius: f64,
	extrusion: f64x3,
	angle_range: f64x2,
}
    */
        style := entity_style(arc, dxf_file)
        angle_range := arc.angle_range * math.RAD_PER_DEG
        if angle_range.y < angle_range.x {
            angle_range.y += math.TAU
        }
        start_angle := angle_range[0]
        angle_sweep := angle_range[1] - start_angle
        start_y, start_x := math.sincos(start_angle)
        delta := [2]f64{start_x, start_y} * arc.radius
        sweep_point(arc.center.xy, delta, angle_sweep, style)        
        
    }

    for line in dxf_file.lines {
        style := entity_style(line, dxf_file)
        ab.draw_line(
            ab.renderer,
            {f32(line.start.x), f32(line.start.y)},
            {f32(line.end.x), f32(line.end.y)},
            1.0,
            style.color,
        )

    }

    for polyline in dxf_file.polylines {
        style := entity_style(polyline, dxf_file)
        prev := polyline.points[0]
        bulge := polyline.bulges[0]
        for idx in 1 ..< len(polyline.points) {
            next := polyline.points[idx]
            draw_poly_segment(prev, next, bulge, style)

            prev = next
            bulge = polyline.bulges[idx]
        }
        if (polyline.flags & 1) != 0 {
            next := polyline.points[0]
            draw_poly_segment(prev, next, bulge, style)
        }

    }

    for curve in vp.data.curves_list {
        num_segments := (len(curve.points) - 1) / 3
        for idx in 0 ..< num_segments {
            a := curve.points[idx * 3 + 0]
            b := curve.points[idx * 3 + 1]
            c := curve.points[idx * 3 + 2]
            d := curve.points[idx * 3 + 3]

            prev := a
            SUBDIVS :: 20
            for s in 1 ..= SUBDIVS {
                t := f64(s) / SUBDIVS
                lab := lerp(a, b, t)
                lbc := lerp(b, c, t)
                lcd := lerp(c, d, t)
                labc := lerp(lab, lbc, t)
                lbcd := lerp(lbc, lcd, t)
                next := lerp(labc, lbcd, t)

                ab.draw_line(
                    ab.renderer,
                    {f32(prev.x), f32(prev.y)},
                    {f32(next.x), f32(next.y)},
                    1.0,
                )
                prev = next

            }
        }
    }

}


draw_poly_segment :: proc(prev: f64x2, next: f64x2, bulge: f64, style: gfx.LineStyleSimple) {
    
    if bulge == 0 {
        ab.draw_line(
            ab.renderer,
            {f32(prev.x), f32(prev.y)},
            {f32(next.x), f32(next.y)},
            1.0,
            style.color,
        )
    } else {
        dir := next - prev

        midpoint := prev + (dir * 0.5)

        b := bulge
        side := [2]f64{-dir.y, dir.x} * (1-(b*b)) / (4 * b)

        center := midpoint + side 
        angle := 4 * math.atan(bulge)

        steps := int(10) // maybe dynamic based on angle and chord?
        delta := prev - center
        rot := linalg.matrix2_rotate(angle / f64(steps))
        curr := prev

        for jdx in 0..<steps {
            delta = rot * delta
            new := center + delta
            ab.draw_line(
                ab.renderer,
                {f32(curr.x), f32(curr.y)},
                {f32(new.x), f32(new.y)},
                1.0,
                style.color,
            )   
            curr = new
        }
        
    }
}

sweep_point :: proc(center: f64x2, in_delta: f64x2, angle: f64, style: gfx.LineStyleSimple) {

    steps := int(10) // maybe dynamic based on angle and chord?
    rot := linalg.matrix2_rotate(angle / f64(steps))
    delta := in_delta 
    curr := center + delta

    for jdx in 0..<steps {
        delta = rot * delta
        new := center + delta
        ab.draw_line(
            ab.renderer,
            {f32(curr.x), f32(curr.y)},
            {f32(new.x), f32(new.y)},
            1.0,
            style.color,
        )   
        curr = new
    }

}


view_to_model :: proc(vp: ViewportState, draw_size: f64x2, in_coords: [2]f32) -> [2]f64 {

	right := vp.basis_x
	up := vp.basis_y


	draw_matrix: matrix[3, 3]f64 = 1
	offset := vp.origin
	draw_matrix = draw_matrix * matrix[3, 3]f64{
				1, 0, -offset.x,
				0, 1, -offset.y,
				0, 0, 1,
			}

	scale_mat := matrix[3, 3]f64{
		1, 0, 0,
		0, 1, 0,
		0, 0, 1,
	}

	scale_mat[0] = {right.x, right.y, 0}
	scale_mat[1] = {up.x, up.y, 0}

	draw_matrix = scale_mat * draw_matrix

	midpoint := [2]f64{f64(viewport.last_draw_rect.w), f64(viewport.last_draw_rect.h)} / 2

	center := midpoint

	draw_matrix = matrix[3, 3]f64{
			1, 0, center.x,
			0, 1, center.y,
			0, 0, 1,
		} * draw_matrix

	model_to_view := draw_matrix
	view_to_model_mat := linalg.inverse(model_to_view)

    coords := in_coords - [2]f32{viewport.last_draw_rect.x, viewport.last_draw_rect.y}
	result := view_to_model_mat * f64x3{f64(coords.x), f64(coords.y), 1}

	return {result.x, result.y}
}




Color :: [4]f32

colors := []Color {
	{1, 0, 1, 1}, // color is ByBlock, we shouldn't use this
	{1, 0, 0, 1}, // 1
	{1, 1, 0, 1}, // 2
	{0, 1, 0, 1}, // 3
	{0, 1, 1, 1}, // 4
	{0, 0, 1, 1}, // 5
	{1, 0, 1, 1}, // 6
	{1, 1, 1, 1}, // 7
}


entity_style :: proc(entity: dxf.DXF_Entity, file: dxf.DXF_Data) -> gfx.LineStyleSimple {
	color := [4]f32{1, 1, 1, 1}

	index := entity.color

	if index == 0 {
		// TODO: resolve block color, which could be bylayer
		index = rand.int_range(1, 3)
	}

	if entity.color == 256 {
		// TODO: grab from layer
		layer := file.layers[entity.layer]
		index = layer.color
	}
	if index == 0 {
		color = colors[rand.int_range(1, 7)]
	} else if index < len(colors) {
		color = colors[index]
	} else {
		color = colors[7]
	}

	return gfx.LineStyleSimple{width = 1, color = color}
}



font_id := ab.NIL_FONT
font_steps := []u16 {
	8,
	10,
	12,
	14,
	16,
	20,
	24,
	38,
	32,
	36,
	40,
	48,
	56,
	64,
	72,
	96,
}
