package dxf

import "core:fmt"
import "core:log"
import "core:strconv"
import "core:mem"


parse_code_f64 :: proc(parse_state: ^DXF_ParseState) -> (value: f64, ok: bool) {
	code := parse_group_code(parse_state)
	content_string := trim(parse_content_string(parse_state))
	value, ok = strconv.parse_f64(content_string)
	if !ok {
		log.warn("error parsing decimal value", code , content_string)
	}
	return
}

parse_code_int :: proc(parse_state: ^DXF_ParseState) -> (value: int, ok: bool) {
	code := parse_group_code(parse_state)
	content_string := trim(parse_content_string(parse_state))
	value, ok = strconv.parse_int(content_string)
	if !ok {
		log.warn("error parsing int value", code , content_string)
	}
	return
}

parse_code_string :: proc(parse_state: ^DXF_ParseState) -> string {
	_ = parse_group_code(parse_state)
	return parse_content_string(parse_state)
}

parse_code_assert_ignore :: proc(parse_state: ^DXF_ParseState, in_code: DXF_Code, _message: string) {
	code := parse_group_code(parse_state)
	parse_content_string(parse_state)
	assert(code == in_code)
}

parse_code_optional_ignore :: proc(parse_state: ^DXF_ParseState, in_code: DXF_Code, _message: string) {
	code := peek_group_code(parse_state)
	if code == in_code {
		parse_group_code(parse_state)
 		parse_content_string(parse_state)
	}
}

trim :: proc(value: string) -> string {
	trim_start := 0
	for value[trim_start] == ' ' {
		trim_start += 1
	}
	return value[trim_start:]
}

peek_group_code :: proc(cursor_ptr: ^DXF_ParseState) -> DXF_Code {
	cursor := cursor_ptr.cursor
	for cursor^ == ' ' || cursor^ == '\t' {
		cursor = mem.ptr_offset(cursor, 1)
	}
	start := cursor
	for true {
		cursor = mem.ptr_offset(cursor, 1)
		if cursor^ < '0' || cursor^ > '9' {
			break;
		}
	}
	strlen := mem.ptr_sub(cursor, start) // exclude newline
	
	str := string(([^]byte)(start)[:strlen])
	result, ok := strconv.parse_uint(str)
	if (!ok) {
		str2 := string(str)
		fmt.printf("bad parse uint:'%s'\n", str2)
		for char in str2 {
			fmt.printf("%d", char)
		}
		fmt.printf("\nbad parse uint:'%s'\n", str)
	}
	/*fmt.println("str: ", str)
	for char in str {
		fmt.print(char)
	}
	fmt.println()
	*/
	assert(ok)
	return DXF_Code(result)
}



parse_group_code :: proc(cursor_ptr: ^DXF_ParseState) -> DXF_Code {
	cursor := cursor_ptr.cursor
	for cursor^ == ' ' || cursor^ == '\t' {
		cursor = mem.ptr_offset(cursor, 1)
	}
	start := cursor
	for true {
		cursor = mem.ptr_offset(cursor, 1)
		if cursor^ < '0' || cursor^ > '9' {
			break;
		}
	}
	strlen := mem.ptr_sub(cursor, start) // exclude newline

	for cursor^ != '\n' {
		cursor = mem.ptr_offset(cursor, 1)
	}
	cursor = mem.ptr_offset(cursor, 1)
	
	cursor_ptr.cursor = cursor

	str := string(([^]byte)(start)[:strlen])
	str = trim(str)
	result, ok := strconv.parse_uint(str)
	// if (!ok) {
	// 	str2 := string(str)
	// 	fmt.printf("bad parse uint:'%s'\n", str2)
	// 	for char in str2 {
	// 		fmt.printf("%d", char)
	// 	}
	// 	fmt.printf("\nbad parse uint:'%s'\n", str)
	// }
	assert(ok)
	if PARSE_DEBUG { fmt.printf("%d:\t", result) }
	return DXF_Code(result)
}

parse_content_string :: proc(cursor_ptr: ^DXF_ParseState) -> string {
	cursor := cursor_ptr.cursor
	start := cursor
	for cursor^ != '\n' && cursor^ != '\r' {
		cursor = mem.ptr_offset(cursor, 1)
	}
	strlen := mem.ptr_sub(cursor, start)
	for cursor^ == '\n' || cursor^ == '\r' {
		cursor = mem.ptr_offset(cursor, 1)
	}
	cursor_ptr.cursor = cursor

	str := string(([^]byte)(start)[:strlen])
//	fmt.printf("found '%s'\n", str)
	if PARSE_DEBUG { fmt.printf("%s\n", str) }
	return str
}

