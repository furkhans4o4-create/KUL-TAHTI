shader_type canvas_item;
render_mode unshaded;

uniform sampler2D atlas_tex : filter_nearest, repeat_disable;
uniform vec2 glyph_grid = vec2(260.0, 110.0);
uniform float brightness : hint_range(0.5, 3.0) = 1.95;

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
    // Preserve dark negative space instead of covering the entire world with noise.
    float a = lum + (n - 0.5) * 0.021;
    float idx = 0.0;
    if (a > .135) idx = 1.0;          // .
    if (a > .180) idx = 2.0;          // :
    if (a > .225) idx = 3.0;          // -
    if (a > .265) idx = 8.0;          // i
    if (a > .305) idx = 10.0;         // v
    if (a > .360) idx = 11.0;         // Y
    if (a > .430) idx = 12.0;         // o
    if (a > .495) idx = 13.0;         // x
    if (a > .560) idx = 14.0;         // *
    if (a > .630) idx = 15.0;         // %
    if (a > .715) idx = 16.0;         // #
    if (a > .830) idx = 17.0;         // @
    if (gx > 0.13 && gx > gy * 1.20 && a > 0.17) idx = 6.0;
    if (gy > 0.13 && gy > gx * 1.20 && a > 0.17) idx = 3.0;
    if (lum > 0.19 && lum < 0.44 && n > 0.94) idx = 4.0;
    if (lum > 0.19 && lum < 0.44 && n < 0.06) idx = 5.0;
    if (lum > 0.20 && lum < 0.40 && n > 0.78 && n < .86) idx = 18.0;
    vec2 guv = (vec2(mod(idx,16.0), floor(idx/16.0)) + f) / vec2(16.0,2.0);
    float ink = texture(atlas_tex, guv).r;
    vec3 dark = vec3(0.006, 0.011, 0.012);
    vec3 color_ink = min(vec3(1.0), pow(avg, vec3(0.78)) * brightness);
    color_ink += vec3(0.008,0.012,0.014);
    COLOR = vec4(mix(dark, color_ink, ink), 1.0);
}
