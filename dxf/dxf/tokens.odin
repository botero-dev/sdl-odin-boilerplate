package dxf

import "core:fmt"
import "core:log"
import "core:strconv"
import "core:mem"
import "core:unicode/utf8"
import "../codepages"


parse_code_f64 :: proc(parse_state: ^DXF_ParseState) -> (value: f64, ok: bool) {
	code := parse_group_code(parse_state)
	content_string := trim(parse_line(parse_state))
	value, ok = strconv.parse_f64(content_string)
	if !ok {
		log.warn("error parsing decimal value", code , content_string)
	}
	return
}

parse_code_checked_f64 :: proc(parse_state: ^DXF_ParseState, in_code: DXF_Code) -> (value: f64, ok: bool) {
	code := parse_group_code(parse_state)
	assert(code == in_code)
	content_string := trim(parse_line(parse_state))
	value, ok = strconv.parse_f64(content_string)
	if !ok {
		log.warn("error parsing decimal value", code , content_string)
	}
	return
}


parse_code_int :: proc(parse_state: ^DXF_ParseState) -> (value: int, ok: bool) {
	code := parse_group_code(parse_state)
	content_string := trim(parse_line(parse_state))
	value, ok = strconv.parse_int(content_string)
	if !ok {
		log.warn("error parsing int value", code , content_string)
	}
	return
}

parse_code_checked_int :: proc(parse_state: ^DXF_ParseState, in_code: DXF_Code) -> (value: int, ok: bool) {
	code := parse_group_code(parse_state)
	assert(code == in_code)
	content_string := trim(parse_line(parse_state))
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

parse_code_checked_string :: proc(parse_state: ^DXF_ParseState, in_code: DXF_Code) -> string {
	code := parse_group_code(parse_state)
	assert(code == in_code)
	return parse_content_string(parse_state)
}

parse_code_checked_line :: proc(parse_state: ^DXF_ParseState, in_code: DXF_Code) -> string {
	code := parse_group_code(parse_state)
	assert(code == in_code)
	return parse_line(parse_state)
}

parse_code_assert_ignore :: proc(parse_state: ^DXF_ParseState, in_code: DXF_Code, _message: string) {
	code := parse_group_code(parse_state)
	parse_line(parse_state)
	assert(code == in_code)
}

parse_code_optional_ignore :: proc(parse_state: ^DXF_ParseState, in_code: DXF_Code, _message: string) {
	code := peek_group_code(parse_state)
	if code == in_code {
		parse_group_code(parse_state)
 		parse_line(parse_state)
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
	cursor_ptr.line += 1
	return DXF_Code(result)
}

parse_content_string :: proc(cursor_ptr: ^DXF_ParseState) -> string {
	base := parse_line(cursor_ptr)
	
	decoded, changed := decode_string(base, cursor_ptr.data.header.codepage)
	return decoded
}

parse_line :: proc(cursor_ptr: ^DXF_ParseState) -> string {
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
	cursor_ptr.line += 1
	return str
}



decode_string :: proc(base: string, codepage: int) -> (string, bool) {
	switch codepage {
		case 874:  return codepage_to_utf8(base, codepages.cp874)
		case 932:  return codepage_to_utf8(base, codepages.cp932)
		case 936:  return codepage_to_utf8(base, codepages.cp936)
		case 949:  return codepage_to_utf8(base, codepages.cp949)
		case 950:  return codepage_to_utf8(base, codepages.cp950)
		case 1250: return codepage_to_utf8(base, codepages.cp1250)
		case 1251: return codepage_to_utf8(base, codepages.cp1251)
		case 1252: return codepage_to_utf8(base, codepages.cp1252)
		case 1253: return codepage_to_utf8(base, codepages.cp1253)
		case 1254: return codepage_to_utf8(base, codepages.cp1254)
		case 1255: return codepage_to_utf8(base, codepages.cp1255)
		case 1256: return codepage_to_utf8(base, codepages.cp1256)
		case 1257: return codepage_to_utf8(base, codepages.cp1257)
		case 1258: return codepage_to_utf8(base, codepages.cp1258)
	}
	return base, false
}
	

codepage_to_utf8 :: proc(src: string, codepage: $C) -> (string, bool) {

    out: [dynamic]u8 // use context allocator
	
	copy_cursor := 0

	idx := 0

    for idx < len(src) {
		b := u16(src[idx])
        if b < 0x80 {  // 00-7F
			idx += 1
            continue
		}
		
		step := 1

		unicode := codepage[b]
		if unicode == 0 {
			step = 2
			b2 := u16(src[idx+1])
			b = b << 8 | b2
			unicode = codepage[b]
		}
		if unicode == 0 {
			log.error("bad string:", src)
			return src, false
		}
		
		cp := rune(unicode)

		if copy_cursor == 0 {
			reserve(&out, len(src) * 2)
		}
		if copy_cursor != idx {
			append(&out, src[copy_cursor:idx])
		}
		
        utf8_bytes, count := utf8.encode_rune(cp)
		append(&out, string(utf8_bytes[:count]))

		idx += step
		copy_cursor = idx
    }

	if len(out) == 0 {
		//log.info("didnt' copy string", src)
		return src, false
	}

	if copy_cursor != len(src) {
		append(&out, src[copy_cursor:])
	}

	//log.info("copied string", string(out[:]))
		
    return string(out[:]), true
}
