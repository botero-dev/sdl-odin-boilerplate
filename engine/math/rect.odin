package abmath

Rect :: struct  {
    x, y, w, h: f32
}

point_in_rect :: proc(point: f32x2, rect: Rect) -> bool {
    return (
        point.x > rect.x &&
        point.x < (rect.x + rect.w) &&
        point.y > rect.y &&
        point.y < (rect.y + rect.h)
    )
}