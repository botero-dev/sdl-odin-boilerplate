package ui

import "core:unicode/utf8"


cp1252_to_utf8 :: proc(src: []u8, allocator := context.allocator) -> []u8 {
    cp1252_special := [32]rune{
        0x20AC, 0x0081, 0x201A, 0x0192,
        0x201E, 0x2026, 0x2020, 0x2021,
        0x02C6, 0x2030, 0x0160, 0x2039,
        0x0152, 0x008D, 0x017D, 0x008F,
        0x0090, 0x2018, 0x2019, 0x201C,
        0x201D, 0x2022, 0x2013, 0x2014,
        0x02DC, 0x2122, 0x0161, 0x203A,
        0x0153, 0x009D, 0x017E, 0x0178,
    }

    out := make([dynamic]u8, 0, len(src) * 2, allocator)

    for b in src {
        cp: rune

        if b < 0x80 {
            cp = rune(b)
        } else if b < 0xA0 {
            cp = cp1252_special[b - 0x80]
        } else {
            cp = rune(b)
        }

        utf8_bytes, count := utf8.encode_rune(cp)

        for c in 0..<count {
            append(&out, utf8_bytes[c])
        }
    }

    return out[:]
}