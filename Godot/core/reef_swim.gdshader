shader_type canvas_item;
uniform float swim_clock = 0.0;
void fragment() {
 vec2 uv = UV;
 // Strong tail beat with a stable head; local fin flutter adds a second rhythm.
 float tail = 1.0-smoothstep(0.18,0.66,uv.x);
 uv.y += sin(swim_clock*11.0+uv.x*7.0)*0.12*tail;
 uv.x += sin(swim_clock*11.0)*0.025*tail;
 float fin = exp(-pow((uv.x-0.62)*10.0,2.0)-pow((uv.y-0.70)*9.0,2.0));
 uv.y += sin(swim_clock*17.0)*0.026*fin;
 COLOR = texture(TEXTURE,uv);
}
