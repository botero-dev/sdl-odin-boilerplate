package main

import "core:fmt"
import "core:log"
import "core:c"
import "core:strconv"
import "core:strings"
import "core:math"
import "core:math/linalg"
import "core:math/rand"
import "core:unicode/utf8"


import SDL "vendor:sdl3"
import TTF "vendor:sdl3/ttf"

import ab "engine:."
import "engine:gfx"
import "engine:ui"

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
    pos := [3]f32{f32(in_pos.x), f32(in_pos.y), 1}

    // dbg := f32(1)
    // gfx.draw_line(ab.renderer, pos.xy + {-dbg, 0}, pos.xy + {dbg, 0}, 1, {1, 0, 0, 1})
    // gfx.draw_line(ab.renderer, pos.xy + {0, -dbg}, pos.xy + {0, dbg}, 1, {1, 0, 0, 1})

    new_pos := ab.draw_matrix * pos

    cstr := cstring(raw_data(content))


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

    sdl_font := ui.get_font_with_size(font_id, font_size)
    if sdl_font != nil {
        wght := TTF.VARIATION("wght", 400)
        ok := TTF.SetFontVariations(sdl_font, &wght, 1)
        assert(ok == true)

        //TTF.SetFontLanguage(sdl_font, "ja") // ja, zh
    }

    sdl_text := ui.get_text_with_font_size(font_id, font_size)

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

        ypos := i32(0)
        switch text.valign {
            case .Top:
                // do nothing
            case .Middle:
                ypos -= TTF.GetFontHeight(sdl_font) / 2
            case .Baseline:
                ypos -= TTF.GetFontAscent(sdl_font)
            case .Bottom:
                ypos -= TTF.GetFontHeight(sdl_font)
        }
        w, h: i32
        font_size := TTF.GetStringSize(sdl_font, cstr, uint(len(content)),&w, &h)
        xpos := i32(0)
        #partial switch text.hjustify {
            case .Left:
                //nothing
            case .Center:
                xpos -= w / 2
            case .Right:
                xpos -= w
        }


        TTF.DrawRendererTextTx(sdl_text, f32(xpos), f32(ypos), &tx[0][0])
    }
}

MText_Command_LineBreak :: struct {
    substring: string,
}

MText_Command_DrawText :: struct {
    substring: string,
}

MText_Command_DrawFraction :: struct {
    numerator: string,
    denominator: string,
    separator: u8,
}

// {
MText_Command_PushState :: struct {}

// }
MText_Command_PopState :: struct {}

// \C{color-index};
MText_Command_SetColorIndex :: struct {
    color: int,
}
// \c{rgb-as-decimal};
MText_Command_SetColorRGB :: struct {
    color: int,
}

// \f{font}|b{bold}|i{italic}...;
MText_Command_SetFont :: struct {
    font: string,
    bold: bool,
    italic: bool,
}



MText_Command :: union #no_nil {
    MText_Command_LineBreak,
    MText_Command_DrawText,
    MText_Command_DrawFraction,
    MText_Command_PushState,
    MText_Command_PopState,
    MText_Command_SetColorIndex,
    MText_Command_SetColorRGB,
    MText_Command_SetFont,
}

MText_Parse_State :: struct {
    commands: [dynamic]MText_Command,
    buffer: string,
    cursor: int,
    substring_start: int,
}

parse_state_data: MText_Parse_State

compute_mtext_draw :: proc(text: dxf.Entity_MText) -> [dynamic]MText_Command {
    clear(&parse_state_data.commands)

    parse_state_data.cursor = 0
    parse_state_data.substring_start = 0
    parse_state_data.buffer = text.content

    parse_state := &parse_state_data

    close_current_string :: proc(parse_state: ^MText_Parse_State) {
        if parse_state.substring_start != parse_state.cursor {
            append(&parse_state.commands, MText_Command_DrawText {
                    parse_state.buffer[parse_state.substring_start:parse_state.cursor]
            })
            parse_state.substring_start = parse_state.cursor
        }
    }

    for parse_state.cursor < len(parse_state.buffer) {
        char := parse_state.buffer[parse_state.cursor]
        reset_substring := false
        if char == '{' {
            close_current_string(parse_state)
            append(&parse_state.commands, MText_Command_PushState {})
            parse_state.cursor += 1
            reset_substring = true
        } else if char == '}' {
            close_current_string(parse_state)
            append(&parse_state.commands, MText_Command_PopState {})
            parse_state.cursor += 1
            reset_substring = true
        } else if char == '\\' {
            // its good to always close current string because, even if it is a escape character, we
            // want to create a new substring from after the escape "\" token
            close_current_string(parse_state)
                
            parse_state.cursor += 1
            char = parse_state.buffer[parse_state.cursor]
            if char == 'P' { // parse color
                append(&parse_state.commands, MText_Command_LineBreak {} )
                parse_state.cursor += 1 
                reset_substring = true
            } else if char == 'C' { // parse color
                color_start := parse_state.cursor + 1
                color_end := color_start
                for parse_state.buffer[color_end] != ';' {
                    color_end += 1
                }
                color_substring := parse_state.buffer[color_start:color_end]
               	color_value, ok := strconv.parse_int(color_substring); assert(ok)
                append(&parse_state.commands, MText_Command_SetColorIndex {color_value} )
                parse_state.cursor = color_end + 1
                reset_substring = true
            } else if char == 'A' { // parse vertical alignment
                valign_start := parse_state.cursor + 1
                valign_end := valign_start
                for parse_state.buffer[valign_end] != ';' {
                    valign_end += 1
                }
                valign_substring := parse_state.buffer[valign_start:valign_end]
               	valign_value, ok := strconv.parse_int(valign_substring); assert(ok)
                //append(&parse_state.commands, MText_Command_SetvalignIndex {valign_value} )
                parse_state.cursor = valign_end + 1
                reset_substring = true
            } else if char == 'H' { // parse height scale
                hscale_start := parse_state.cursor + 1
                hscale_end := hscale_start
                for parse_state.buffer[hscale_end] != ';' {
                    hscale_end += 1
                }
                hscale_relative := false
                true_hscale_end := hscale_end
                if parse_state.buffer[hscale_end-1] == 'x' {
                    hscale_relative = true
                    hscale_end -= 1
                }
                hscale_substring := parse_state.buffer[hscale_start:hscale_end]
               	hscale_value, ok := strconv.parse_f64(hscale_substring); assert(ok)
                
                //append(&parse_state.commands, MText_Command_SethscaleIndex {hscale_value} )
                parse_state.cursor = true_hscale_end + 1
                reset_substring = true
            } else if char == 'S' { // parse stacked texts: '/' means horizontal line, '^' is no line, and '#' is diagonal stack
                numerator_start := parse_state.cursor + 1
                numerator_end := numerator_start
                // todo: investigate how \ and { characters are encoded
                for parse_state.buffer[numerator_end] != '/' && parse_state.buffer[numerator_end] != '^' && parse_state.buffer[numerator_end] != '#' {
                    numerator_end += 1
                }
                cmd := MText_Command_DrawFraction {}
                cmd.numerator = parse_state.buffer[numerator_start:numerator_end]
                cmd.separator = parse_state.buffer[numerator_end]
                denominator_start := numerator_end + 1
                denominator_end := denominator_start
                for parse_state.buffer[denominator_end] != ';' {
                    denominator_end += 1
                }
                cmd.denominator = parse_state.buffer[denominator_start:denominator_end]
                
                append(&parse_state.commands, cmd)
               	parse_state.cursor = denominator_end + 1
                reset_substring = true
            } else if char == 'f' { // parse font
                font_start := parse_state.cursor + 1
                font_end := font_start
                for parse_state.buffer[font_end] != ';' && parse_state.buffer[font_end] != '|' {
                    font_end += 1
                }
                font_command := MText_Command_SetFont {}

                font_command.font = parse_state.buffer[font_start:font_end]
                cursor_flags := font_end
                for parse_state.buffer[cursor_flags] == '|' {
                    flag_name_start := cursor_flags + 1
                    flag_name := parse_state.buffer[flag_name_start]
                    flag_value_start := flag_name_start + 1
                    flag_value_end := flag_value_start
                    for parse_state.buffer[flag_value_end] != ';' && parse_state.buffer[flag_value_end] != '|' {
                        flag_value_end += 1
                    }
                    flag_value_str := parse_state.buffer[flag_value_start:flag_value_end]
                    flag_value, ok := strconv.parse_int(flag_value_str); assert(ok)

                    if flag_name == 'b' {
                        font_command.bold = (flag_value != 0)
                    } else if flag_name == 'i' {
                        font_command.italic = (flag_value != 0)
                    }
                
                    cursor_flags = flag_value_end
                }
                append(&parse_state.commands, font_command )
                
                parse_state.cursor = cursor_flags + 1
                reset_substring = true
            } else {
                // character \ was used as escape token, we make a new substring start after "\" token
                parse_state.substring_start = parse_state.cursor
                // but we move the cursor one past the start, so \\ or \{ sequences don't try to interpret second character
                parse_state.cursor += 1
            }
        } else {
            // no special token
            parse_state.cursor += 1
        }
        if reset_substring {
            parse_state.substring_start = parse_state.cursor
        }
    }

    close_current_string(parse_state)
    return parse_state.commands
}

draw_mtext :: proc(text: dxf.Entity_MText, dxf_file: dxf.DXF_Data) {
    in_pos := text.pos
    content := text.content
    entity := text.entity
    pos := [3]f32{f32(in_pos.x), f32(in_pos.y), 1}
    new_pos := ab.draw_matrix * pos

    commands := compute_mtext_draw(text)



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

    font := ui.get_font_with_size(font_id, font_size)
    if font != nil {
        wght := TTF.VARIATION("wght", 400)
        ok := TTF.SetFontVariations(font, &wght, 1)
        assert(ok == true)
    }


    sdl_text := ui.get_text_with_font_size(font_id, font_size)

    dir_fwd /= f32(font_size)
    dir_up := linalg.cross(dir_fwd, [3]f32{0, 0, -1})


    color := entity_style(text, dxf_file).color
        
    if sdl_text != nil {
        
        tx : matrix[3,3]f32 = 1

        tx[0] = { f32(dir_fwd.x), f32(dir_fwd.y), 0}
        tx[1] = { f32(dir_up.x), f32(dir_up.y), 0}

        tx[2] = { f32(new_pos.x), f32(new_pos.y), 1}

        tx = linalg.transpose(tx)

        cursor := [2]f32{0, 0}

        for command in commands {
            #partial switch cmd in command {
                case MText_Command_SetColorIndex:
                    new_index := entity_resolve_color_index(text, dxf_file, cmd.color)
                    color = resolve_color(new_index)

                case MText_Command_LineBreak:
                    cursor.x = 0
                    cursor.y += f32(font_size)
                case MText_Command_DrawText:

                    cstr := cstring(raw_data(cmd.substring))

                    TTF.SetTextColor(
                        sdl_text,
                        u8(color[0] * 255),
                        u8(color[1] * 255),
                        u8(color[2] * 255),
                        u8(color[3] * 255),
                    )
                    TTF.SetTextString(sdl_text, cstr, uint(len(cmd.substring)))
                    TTF.SetTextWrapWidth(sdl_text, 0)
                    // math.round(new_pos.x), math.round(new_pos.y)
                    size: [2]i32
                    TTF.GetTextSize(sdl_text, &size.x, &size.y)
                    TTF.DrawRendererTextTx(sdl_text, cursor.x, cursor.y, &tx[0][0])
                    cursor.x += f32(size.x)
                case MText_Command_DrawFraction:
                    size_num: [2]i32
                    size_denom: [2]i32
                    
                    cstr := cstring(raw_data(cmd.numerator))
                    TTF.SetTextString(sdl_text, cstr, uint(len(cmd.numerator)))
                    TTF.GetTextSize(sdl_text, &size_num.x, &size_num.y)
                    
                    cstr = cstring(raw_data(cmd.denominator))
                    TTF.SetTextString(sdl_text, cstr, uint(len(cmd.denominator)))
                    TTF.GetTextSize(sdl_text, &size_denom.x, &size_denom.y)
                    
                    TTF.SetTextColor(
                        sdl_text,
                        u8(color[0] * 255),
                        u8(color[1] * 255),
                        u8(color[2] * 255),
                        u8(color[3] * 255),
                    )
                    TTF.SetTextWrapWidth(sdl_text, 0)
                    // math.round(new_pos.x), math.round(new_pos.y)
                    
                    half_height := f32(size_num.y) * 0.5

                    cstr = cstring(raw_data(cmd.numerator))
                    TTF.SetTextString(sdl_text, cstr, uint(len(cmd.numerator)))
                    TTF.DrawRendererTextTx(sdl_text, cursor.x, cursor.y - half_height, &tx[0][0])
                    
                    cstr = cstring(raw_data(cmd.denominator))
                    TTF.SetTextString(sdl_text, cstr, uint(len(cmd.denominator)))
                    TTF.DrawRendererTextTx(sdl_text, cursor.x, cursor.y + half_height, &tx[0][0])
                    
                    largest := math.max(size_num.x, size_denom.x)
                    cursor.x += f32(largest)
            }
            
        }
    }
}

current_block_color := 0

vp_draw :: proc(vp: ViewportState) {
	ab.draw_set_view_basis(vconv(vp.basis_x), vconv(vp.basis_y), vconv(vp.origin))


    draw_entities(vp.data.dxf.entities, vp.data)
}

draw_entities :: proc (entities: dxf.DXF_Entities, model: ^Model) {
    dxf_file := model.dxf

    for text in entities.texts {
        color := entity_style(text, dxf_file).color

        draw_text(text, color)
    }

    for text in entities.mtexts {
        draw_mtext(text, dxf_file)
    }


    for circle in entities.circles {
        gfx.draw_circle(
            {{f32(circle.center.x), f32(circle.center.y)}, f32(circle.radius)},
            {line = entity_style(circle, dxf_file)},
        )
    }

    for arc in entities.arcs {
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

    /*
DrawBuffer :: struct {
	num_vertices: i32,
	num_indices:  i32,
	vertices:     []f32x2,
	uvs:          []f32x2,
	colors:       [][4]f32,
	indices:      []u8,
}
    */
    verts : [256]f32x2
    uvs   : [256]f32x2
    color : [256]f32x4
    index : [256]u8
    
    buffer := gfx.DrawBuffer {
        vertices = verts[:],
        uvs = uvs[:],
        colors = color[:],
        indices = index[:],
    }

    for line in entities.lines {
        style := entity_style(line, dxf_file)

        gfx.buffer_line(&buffer,
            {f32(line.start.x), f32(line.start.y)},
            {f32(line.end.x), f32(line.end.y)},
            1.0,)

        gfx.draw_buffer(ab.renderer, &buffer, style.color)
        buffer.num_indices = 0
        buffer.num_vertices = 0
    
    }

    for polyline in entities.polylines {
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

    for spline in entities.splines {
        maybe_curve: Maybe(CurveBezierCubic)
        for c in model.curves_list {
            if c.handle == spline.handle {
                maybe_curve = c
            }
        }

        curve := maybe_curve.(CurveBezierCubic) or_continue

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

                gfx.draw_line(
                    ab.renderer,
                    {f32(prev.x), f32(prev.y)},
                    {f32(next.x), f32(next.y)},
                    1.0,
                )
                prev = next

            }
        }
    }

    for insert in entities.inserts {
        ab.draw_push_state()
        defer ab.draw_pop_state()

        prev_color := current_block_color
        current_block_color = insert.color
        defer current_block_color = prev_color

        user_matrix: matrix[3,3]f32 = 1
        
        translation: matrix[3,3]f32 = 1

        translation[2] = { f32(insert.center.x), f32(insert.center.y), 1 }
        
        user_matrix *= translation


        scale: matrix[3,3]f32 = 1
        scale[0] = {f32(insert.scale.x), 0, 0}
        scale[1] = {0, f32(insert.scale.y), 0}
        user_matrix *= scale

        rotate := linalg.matrix3_rotate(f32(insert.rotation) * math.RAD_PER_DEG, f32x3{0,0,1})
        user_matrix *= rotate

        ab.draw_set_matrix(user_matrix)

        maybe_block: Maybe(dxf.Block)

        for block in dxf_file.blocks {
            if block.name == insert.block_name {
                maybe_block = block
                break
            }
        }

        if maybe_block == nil {
            log.warn("unable to find block", insert.block_name)
        }

        block_to_draw := maybe_block.(dxf.Block) or_continue
        draw_entities(block_to_draw.entities, model)

    }
    for dim in entities.dimensions {
        #partial switch d in dim {
            case dxf.Entity_Dimension_Aligned: {
                ent_style := entity_style(d, dxf_file)

                color_dim := ent_style.color
                color_ext := ent_style.color
                color_txt := ent_style.color

                dim_style: dxf.Table_DimStyle

                found := false
                for s in dxf_file.dimstyles {
                    if d.style_name == s.name {
                        dim_style = s
                        found = true
                        break
                    }
                }
                
                txt_size := f64(0)

                if found {
                    if dim_style.color_dim != -1 {
                        color_dim = resolve_color(dim_style.color_dim)
                    }
                    if dim_style.color_ext != -1 {
                        color_ext = resolve_color(dim_style.color_ext)
                    }
                    if dim_style.color_txt == 0 {
                        
                    } else if dim_style.color_txt != -1 {
                        color_txt = resolve_color(dim_style.color_txt)
                    }

                    txt_size = dim_style.txt_size
                }

                //style := entity_style(d.entity, dxf_file)
        
                // gfx.draw_line(
                //     ab.renderer,
                //     {f32(d.pos_text.x), f32(d.pos_text.y)},
                //     {f32(d.def_point_b.x), f32(d.def_point_b.y)},
                //     1.0,
                //     style.color,
                // )

                delta_linestart_to_startpoint := d.def_point_b - d.pos_def
                ds := delta_linestart_to_startpoint
                line_dir := f64x3{ds.y, -ds.x, 0}

                delta_linestart_to_endpoint := d.def_point_a - d.pos_def

                line_end_relative := linalg.projection(delta_linestart_to_endpoint, line_dir)

                pos_end := d.pos_def + line_end_relative

                gfx.draw_line(
                    ab.renderer,
                    {f32(d.pos_def.x), f32(d.pos_def.y)},
                    {f32(d.def_point_b.x), f32(d.def_point_b.y)},
                    1.0,
                    color_ext,
                )
                gfx.draw_line(
                    ab.renderer,
                    {f32(pos_end.x), f32(pos_end.y)},
                    {f32(d.def_point_a.x), f32(d.def_point_a.y)},
                    1.0,
                    color_ext,
                )
                gfx.draw_line(
                    ab.renderer,
                    {f32(d.pos_def.x), f32(d.pos_def.y)},
                    {f32(pos_end.x), f32(pos_end.y)},
                    1.0,
                    color_dim,
                )

                text_to_draw: string = d.text_override
                if text_to_draw == "" {
                    text_to_draw = fmt.tprintf("%f", d.measurement)
                }

                rot_mat := linalg.matrix3_rotate(d.angle * math.RAD_PER_DEG, f64x3{0, 0, -1})
                txt_end := f64x3 {1, 0, 0} * rot_mat

                text := dxf.Entity_Text {
                    content = text_to_draw,
                    pos = d.pos_text,
                    end = txt_end,
                    height = txt_size,
                    valign = .Middle,
                    hjustify = .Center
                }

                draw_text(text, color_txt)

            }
        }
    }



}


draw_poly_segment :: proc(prev: f64x2, next: f64x2, bulge: f64, style: gfx.LineStyleSimple) {
    
    if bulge == 0 {
        gfx.draw_line(
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
            gfx.draw_line(
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
        gfx.draw_line(
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


mouse_motion_handler :: proc(model_coords: f64x2, model: ^Model) {
    hovered := -1
    hovered_type := -1

    if model != nil {

        for line in model.dxf.entities.lines {
            
            start := [3]f32{f32(line.start.x), f32(line.start.y), 1}
            end := [3]f32{f32(line.end.x), f32(line.end.y), 1}

            starta := gfx.draw_matrix * start
            enda := gfx.draw_matrix * end
        }
    }
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

entity_resolve_color_index :: proc(entity: dxf.DXF_Entity, file: dxf.DXF_Data, base: int) -> int {
    index := base
	if index == 0 {
        // color: ByBlock
		// TODO: resolve block color, which could map to bylayer?
		index = current_block_color
	}

	if index == 256 {
		// TODO: grab from layer
		layer := file.layers[entity.layer]
		index = layer.color
	}
    return index
}

resolve_color :: proc(index: int) -> Color {
	color := [4]f32{1, 1, 1, 1}
    if index == 0 {
		color = colors[rand.int_range(1, 7)]
	} else if index < len(colors) {
		color = colors[index]
	} else {
		color = colors[7]
	}
    return color
}


entity_style :: proc(entity: dxf.DXF_Entity, file: dxf.DXF_Data) -> gfx.LineStyleSimple {

	index := entity_resolve_color_index(entity, file, entity.color)
    if index < 0 {
        return gfx.LineStyleSimple{width = 0, color = {0,0,0,0}}
    }
    color := resolve_color(index)

	return gfx.LineStyleSimple{width = 1, color = color}
}



font_id := ui.NIL_FONT
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
    144,
}
