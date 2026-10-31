shader_type canvas_item;
render_mode unshaded;

uniform sampler2D atlas_tex : filter_nearest, repeat_disable;
uniform vec2 glyph_grid = vec2(260.0, 110.0);
uniform float brightness : hint_range(0.5, 3.0) = 1.7;

float luminance(vec3 v) { return dot(v, vec3(0.2126, 0.7152, 0.0722)); }
float noise21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
    vec2 xy = UV * glyph_grid;
    vec2 cell = floor(xy);
    vec2 f = fract(xy);
    vec2 uv = (cell + 0.5) / glyph_grid;
    vec2 ox = vec2(0.48 / glyph_grid.x, 0.0);
    vec2 oy = vec2(0.0, 0.48 / glyph_grid.y);
    vec3 src = texture(TEXTURE, uv).rgb;
    vec3 l = texture(TEXTURE, uv-ox).rgb;
    vec3 r = texture(TEXTURE, uv+ox).rgb;
    vec3 t = texture(TEXTURE, uv-oy).rgb;
    vec3 b = texture(TEXTURE, uv+oy).rgb;
    vec3 avg = (src * 3.0 + l+r+t+b) / 7.0;
    float lum = luminance(avg);
    float n = noise21(cell);
    float gx = abs(luminance(l) - luminance(r));
    float gy = abs(luminance(t) - luminance(b));
    float a = lum + (n - 0.5) * 0.044;
    float idx = 0.0;
    if (a > .035) idx = 1.0;          // .
    if (a > .075) idx = 2.0;          // :
    if (a > .110) idx = 3.0;          // -
    if (a > .145) idx = 8.0;          // i
    if (a > .185) idx = 10.0;         // v
    if (a > .230) idx = 11.0;         // Y
    if (a > .280) idx = 12.0;         // o
    if (a > .345) idx = 13.0;         // x
    if (a > .410) idx = 14.0;         // *
    if (a > .495) idx = 15.0;         // %
    if (a > .590) idx = 16.0;         // #
    if (a > .720) idx = 17.0;         // @
    if (gx > 0.090 && gx > gy * 1.20 && a > 0.07) idx = 6.0;
    if (gy > 0.09 && gy > gx * 1.20 && a > 0.07) idx = 3.0;
    if (lum > 0.07 && lum < 0.38 && n > 0.88) idx = 4.0;
    if (lum > 0.07 && lum < 0.38 && n < 0.11) idx = 5.0;
    if (lum > 0.10 && lum < 0.28 && n > 0.73 && n < .83) idx = 18.0;
    vec2 guv = (vec2(mod(idx,16.0), floor(idx/16.0)) + f) / vec2(16.0,2.0);
    float ink = texture(atlas_tex, guv).r;
    vec3 dark = avg * 0.035;
    vec3 color_ink = min(vec3(1.0), pow(avg, vec3(0.76)) * brightness);
    color_ink += vec3(0.008,0.012,0.014);
    COLOR = vec4(mix(dark, color_ink, ink), 1.0);
}
