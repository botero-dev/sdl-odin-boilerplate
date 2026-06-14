package main

import "dxf"



convert_curves :: proc(file: dxf.DXF_Data, curves: ^[dynamic]CurveBezierCubic ) {
	for spline in file.entities.splines {
		if len(spline.knots) == (len(spline.control_points) + int(spline.degree) + 1) {
			segments := (len(spline.control_points) - 1) / int(spline.degree)
			// can be simplified to bezier curve
			last_knot := spline.knots[0]
			multiplicity := 1
			segment := 0

			meets_criteria := true

			for idx in 1..<len(spline.knots) {
				if spline.knots[idx] == last_knot {
					multiplicity += 1
				} else { // new knot, check previous knot validity
					if multiplicity == 3 {
						//meets_criteria = true
					} else if segment == 0 && multiplicity == 4 {
						// meets_criteria = true
					} else {
						meets_criteria = false
						break;
					}
					if !meets_criteria {
						break
					}
					multiplicity = 1
					last_knot = spline.knots[idx]
				}
			}

			if multiplicity != 4 {
				meets_criteria = false
			}

			if !meets_criteria {
				continue
			}

			bezier := CurveBezierCubic {
				points = spline.control_points
			}
			append(curves, bezier)
		}
	}
}