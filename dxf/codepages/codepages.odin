package codepages
/*
/// Idea for more optimal decoding data structure
CodePageMapping_Base :: struct {
	start: u32,
	end: u32, // inclusive
}

CodePageMapping_Same :: struct {
	using CodePageMapping_Base,
}

CodePageMapping_Remap :: struct {
	using CodePageMapping_Base,
	new_start: i32
}

// indices in values table are calculated from the start of the range
CodePageMapping_Table :: struct {
	using CodePageMapping_Base,
	values: []u32{}
}

// This indicates another byte should be read, and combined value should be used to index this table
CodePageMapping_SubTable :: struct {
	using CodePageMapping_Base,
	values: []u32{}
}

CodePageMapping :: union {
	CodePageMapping_Same,
	CodePageMapping_Offset,
}

cp932 := []CodePageMapping {
	CodePageMapping_Same { 0x00, 0x79 },
	CodePageMapping_SubTable { 0x80, 0xA0 },
	CodePageMapping_Remap { 0xA1, 0xDF, 0xFF61 }
	CodePageMapping_SubTable { 0xE0, 0xFF },
}

*/

