shader_type canvas_item;

uniform float skew_amount : hint_range(-2.0, 2.0) = 0.4;

void vertex() {
    VERTEX.x += VERTEX.y * skew_amount;
}