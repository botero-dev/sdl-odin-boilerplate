package dxf

PARSE_DEBUG :: false

f64x2 :: [2]f64
f64x3 :: [3]f64

DXF_Code :: distinct u32
DXF_Group :: string

DXF_ARC :: DXF_Group("ARC")
DXF_CIRCLE :: DXF_Group("CIRCLE")
DXF_DIMENSION :: DXF_Group("DIMENSION")
DXF_ELLIPSE :: DXF_Group("ELLIPSE")
DXF_ENDSEC :: DXF_Group("ENDSEC")
DXF_ENDTAB :: DXF_Group("ENDTAB")
DXF_ENTITIES :: DXF_Group("ENTITIES")
DXF_EOF :: DXF_Group("EOF")
DXF_HATCH :: DXF_Group("HATCH")
DXF_HEADER :: DXF_Group("HEADER")
DXF_INSERT :: DXF_Group("INSERT")
DXF_LINE :: DXF_Group("LINE")
DXF_LWPOLYLINE :: DXF_Group("LWPOLYLINE")
DXF_MTEXT :: DXF_Group("MTEXT")
DXF_POINT :: DXF_Group("POINT")
DXF_SECTION :: DXF_Group("SECTION")
DXF_SPLINE :: DXF_Group("SPLINE")
DXF_TABLES :: DXF_Group("TABLES")
DXF_TABLE :: DXF_Group("TABLE")
DXF_TEXT :: DXF_Group("TEXT")
DXF_VIEWPORT :: DXF_Group("VIEWPORT")

DXF_VPORT :: DXF_Group("VPORT")
DXF_LTYPE :: DXF_Group("LTYPE")
DXF_LAYER :: DXF_Group("LAYER")
DXF_STYLE :: DXF_Group("STYLE")
DXF_VIEW :: DXF_Group("VIEW")
DXF_UCS :: DXF_Group("UCS")
DXF_APPID :: DXF_Group("APPID")
DXF_DIMSTYLE :: DXF_Group("DIMSTYLE")
DXF_BLOCK_RECORD :: DXF_Group("BLOCK_RECORD")

DXF_ParseState :: struct {
	start: ^byte,
	end: ^byte,
	cursor: ^byte,
	cursor_end: ^byte, // when different to cursor, means next line was parsed already in a peek call. TODO: you can call "consume" and cursor will be set directly to cursor_end
	data: ^DXF_Data,
	line: int,
}

DXF_Entity :: struct {
	using obj: DXF_Object,
	color: int,
	layer: int, // matches an index in layers table
}

Entity_Line :: struct {
	using entity: DXF_Entity,
	start: f64x3,
	end: f64x3,
}


Entity_Circle :: struct {
	using entity: DXF_Entity,
	center: f64x3,
	radius: f64,
}

Entity_Point :: struct {
	using entity: DXF_Entity,
	x: f64,
	y: f64,
	z: f64,
}


Entity_Ellipse :: struct {
	using entity: DXF_Entity,
	center: f64x3,
	axis: f64x3,
	normal: f64x3,
	axis_ratio: f64,
	arc_range: f64x2,
}


Entity_Hatch :: struct {
	using entity: DXF_Entity,
	flags: int,
	points: []f64x2,
	bulges: []f64,
}

Entity_Polyline :: struct {
	using entity: DXF_Entity,
	flags: int,
	points: []f64x2,
	bulges: []f64,
}

Entity_Spline :: struct {
	using entity: DXF_Entity,
	flags: uint,
	degree: uint,
	knots: []f64,
	control_points: []f64x3,
}


Entity_Text :: struct {
	using entity: DXF_Entity,
	content: string,
	pos: f64x3,
	height: f64,
	end: f64x3,
}

Entity_MText :: struct {
	using text: Entity_Text,
}

Entity_Viewport :: struct {
	using entity: DXF_Entity,
	center: f64x3,
	size: f64x2,
}

Entity_Insert :: struct {
	using entity: DXF_Entity,
	component_name: string,
	center: f64x3,
	scale: f64x3,
	rotation: f64,
}

Entity_Arc :: struct {
	using entity: DXF_Entity,
	center: f64x3,
	radius: f64,
	extrusion: f64x3,
	angle_range: f64x2,
}


Entity_Dimension :: struct {
	using entity: DXF_Entity,
	block: string,
	def: f64x3,
	text: f64x3,
	flags: string,
}

DXF_Codepage :: enum {
	ANSI_874  = 874,     // Thai
	ANSI_932  = 932,     // Japanese
	ANSI_936  = 936,     // UnifiedChinese
	ANSI_949  = 949,     // Korean
	ANSI_950  = 950,     // TradChinese
	ANSI_1250 = 1250,    // CentralEurope
	ANSI_1251 = 1251,    // Cyrillic
	ANSI_1252 = 1252,    // WesternEurope
	ANSI_1253 = 1253,    // Greek
	ANSI_1254 = 1254,    // Turkish
	ANSI_1255 = 1255,    // Hebrew
	ANSI_1256 = 1256,    // Arabic
	ANSI_1257 = 1257,    // Baltic
	ANSI_1258 = 1258,    // Vietnam
}


DXF_Header :: struct {
	acadver: int,
	codepage: int,
}

DXF_Data :: struct {
	header: DXF_Header,

	layers: [dynamic]Table_Layer,

	points: [dynamic]Entity_Point,
	hatches: [dynamic]Entity_Hatch,
	polylines: [dynamic]Entity_Polyline,
	splines: [dynamic]Entity_Spline,
    lines: [dynamic]Entity_Line,
    circles: [dynamic]Entity_Circle,
    arcs: [dynamic]Entity_Arc,
    inserts: [dynamic]Entity_Insert,
	ellipses: [dynamic]Entity_Ellipse,
    texts: [dynamic]Entity_Text,
    mtexts: [dynamic]Entity_MText,
    dimensions: [dynamic]Entity_Dimension,
}

