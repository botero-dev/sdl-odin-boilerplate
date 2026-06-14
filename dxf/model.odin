package main

import "core:math"

import "dxf"

Model :: struct {
    dxf: dxf.DXF_Data,
    curves_list: [dynamic]CurveBezierCubic,
	center: f64x2,
	size: f64x2,
}

CurveBezierCubic :: struct {
	handle: string,
	points: []f64x3,
}

model_from_dxf :: proc(bytes: []byte) -> Model {
    model := Model {}

	model.dxf = dxf.parse_dxf(bytes)

	post_import(&model)


    return model
}



post_import :: proc(model: ^Model) {

	convert_curves(model.dxf.entities.splines[:], &model.curves_list)
	for block in model.dxf.blocks {
		convert_curves(block.entities.splines[:], &model.curves_list)
	}

	dxf_file := model.dxf

	minx := f64(0)
	miny := f64(0)
	maxx := f64(0)
	maxy := f64(0)
	started := false

	for line in dxf_file.entities.lines {
		if !started {
			minx = line.start.x
			miny = line.start.y
			maxx = line.start.x
			maxy = line.start.y
			started = true
		}

		minx = math.min(minx, line.start.x, line.end.x)
		miny = math.min(miny, line.start.y, line.end.y)
		maxx = math.max(maxx, line.start.x, line.end.x)
		maxy = math.max(maxy, line.start.y, line.end.y)
	}

	for polyline in dxf_file.entities.polylines {
		if !started {
			minx = polyline.points[0].x
			miny = polyline.points[0].y
			maxx = polyline.points[0].x
			maxy = polyline.points[0].y
			started = true
		}

		for point in polyline.points {
			minx = math.min(minx, point.x)
			miny = math.min(miny, point.y)
			maxx = math.max(maxx, point.x)
			maxy = math.max(maxy, point.y)
		}
	}

	for curve in model.curves_list {
		if !started {
			minx = curve.points[0].x
			miny = curve.points[0].y
			maxx = curve.points[0].x
			maxy = curve.points[0].y
			started = true
		}

		for point in curve.points {
			minx = math.min(minx, point.x)
			miny = math.min(miny, point.y)
			maxx = math.max(maxx, point.x)
			maxy = math.max(maxy, point.y)
		}
	}


	size_x := maxx - minx
	size_y := maxy - miny

	center_x := size_x * 0.5 + minx
	center_y := size_y * 0.5 + miny

	model.center = {center_x, center_y}
	model.size = {size_x, size_y}

}
