package dxf

import "core:fmt"
import "core:log"
import "core:strconv"


parse_dxf :: proc(bytes: []byte) -> DXF_Data {

	data_data: DXF_Data
	data := &data_data

	parse_state_data := DXF_ParseState {
		start = &bytes[0],
		end = &(([^]byte)(&bytes[0])[len(bytes)]), // way to address past end
		cursor = &bytes[0],
		data = data,
	}

	parse_state := &parse_state_data

	entity_id := -1


	for parse_state.cursor < parse_state.end {
		group_code := parse_group_code(parse_state)
		content := parse_content_string(parse_state)
		if group_code == 0 {
			if content == DXF_SECTION {
				parse_section(parse_state)
				continue
			} else if content == DXF_EOF {
				break
			}
			
		} else if group_code == 999 {
			// created by dxflib tag
			continue
		}
		assert(false, "shouldn't reach this")
	}

	return data_data
}

parse_section :: proc(parse_state: ^DXF_ParseState) {

	assert(parse_group_code(parse_state) == 2)
	section_name := parse_content_string(parse_state)

	log.info("Parsing SECTION:", section_name)
	defer log.info("Finished SECTION:", section_name)

	if section_name == DXF_HEADER {
		parse_section_header(parse_state)
		return
	} else if section_name == DXF_BLOCKS {
		parse_section_blocks(parse_state)
		return
	} else if section_name == DXF_ENTITIES {
		parse_section_entities(parse_state)
		return
	} else if section_name == DXF_TABLES {
		parse_section_tables(parse_state)
		return
	}

	// any other section just iterates to the ENDSEC token
	for true {
		group_code := parse_group_code(parse_state)
		content := parse_content_string(parse_state)
		if group_code == 0 {
			if content == DXF_ENDSEC {
				break
			}
			//continue
		}
		//log.info("code:", group_code, " :", content)
	}

}
parse_section_header :: proc(parse_state: ^DXF_ParseState) {
	for true {
		group_code := parse_group_code(parse_state)
		content := parse_content_string(parse_state)
		if group_code == 0 {
			assert(content == DXF_ENDSEC)
			break
		} else if group_code == 9 {
			parse_header(parse_state, content)
		} else {
			log.error("When parsing HEADER found unexpected:", group_code, content)
		}	
	}
}

current_codes: [dynamic]DXF_Code
current_values: [dynamic]string

INSUNITS_VALUES := []string {
	"Unitless",
	"Inches",
	"Feet",
	"Miles",
	"Millimeters",
	"Centimeters",
	"Meters",
	"Kilometers",
}

parse_header :: proc(parse_state: ^DXF_ParseState, header_name: string) {
	switch header_name {
		case "$ACADVER":
			acad_ver := parse_code_checked_string(parse_state, 1)
			log.info("acad version:", acad_ver)
		case "$DWGCODEPAGE":
			codepage := parse_code_checked_string(parse_state, 3)
			assert(codepage[0:5] == "ANSI_")
			parse_state.data.header.codepage = strconv.parse_int(codepage[5:]) or_break
		case "$INSUNITS": 
			units := parse_code_checked_int(parse_state, 70) or_break
			if units < len(INSUNITS_VALUES) {
				log.info("Model units:", INSUNITS_VALUES[units])
			} else {
				log.info("Model units:", units)
			}
		case:
			//clear(&current_codes)
			//clear(&current_values)
			next := peek_group_code(parse_state)
			for next != 0 && next != 9 {
				value_code := parse_group_code(parse_state)
				value_string := parse_content_string(parse_state)
				//append(&current_codes, value_code)
				//append(&current_values, value_string)
				next = peek_group_code(parse_state)
			}
			//log.info(header_name, current_codes, current_values[:])
	}
}

parse_section_tables :: proc(parse_state: ^DXF_ParseState) {
	for true {
		group_code := parse_group_code(parse_state)
		content := parse_content_string(parse_state)
		if group_code == 0 {
			if content == DXF_ENDSEC {
				break
			}
			if content == DXF_TABLE {
				parse_table(parse_state)
				continue
			}
		}
		log.warn("unhandled", group_code, content)
	}
}

table_callback :: #type proc (parse_state: ^DXF_ParseState)

table_callbacks: map[string]table_callback

parse_table :: proc(parse_state: ^DXF_ParseState) {
	if len(table_callbacks) == 0 {
		table_callbacks[DXF_LTYPE] = parse_table_ltype
		table_callbacks[DXF_LAYER] = parse_table_layer
	}

	assert(parse_group_code(parse_state) == 2)
	table_name := parse_content_string(parse_state)
	callback := table_callbacks[table_name]

	fmt.println("parsing table:", table_name)
	defer fmt.println("finished table:", table_name)
	for true {
		group_code := parse_group_code(parse_state)
		content := parse_content_string(parse_state)
		if group_code == 0 {
			if content == DXF_ENDTAB {
				break
			}
			assert(content == table_name)

			if callback != nil {
				callback(parse_state)
			} else {
				parse_table_item(parse_state, table_name)
			}
		} else if group_code == 5 {
			hex_handle := content
			fmt.println("table handle:", hex_handle)
		} else if group_code == 330 {
			//soft_owner := content
		} else if group_code == 100 {
			//subclass := content
		} else if group_code == 70 {
			//numentries := content
		} else if group_code == 71 {
			//
		} else if group_code == 340 {
			//
		} else if group_code == 102 {
			parse_extension(parse_state, content)
		} else {
			log.warn("unexpected", group_code, ":", content)
		}
	}

}

parse_table_item :: proc(parse_state: ^DXF_ParseState, name: string) {
	done := false
	for !done {
		code := peek_group_code(parse_state)
		switch code {
			case 0:
				done = true
			case 2:
				item_name := parse_code_string(parse_state)
				//log.debug("unhandled", name, item_name)
			case:
				value := parse_code_string(parse_state)
				//fmt.println(name, ":", code, value)
		}
	}
}


Table_LType :: struct {
	using obj: DXF_Object,
	name: string,
}

parse_table_ltype :: proc(parse_state: ^DXF_ParseState) {
	item := Table_LType{}
	done := false
	for !done {
		code := peek_group_code(parse_state)
		switch code {
			case 0:
				done = true
			case 2:
				item.name = parse_code_string(parse_state)
			case 5:
				item.handle = parse_code_string(parse_state)
			case 330:
				item.owner = parse_code_string(parse_state)
			case 100:
				_ = parse_code_string(parse_state)
			case 70:
				layer_flags := parse_code_string(parse_state) // 1:frozen 4:locked

			case 3:
				description := parse_code_string(parse_state)
			case 72:
				alignment_code := parse_code_string(parse_state)
			case 73:
				num_elements := parse_code_string(parse_state)
			case 40:
				total_pattern_length := parse_code_string(parse_state)
			
			// repeating:
			case 49:
				// positive: line, negative: whitespace, zero: dot
				segment_length := parse_code_string(parse_state)
			case 74:
				segment_type_shape_flags := parse_code_string(parse_state)

			case:
				value := parse_code_string(parse_state)
				fmt.println(code, " ", value)
		}
	}
	log.info("parsed ltype", item.name)
}


Table_Layer :: struct {
	using object: DXF_Object,
	name: string,
	color: int,
}

DXF_Object :: struct {
	type: typeid,
	handle: string,
	owner: string,
}

parse_table_layer :: proc(parse_state: ^DXF_ParseState) {
	layer := Table_Layer {}
	layer.handle = parse_code_checked_string(parse_state, 5)

	maybe_ext := peek_group_code(parse_state)
	for maybe_ext == DXF_Code(102) {
		parse_extension(parse_state)
		maybe_ext = peek_group_code(parse_state)
	}

	done := false
	for !done {
		code := peek_group_code(parse_state)
		switch code {
			case 0:
				done = true
			case 2:
				layer.name = parse_code_string(parse_state)
			case 330:
				layer.owner = parse_code_string(parse_state)
			case 100:
				_ = parse_code_string(parse_state)
			case 70:
				layer_flags := parse_code_string(parse_state) // 1:frozen 4:locked
			case 62:
				layer.color = parse_code_int(parse_state) or_continue
			
			case 6:
				line_type := parse_code_string(parse_state)
			case 290:
				plot_flag := parse_code_string(parse_state)
			
			case 370:
				// positive values are hundredths of mm: 50:0.5mm
				// -1:bylayer -2:byblock -3:default
				line_weight := parse_code_int(parse_state) or_continue 
			case 390:
				plot_style_handle := parse_code_string(parse_state)
			case 420:
				true_color := parse_code_string(parse_state)
			case 1001:
				parse_xdata(parse_state)
			case:
				value := parse_code_string(parse_state)
				fmt.println(parse_state.line, "code:", code, ":", value)
		}
	}

	append(&parse_state.data.layers, layer)
}

Block :: struct {
	using entity: DXF_Entity,
	name: string,
	entities: DXF_Entities,
}

parse_section_blocks :: proc(parse_state: ^DXF_ParseState) {
	for true {
		next := parse_code_checked_line(parse_state, 0)
		if next == DXF_BLOCK {
			parse_block(parse_state)
		} else if next == DXF_ENDBLK {
			break
		} else {
			log.error("unexpected group code when parsing block:", next)
			break
		}
	}
}


parse_block :: proc(parse_state: ^DXF_ParseState) {
	block := Block {}
	parse_entity_header(parse_state, &block)
	block.name = parse_code_checked_string(parse_state, 2)
	block_flags, ok := parse_code_checked_int(parse_state, 70); assert(ok)
	parse_code_assert_ignore(parse_state, 10, "block_x")
	parse_code_assert_ignore(parse_state, 20, "block_y")
	parse_code_assert_ignore(parse_state, 30, "block_z")
	parse_code_assert_ignore(parse_state, 3, "layer name alt")
	parse_code_assert_ignore(parse_state, 1, "xref")

	parse_state.entities = &block.entities
	parse_section_entities(parse_state)
	parse_state.entities = nil
}

parse_endblk :: proc(parse_state: ^DXF_ParseState) {
	entity_dummy := DXF_Entity {}
	parse_entity_header(parse_state, &entity_dummy)
}

parse_section_entities :: proc(parse_state: ^DXF_ParseState) {
	parse_state.entities = &parse_state.data.entities
	for true {
		group_code := parse_group_code(parse_state)
		content := parse_content_string(parse_state)
		if group_code == 0 {
			if content == DXF_ENDSEC {
				break
			}
			if content == DXF_ENDBLK {
				parse_endblk(parse_state)
				break
			}
			
			//fmt.println(parse_state.line, content)
			if content == DXF_SPLINE {
				parse_entity_spline(parse_state)
				continue
			}
			if content == DXF_LINE {
				parse_entity_line(parse_state)
				continue
			}
			if content == DXF_CIRCLE {
				parse_entity_circle(parse_state)
				continue
			}
			if content == DXF_LWPOLYLINE {
				parse_entity_polyline(parse_state)
				continue
			}
			if content == DXF_TEXT {
				parse_entity_text(parse_state)
				continue
			}
			if content == DXF_MTEXT {
				parse_entity_mtext(parse_state)
				continue
			}
			if content == DXF_VIEWPORT {
				parse_entity_viewport(parse_state)
				continue
			}
			if content == DXF_DIMENSION {
				parse_entity_dimension(parse_state)
				continue
			}
			if content == DXF_ARC {
				parse_entity_arc(parse_state)
				continue
			}
			if content == DXF_INSERT {
				parse_entity_insert(parse_state)
				continue
			}
			if content == DXF_ELLIPSE {
				parse_entity_ellipse(parse_state)
				continue
			}
			if content == DXF_POINT {
				parse_entity_point(parse_state)
				continue
			}
			if content == DXF_HATCH {
				parse_entity_hatch(parse_state)
				continue
			}
			
			fmt.println("unhandled entity:", content)
		}
		fmt.println(parse_state.line, "code:", group_code, ":", content)
	}

	log.info("Finished parsing ENTITIES")
	parse_state.entities = nil
}


parse_entity_header :: proc(parse_state: ^DXF_ParseState, entity: ^DXF_Entity) {
	assert(entity != nil)
	assert(parse_group_code(parse_state) == DXF_Code(5))	
	entity.handle = parse_content_string(parse_state)

	maybe_ext := peek_group_code(parse_state)
	for maybe_ext == DXF_Code(102) {
		parse_extension(parse_state)
		maybe_ext = peek_group_code(parse_state)
	}

	maybe_owner := peek_group_code(parse_state)
	if maybe_owner == DXF_Code(330) {
		parse_group_code(parse_state)
		entity.owner = parse_content_string(parse_state)
	}

	entity.color = 256 // Color:ByLayer by default

	unhandled := false
	for !unhandled {
		switch peek_group_code(parse_state) {
			case DXF_Code(100):
				parse_group_code(parse_state)
				subclass := parse_content_string(parse_state)
			case DXF_Code(8):
				parse_group_code(parse_state)
				layer_name := parse_content_string(parse_state)

				layer_idx := -1
				all_layers := parse_state.data.layers
				for idx in 0..<len(all_layers) {
					if all_layers[idx].name == layer_name {
						layer_idx = idx
					}
				}
				assert(layer_idx != -1)
				entity.layer = layer_idx
			case DXF_Code(62): // color
				entity.color = parse_code_int(parse_state) or_continue
			case DXF_Code(67): // space
				parse_group_code(parse_state)
				space := parse_content_string(parse_state) // 0: model space, 1: paper space
			case DXF_Code(6):
				parse_group_code(parse_state)
				linetype := parse_content_string(parse_state)
			case DXF_Code(48):
				parse_group_code(parse_state)
				linetype_scale := parse_content_string(parse_state)

			case DXF_Code(370): // weight
				parse_group_code(parse_state)
				line_weight := parse_content_string(parse_state)

			case DXF_Code(420):
				parse_group_code(parse_state)
				true_color := parse_content_string(parse_state)
				
			case DXF_Code(440):
				parse_group_code(parse_state)
				transparency := parse_content_string(parse_state)
				
			case:
				unhandled = true
		}
	}
}
// parse entities functions

parse_entity_point :: proc(parse_state: ^DXF_ParseState) -> (ok: bool) {
	point := Entity_Point {}
	parse_entity_header(parse_state, &point)

	done := false
	for !done {
		next := peek_group_code(parse_state)
		switch next {
			case DXF_Code(0):
				done = true
			case:
				log.error("Point Unexpected code:", next)
				done = true

			case DXF_Code(10):
				point.x = parse_code_f64(parse_state) or_return
			case DXF_Code(20):
				point.y = parse_code_f64(parse_state) or_return
			case DXF_Code(30):
				point.z = parse_code_f64(parse_state) or_return
		}
	}

	append(&parse_state.entities.points, point)
	ok = true
	return
}


parse_entity_ellipse :: proc(parse_state: ^DXF_ParseState) -> (ok: bool) {
	ellipse := Entity_Ellipse {}
	parse_entity_header(parse_state, &ellipse)

	done := false
	for !done {
		next := peek_group_code(parse_state)
		switch next {
			case DXF_Code(0):
				done = true
			case:
				log.error("Unexpected code:", next)
				done = true

			case DXF_Code(10):
				ellipse.center.x = parse_code_f64(parse_state) or_return
			case DXF_Code(20):
				ellipse.center.y = parse_code_f64(parse_state) or_return
			case DXF_Code(30):
				ellipse.center.z = parse_code_f64(parse_state) or_return

			case DXF_Code(11):
				ellipse.axis.x = parse_code_f64(parse_state) or_return
			case DXF_Code(21):
				ellipse.axis.y = parse_code_f64(parse_state) or_return
			case DXF_Code(31):
				ellipse.axis.z = parse_code_f64(parse_state) or_return

			case DXF_Code(210):
				ellipse.normal.x = parse_code_f64(parse_state) or_return
			case DXF_Code(220):
				ellipse.normal.y = parse_code_f64(parse_state) or_return
			case DXF_Code(230):
				ellipse.normal.z = parse_code_f64(parse_state) or_return

			case DXF_Code(40):
				ellipse.axis_ratio = parse_code_f64(parse_state) or_return
			case DXF_Code(41):
				ellipse.arc_range.x = parse_code_f64(parse_state) or_return
			case DXF_Code(42):
				ellipse.arc_range.y = parse_code_f64(parse_state) or_return
		}
	}

	append(&parse_state.entities.ellipses, ellipse)
	ok = true
	return
}

parse_entity_insert :: proc(parse_state: ^DXF_ParseState) -> (ok: bool) {
	insert := Entity_Insert {}
	parse_entity_header(parse_state, &insert)
	done := false
	for !done {
		next := peek_group_code(parse_state)
		switch next {
			case DXF_Code(2):
				insert.component_name = parse_code_string(parse_state)
			case DXF_Code(10):
				insert.center.x = parse_code_f64(parse_state) or_return
			case DXF_Code(20):
				insert.center.y = parse_code_f64(parse_state) or_return
			case DXF_Code(30):
				insert.center.z = parse_code_f64(parse_state) or_return

			case DXF_Code(41):
				insert.scale.x = parse_code_f64(parse_state) or_return
			case DXF_Code(42):
				insert.scale.y = parse_code_f64(parse_state) or_return
			case DXF_Code(43):
				insert.scale.z = parse_code_f64(parse_state) or_return

			case DXF_Code(50):
				insert.rotation = parse_code_f64(parse_state) or_return
			case:
				done = true
		}
	}
	parse_xdata(parse_state)

	append(&parse_state.entities.inserts, insert)

	next := peek_group_code(parse_state)
	assert(next == DXF_Code(0))
	ok = true
	return
}

parse_entity_arc :: proc(parse_state: ^DXF_ParseState) -> (ok: bool) {
	arc := Entity_Arc {}
	parse_entity_header(parse_state, &arc)
	done := false
	for !done {
		next := peek_group_code(parse_state)
		switch next {
			case DXF_Code(10):
				arc.center.x = parse_code_f64(parse_state) or_return
			case DXF_Code(20):
				arc.center.y = parse_code_f64(parse_state) or_return
			case DXF_Code(30):
				arc.center.z = parse_code_f64(parse_state) or_return
			case DXF_Code(40):
				arc.radius = parse_code_f64(parse_state) or_return

			case DXF_Code(210):
				arc.extrusion.x = parse_code_f64(parse_state) or_return
			case DXF_Code(220):
				arc.extrusion.y = parse_code_f64(parse_state) or_return
			case DXF_Code(230):
				arc.extrusion.z = parse_code_f64(parse_state) or_return

			case DXF_Code(100):
				_ = parse_code_string(parse_state)
			case DXF_Code(50):
				arc.angle_range[0] = parse_code_f64(parse_state) or_return
			case DXF_Code(51):
				arc.angle_range[1] = parse_code_f64(parse_state) or_return

			case:
				done = true
		}
	}
	append(&parse_state.entities.arcs, arc)
	ok = true
	return
}

parse_entity_dimension :: proc(parse_state: ^DXF_ParseState) -> (ok: bool) {
	dim := Entity_Dimension {}
	parse_entity_header(parse_state, &dim)

	done := false
	for !done {
		next := peek_group_code(parse_state)
		switch next {
			case DXF_Code(2):
				dim_block := parse_code_string(parse_state)
	
			case DXF_Code(10):
				dim.def.x = parse_code_f64(parse_state) or_return
			case DXF_Code(20):
				dim.def.y = parse_code_f64(parse_state) or_return
			case DXF_Code(30):
				dim.def.z = parse_code_f64(parse_state) or_return

			case DXF_Code(11):
				dim.text.x = parse_code_f64(parse_state) or_return
			case DXF_Code(21):
				dim.text.y = parse_code_f64(parse_state) or_return
			case DXF_Code(31):
				dim.text.z = parse_code_f64(parse_state) or_return

			case DXF_Code(70):
				dim_flags := parse_code_string(parse_state)

			case DXF_Code(1):
				override_text := parse_code_string(parse_state)
			case DXF_Code(71):
				text_attachment := parse_code_string(parse_state)
			case DXF_Code(42):
				measurement := parse_code_string(parse_state)

			case DXF_Code(3):
				dim_style := parse_code_string(parse_state)

			case DXF_Code(100):
				subclass := parse_code_string(parse_state)

			case DXF_Code(13):
				line1_x := parse_code_string(parse_state)
			case DXF_Code(23):
				line1_y := parse_code_string(parse_state)
			case DXF_Code(33):
				line1_z := parse_code_string(parse_state)

			case DXF_Code(14):
				line2_x := parse_code_string(parse_state)
			case DXF_Code(24):
				line2_y := parse_code_string(parse_state)
			case DXF_Code(34):
				line2_z := parse_code_string(parse_state)

			case DXF_Code(50):
				rotation := parse_code_string(parse_state)

			case:
				done = true
		}
	}

	parse_xdata(parse_state)
	ok = true
	return
}


parse_entity_viewport :: proc(parse_state: ^DXF_ParseState) {

/*	assert(parse_group_code(parse_state) == DXF_Code(5))	
	handle := parse_content_string(parse_state)

	maybe_ext := peek_group_code(parse_state)
	if maybe_ext == DXF_Code(102) {
		parse_extension(parse_state)
	}

	assert(parse_group_code(parse_state) == DXF_Code(330))
	owner := parse_content_string(parse_state)
*/
	viewport := Entity_Viewport {}
	parse_entity_header(parse_state, &viewport)
	// assert(parse_group_code(parse_state) == DXF_Code(6))
	// linetype := parse_content_string(parse_state)

	
	assert(parse_group_code(parse_state) == DXF_Code(10))
	viewport.center.x, _ = strconv.parse_f64(trim(parse_content_string(parse_state))) 
	assert(parse_group_code(parse_state) == DXF_Code(20))
	viewport.center.y, _ = strconv.parse_f64(trim(parse_content_string(parse_state)))
	assert(parse_group_code(parse_state) == DXF_Code(30))
	viewport.center.z, _ = strconv.parse_f64(trim(parse_content_string(parse_state)))

	assert(parse_group_code(parse_state) == DXF_Code(40))
	viewport.size.x, _ = strconv.parse_f64(trim(parse_content_string(parse_state)))
	assert(parse_group_code(parse_state) == DXF_Code(41))
	viewport.size.y, _ = strconv.parse_f64(trim(parse_content_string(parse_state)))
	
	
	assert(parse_group_code(parse_state) == DXF_Code(68))
	viewport_status := parse_content_string(parse_state)

	assert(parse_group_code(parse_state) == DXF_Code(69))
	viewport_id := parse_content_string(parse_state)

	assert(parse_group_code(parse_state) == DXF_Code(12))
	view_center_x := parse_content_string(parse_state)

	assert(parse_group_code(parse_state) == DXF_Code(22))
	view_center_y := parse_content_string(parse_state)


	assert(parse_group_code(parse_state) == DXF_Code(13))
	snap_base_x := parse_content_string(parse_state)

	assert(parse_group_code(parse_state) == DXF_Code(23))
	snap_base_y := parse_content_string(parse_state)


	assert(parse_group_code(parse_state) == DXF_Code(14))
	snap_spacing_x := parse_content_string(parse_state)

	assert(parse_group_code(parse_state) == DXF_Code(24))
	snap_spacing_y := parse_content_string(parse_state)


	assert(parse_group_code(parse_state) == DXF_Code(15))
	grid_spacing_x := parse_content_string(parse_state)

	assert(parse_group_code(parse_state) == DXF_Code(25))
	grid_spacing_y := parse_content_string(parse_state)

	assert(parse_group_code(parse_state) == DXF_Code(16))
	view_dir_x := parse_content_string(parse_state)
	assert(parse_group_code(parse_state) == DXF_Code(26))
	view_dir_y := parse_content_string(parse_state)
	assert(parse_group_code(parse_state) == DXF_Code(36))
	view_dir_z := parse_content_string(parse_state)

	assert(parse_group_code(parse_state) == DXF_Code(17))
	cam_target_x := parse_content_string(parse_state)
	assert(parse_group_code(parse_state) == DXF_Code(27))
	cam_target_y := parse_content_string(parse_state)
	assert(parse_group_code(parse_state) == DXF_Code(37))
	cam_target_z := parse_content_string(parse_state)

	assert(parse_group_code(parse_state) == DXF_Code(42))
	view_height := parse_content_string(parse_state)
	assert(parse_group_code(parse_state) == DXF_Code(43))
	lens_length := parse_content_string(parse_state)

	assert(parse_group_code(parse_state) == DXF_Code(44))
	front_clip := parse_content_string(parse_state)
	assert(parse_group_code(parse_state) == DXF_Code(45))
	back_clip := parse_content_string(parse_state)

	assert(parse_group_code(parse_state) == DXF_Code(50))
	twist := parse_content_string(parse_state)
	assert(parse_group_code(parse_state) == DXF_Code(51))
	snap_rotation := parse_content_string(parse_state)

	assert(parse_group_code(parse_state) == DXF_Code(72))
	circle_zoom := parse_content_string(parse_state)

	assert(parse_group_code(parse_state) == DXF_Code(90))
	viewport_bits := parse_content_string(parse_state)

	assert(parse_group_code(parse_state) == DXF_Code(1))
	frozen_layers := parse_content_string(parse_state)

	assert(parse_group_code(parse_state) == DXF_Code(281))
	render_mode := parse_content_string(parse_state)

	assert(parse_group_code(parse_state) == DXF_Code(71))
	ucsfollow := parse_content_string(parse_state)

	assert(parse_group_code(parse_state) == DXF_Code(74))
	ucsicon := parse_content_string(parse_state)

	assert(parse_group_code(parse_state) == DXF_Code(110))
	ucs_origin_x := parse_content_string(parse_state)
	assert(parse_group_code(parse_state) == DXF_Code(120))
	ucs_origin_y := parse_content_string(parse_state)
	assert(parse_group_code(parse_state) == DXF_Code(130))
	ucs_origin_z := parse_content_string(parse_state)

	assert(parse_group_code(parse_state) == DXF_Code(111))
	ucs_right_x := parse_content_string(parse_state)
	assert(parse_group_code(parse_state) == DXF_Code(121))
	ucs_right_y := parse_content_string(parse_state)
	assert(parse_group_code(parse_state) == DXF_Code(131))
	ucs_right_z := parse_content_string(parse_state)

	assert(parse_group_code(parse_state) == DXF_Code(112))
	ucs_up_x := parse_content_string(parse_state)
	assert(parse_group_code(parse_state) == DXF_Code(122))
	ucs_up_y := parse_content_string(parse_state)
	assert(parse_group_code(parse_state) == DXF_Code(132))
	ucs_up_z := parse_content_string(parse_state)


	assert(parse_group_code(parse_state) == DXF_Code(79))
	ucs_ortho_type := parse_content_string(parse_state)
	assert(parse_group_code(parse_state) == DXF_Code(146))
	ucs_elevation := parse_content_string(parse_state)

}

parse_entity_mtext :: proc(parse_state: ^DXF_ParseState) {
	/*
	assert(parse_group_code(parse_state) == DXF_Code(5))	
	handle := parse_content_string(parse_state)


	assert(parse_group_code(parse_state) == DXF_Code(330))
	owner := parse_content_string(parse_state)

*/
	text := Entity_MText {}
	text.end = {1, 0, 0}

	parse_entity_header(parse_state, &text)

	done := false
	for !done {
		switch peek_group_code(parse_state) {
			case DXF_Code(10):
				parse_group_code(parse_state)
				text.pos.x, _ = strconv.parse_f64(trim(parse_content_string(parse_state)))
			case DXF_Code(20):
				parse_group_code(parse_state)
				text.pos.y, _ = strconv.parse_f64(trim(parse_content_string(parse_state)))
			case DXF_Code(30):
				parse_group_code(parse_state)
				text.pos.z, _ = strconv.parse_f64(trim(parse_content_string(parse_state)))
			case DXF_Code(40):
				parse_group_code(parse_state)
				text.height, _ = strconv.parse_f64(trim(parse_content_string(parse_state)))

			case DXF_Code(41):
				parse_group_code(parse_state)
				ref_rect_width := parse_content_string(parse_state)

			case DXF_Code(71):
				parse_group_code(parse_state)
				attachment_point := parse_content_string(parse_state) // index of [nw, n, ne, w, c, e, sw, s, se]
				
			case DXF_Code(72):
				parse_group_code(parse_state)
				flow_direction := parse_content_string(parse_state) // 1:LTR, 3:RTL, 5:ByStyle

			case DXF_Code(1):
				parse_group_code(parse_state)
				text.content = parse_content_string(parse_state)

			case 7:
				style_name := parse_code_string(parse_state)
			case 50:
				angle := parse_code_string(parse_state)

			case DXF_Code(73):
				parse_group_code(parse_state)
				space_style := parse_content_string(parse_state) // 1:atleast 2:exact
			case DXF_Code(44):
				parse_group_code(parse_state)
				line_space_factor := parse_content_string(parse_state)

			case DXF_Code(11):
				parse_group_code(parse_state)
				text.end.x, _ = strconv.parse_f64(trim(parse_content_string(parse_state)))
			case DXF_Code(21):
				parse_group_code(parse_state)
				text.end.y, _ = strconv.parse_f64(trim(parse_content_string(parse_state)))
			case DXF_Code(31):
				parse_group_code(parse_state)
				text.end.z, _ = strconv.parse_f64(trim(parse_content_string(parse_state)))


			case:
				done = true
		}
	}

	parse_xdata(parse_state)
	next := peek_group_code(parse_state)
	assert(next == DXF_Code(0))

	append(&parse_state.entities.mtexts, text)
}


parse_entity_text :: proc(parse_state: ^DXF_ParseState) {
	/*
	assert(parse_group_code(parse_state) == DXF_Code(5))	
	handle := parse_content_string(parse_state)


	assert(parse_group_code(parse_state) == DXF_Code(330))
	owner := parse_content_string(parse_state)
*/

	text := Entity_Text {}
	text.end = {1, 0, 0}
	parse_entity_header(parse_state, &text)

	done := false
	for !done {
		switch peek_group_code(parse_state) {
			case DXF_Code(1):
				parse_group_code(parse_state)
				text.content = parse_content_string(parse_state)

			case DXF_Code(10):
				parse_group_code(parse_state)
				text.pos.x, _ = strconv.parse_f64(trim(parse_content_string(parse_state)))
			case DXF_Code(20):
				parse_group_code(parse_state)
				text.pos.y, _ = strconv.parse_f64(trim(parse_content_string(parse_state)))
			case DXF_Code(30):
				parse_group_code(parse_state)
				text.pos.z, _ = strconv.parse_f64(trim(parse_content_string(parse_state)))
			case DXF_Code(40):
				parse_group_code(parse_state)
				text.height, _ = strconv.parse_f64(trim(parse_content_string(parse_state)))

			case DXF_Code(50):
				parse_group_code(parse_state)
				angle := parse_content_string(parse_state)
			
			case 41:
				width_factor := parse_code_f64(parse_state) or_continue
			
			case 7:
				style_name := parse_code_string(parse_state)
			
			case 71:
				text_gen_flags := parse_code_string(parse_state)

			case DXF_Code(72):
				parse_group_code(parse_state)
				justify_horz := parse_content_string(parse_state)

			case DXF_Code(11):
				parse_group_code(parse_state)
				text.end.x, _ = strconv.parse_f64(trim(parse_content_string(parse_state)))
			case DXF_Code(21):
				parse_group_code(parse_state)
				text.end.y, _ = strconv.parse_f64(trim(parse_content_string(parse_state)))
			case DXF_Code(31):
				parse_group_code(parse_state)
				text.end.z, _ = strconv.parse_f64(trim(parse_content_string(parse_state)))

			case DXF_Code(100):
				parse_group_code(parse_state)
				subclass_text := parse_content_string(parse_state)
			case DXF_Code(73):
				parse_group_code(parse_state)
				justify_vert := parse_content_string(parse_state)

			case:
				done = true
		}
	}

	append(&parse_state.entities.texts, text)
}


parse_xdata :: proc(parse_state: ^DXF_ParseState) {
	maybe_xdata := peek_group_code(parse_state)
	if maybe_xdata == DXF_Code(0) {
		return
	}

	assert(parse_group_code(parse_state) == DXF_Code(1001))
	provider := parse_content_string(parse_state)

	for true {
		code := parse_group_code(parse_state)
		value := parse_content_string(parse_state)
		assert(int(code) >= 1000)

		next := peek_group_code(parse_state)
		if next < 1000 {
			break
		}
	}
	
}

parse_extension :: proc(parse_state: ^DXF_ParseState, consumed_ext_name: Maybe(string) = nil) {
	ext_name: string
	if consumed_ext_name == nil {
		assert(parse_group_code(parse_state) == 102)
		ext_name = parse_content_string(parse_state)
	} else {
		ext_name = consumed_ext_name.(string)
	}
	assert(ext_name == "{ACAD_REACTORS" || ext_name == "{ACAD_XDICTIONARY")

	done := false
	for !done {
		switch parse_group_code(parse_state) {
			case DXF_Code(330):
				referenced := parse_content_string(parse_state)
			case DXF_Code(360):
				referenced := parse_content_string(parse_state)
			case DXF_Code(102):
				assert(parse_content_string(parse_state) == "}")
				done = true
		}
	}
	
}

parse_entity_line :: proc(parse_state: ^DXF_ParseState) {
	/*
	assert(parse_group_code(parse_state) == DXF_Code(5))	
	handle := parse_content_string(parse_state)

	maybe_reactor := peek_group_code(parse_state)
	if maybe_reactor == DXF_Code(102) {
		parse_extension(parse_state)
	}

	assert(parse_group_code(parse_state) == DXF_Code(330))
	owner := parse_content_string(parse_state)
	*/

	line := Entity_Line{}
	
	parse_entity_header(parse_state, &line)
	// assert(parse_group_code(parse_state) == DXF_Code(6))
	// linetype := parse_content_string(parse_state)

	assert(parse_group_code(parse_state) == DXF_Code(10))
	start_x, _ := strconv.parse_f64(trim(parse_content_string(parse_state)))
	assert(parse_group_code(parse_state) == DXF_Code(20))
	start_y, _ := strconv.parse_f64(trim(parse_content_string(parse_state)))
	assert(parse_group_code(parse_state) == DXF_Code(30))
	start_z, _ := strconv.parse_f64(trim(parse_content_string(parse_state)))

	assert(parse_group_code(parse_state) == DXF_Code(11))
	end_x, _ := strconv.parse_f64(trim(parse_content_string(parse_state)))
	assert(parse_group_code(parse_state) == DXF_Code(21))
	end_y, _ := strconv.parse_f64(trim(parse_content_string(parse_state)))
	assert(parse_group_code(parse_state) == DXF_Code(31))
	end_z, _ := strconv.parse_f64(trim(parse_content_string(parse_state)))

	line.start = {start_x, start_y, start_z}
	line.end = {end_x, end_y, end_z}
	
	append(&parse_state.entities.lines, line)
}


parse_entity_circle :: proc(parse_state: ^DXF_ParseState) {
	circle := Entity_Circle {}
	parse_entity_header(parse_state, &circle)


	assert(parse_group_code(parse_state) == DXF_Code(10))
	center_x, _ := strconv.parse_f64(trim(parse_content_string(parse_state)))
	assert(parse_group_code(parse_state) == DXF_Code(20))
	center_y, _ := strconv.parse_f64(trim(parse_content_string(parse_state)))
	assert(parse_group_code(parse_state) == DXF_Code(30))
	center_z, _ := strconv.parse_f64(trim(parse_content_string(parse_state)))
	assert(parse_group_code(parse_state) == DXF_Code(40))
	radius, _ := strconv.parse_f64(trim(parse_content_string(parse_state)))

	circle.center = {center_x, center_y, center_z}
	circle.radius = radius
	
	append(&parse_state.entities.circles, circle)
}


parse_entity_hatch :: proc(parse_state: ^DXF_ParseState) {

	hatch := Entity_Hatch {}
	parse_entity_header(parse_state, &hatch)

	done := false
	for !done {
		switch peek_group_code(parse_state) {
			case 10:
				elevation_x := parse_code_f64(parse_state) or_continue
			case 20:
				elevation_y := parse_code_f64(parse_state) or_continue
			case 30:
				elevation_z := parse_code_f64(parse_state) or_continue
			case 210:
				extrusion_x := parse_code_f64(parse_state) or_continue
			case 220:
				extrusion_y := parse_code_f64(parse_state) or_continue
			case 230:
				extrusion_z := parse_code_f64(parse_state) or_continue
			case 2:
				pattern := parse_code_string(parse_state)
			case 70:
				solid_fill_flag := parse_code_string(parse_state)
			case 71:
				associativity_flag := parse_code_string(parse_state)
			case:
				done = true
		}
	}
	
	bounds_num_paths, ok := parse_code_checked_int(parse_state, 91); assert(ok)
	Bounds_Path_Type :: enum {
		Line = 1,
		Arc = 2,
		Ellipse = 3,
		Spline = 4,
	}

	for path_idx in 0..<bounds_num_paths {
		bounds_path_type_flags, ok := parse_code_checked_int(parse_state, 92) ; assert(ok)
		assert(bounds_path_type_flags == 1)
		bounds_path_edges, ok2 := parse_code_checked_int(parse_state, 93); assert(ok2)

		for edge_idx in 0..<bounds_path_edges {
			
			bounds_path_type := Bounds_Path_Type(parse_code_checked_int(parse_state, 72) or_continue)
			#partial switch bounds_path_type {
				case .Line:
					start_x := parse_code_checked_f64(parse_state, 10) or_else 0
					start_y := parse_code_checked_f64(parse_state, 20) or_else 0
					end_x := parse_code_checked_f64(parse_state, 11) or_else 0
					end_y := parse_code_checked_f64(parse_state, 21) or_else 0
				case .Arc:
					center_x := parse_code_checked_f64(parse_state, 10) or_else 0
					center_y := parse_code_checked_f64(parse_state, 20) or_else 0
					radius := parse_code_checked_f64(parse_state, 40) or_else 0
					angle_start := parse_code_checked_f64(parse_state, 50) or_else 0
					angle_end := parse_code_checked_f64(parse_state, 51) or_else 0
					counterclockwise := parse_code_checked_int(parse_state, 73) or_else 0
				case:
					assert(false)
				
			}
		}

		if peek_group_code(parse_state) == 97 {
			num_codes, ok := parse_code_checked_int(parse_state, 97)
			for idx_assoc in 0..<num_codes {
				parse_code_assert_ignore(parse_state, 330, "associate entity id")
			}
		}
	}

	parse_code_optional_ignore(parse_state, 75, "hatch style")
	parse_code_optional_ignore(parse_state, 76, "hatch pattern type")

	parse_code_optional_ignore(parse_state, 52, "pattern angle")
	parse_code_optional_ignore(parse_state, 41, "pattern scale")
	parse_code_optional_ignore(parse_state, 77, "pattern double flag")

	if peek_group_code(parse_state) == 78 {
		pattern_num_lines, ok := parse_code_int(parse_state); assert(ok)

		for line_idx in 0..<pattern_num_lines {
			parse_code_assert_ignore(parse_state, 53, "pattern line angle")
			parse_code_assert_ignore(parse_state, 43, "pattern line base x")
			parse_code_assert_ignore(parse_state, 44, "pattern line base y")
			parse_code_assert_ignore(parse_state, 45, "pattern line offset x")
			parse_code_assert_ignore(parse_state, 46, "pattern line offset y")
			num_dash_items, ok := parse_code_int(parse_state); assert(ok)
			for item in 0..<num_dash_items {
				_ = parse_code_checked_f64(parse_state, 49) or_continue
			}
		}
	}



	if peek_group_code(parse_state) == 98 {
		seed_point_count, ok := parse_code_checked_int(parse_state, 98)
		assert(ok)
		assert(seed_point_count == 0)
		
	}
	
	parse_xdata(parse_state)

	append(&parse_state.entities.hatches, hatch)

}


parse_entity_polyline :: proc(parse_state: ^DXF_ParseState) {

	polyline := Entity_Polyline {}
	parse_entity_header(parse_state, &polyline)

	assert(parse_group_code(parse_state) == DXF_Code(90))
	vertex_count_str := parse_content_string(parse_state)
	vertex_count, _ := strconv.parse_uint(trim(vertex_count_str))

	done := false
	for !done {
		switch peek_group_code(parse_state) {
			case DXF_Code(70):
				polyline.flags = parse_code_int(parse_state) or_continue
			case DXF_Code(43):
				parse_group_code(parse_state)
				polyline_width := parse_content_string(parse_state)
			case DXF_Code(38):
				parse_group_code(parse_state)
				elevation := parse_content_string(parse_state)
			case:
				done = true
		}
	}

	polyline.points = make([]f64x2, vertex_count)
	polyline.bulges = make([]f64, vertex_count)
	

	idx := int(-1)
	done = false
	for !done {
		switch peek_group_code(parse_state) {
			case DXF_Code(10):
				parse_group_code(parse_state)
				idx += 1
				value, ok := strconv.parse_f64(trim(parse_content_string(parse_state)))
				polyline.points[idx].x = value
			case DXF_Code(20):
				parse_group_code(parse_state)
				value, ok := strconv.parse_f64(trim(parse_content_string(parse_state)))
				polyline.points[idx].y = value
			case DXF_Code(42):
				parse_group_code(parse_state)
				value, ok := strconv.parse_f64(trim(parse_content_string(parse_state)))
				polyline.bulges[idx] = value
			case :
				done = true
		}
	}
	assert(idx == (int(vertex_count)-1))

	append(&parse_state.entities.polylines, polyline)

}


parse_entity_spline :: proc(parse_state: ^DXF_ParseState) {

	spline := Entity_Spline {}
	parse_entity_header(parse_state, &spline)

	assert(parse_group_code(parse_state) == DXF_Code(210))
	extrusion_x := parse_content_string(parse_state)

	assert(parse_group_code(parse_state) == DXF_Code(220))
	extrusion_y := parse_content_string(parse_state)

	assert(parse_group_code(parse_state) == DXF_Code(230))
	extrusion_z := parse_content_string(parse_state)


	assert(parse_group_code(parse_state) == DXF_Code(70))
	spline_flags := parse_content_string(parse_state)

	assert(parse_group_code(parse_state) == DXF_Code(71))
	spline_degree_str := parse_content_string(parse_state)
	spline_degree, _ := strconv.parse_uint(trim(spline_degree_str))


	assert(parse_group_code(parse_state) == DXF_Code(72))
	spline_numknots_str := parse_content_string(parse_state)
	spline_numknots, _ := strconv.parse_uint(trim(spline_numknots_str))

	assert(parse_group_code(parse_state) == DXF_Code(73))
	spline_numcontrolpts_ptr := parse_content_string(parse_state)
	spline_numcontrolpts, _ := strconv.parse_uint(trim(spline_numcontrolpts_ptr))

	//log.info("Parsing SPLINE", handle, " degree:", spline_degree, " knots:", spline_numknots, " ctrl_points:", spline_numcontrolpts)

	assert(parse_group_code(parse_state) == DXF_Code(74))
	spline_numfitpts := parse_content_string(parse_state)

	assert(parse_group_code(parse_state) == DXF_Code(42))
	spline_tolerance_knot := parse_content_string(parse_state)

	assert(parse_group_code(parse_state) == DXF_Code(43))
	spline_tolerance_controlpoints := parse_content_string(parse_state)

	spline.degree = spline_degree
	spline.knots = make([]f64, spline_numknots)
	spline.control_points = make([]f64x3, spline_numcontrolpts)

	for idx in 0..<spline_numknots {
		assert(parse_group_code(parse_state) == DXF_Code(40))
		knot_str := parse_content_string(parse_state)
		knot, ok := strconv.parse_f64(trim(knot_str))
		spline.knots[idx] = knot
	}

	for idx in 0..<spline_numcontrolpts {
		assert(parse_group_code(parse_state) == DXF_Code(10))
		control_x, _ := strconv.parse_f64(trim(parse_content_string(parse_state)))
		assert(parse_group_code(parse_state) == DXF_Code(20))
		control_y, _ := strconv.parse_f64(trim(parse_content_string(parse_state)))
		assert(parse_group_code(parse_state) == DXF_Code(30))
		control_z, _ := strconv.parse_f64(trim(parse_content_string(parse_state)))
		spline.control_points[idx] = {control_x, control_y, control_z}
	}	

	append(&parse_state.entities.splines, spline)
}

