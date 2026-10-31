shader_type canvas_item;
render_mode unshaded;

uniform sampler2D atlas_tex : filter_nearest, repeat_disable;
uniform vec2 glyph_grid = vec2(205.0, 95.0);
uniform float brightness : hint_range(0.5, 3.0) = 1.7;

float luma(vec3 c) {
    return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

float hash21(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
    vec2 coords = UV * glyph_grid;
    vec2 cell = floor(coords);
    vec2 in_cell = fract(coords);
    vec2 sample_uv = (cell + 0.5) / glyph_grid;
    vec2 dx = vec2(0.44 / glyph_grid.x, 0.0);
    vec2 dy = vec2(0.0, 0.44 / glyph_grid.y);
    vec3 source = texture(TEXTURE, sample_uv).rgb;
    vec3 left_c = texture(TEXTURE, sample_uv - dx).rgb;
    vec3 right_c = texture(TEXTURE, sample_uv + dx).rgb;
    vec3 above_c = texture(TEXTURE, sample_uv - dy).rgb;
    vec3 below_c = texture(TEXTURE, sample_uv + dy).rgb;

    vec3 avg = (source * 2.5 + left_c + right_c + above_c + below_c) / 6.5;
    float lum = luma(avg);
    float rand = hash21(cell);
    float dx_l = abs(luma(left_c) - luma(right_c));
    float dy_l = abs(luma(above_c) - luma(below_c));
    float green = max(0.0, avg.g - max(avg.r, avg.b) * 0.86);
    float blue = max(0.0, avg.b - avg.r * 1.20);
    float warm = max(0.0, avg.r - avg.g * 1.20);
    float glyph = 0.0;
    float phase = sin(TIME * 1.35 + cell.x * 0.27 + cell.y * 0.23);

    // Material-aware glyph selection: river, leaves, armor and earth use
    // distinct text rhythms instead of one brightness-to-noise lookup.
    if (blue > 0.024 && avg.b > avg.g * 0.91) {
        glyph = 18.0; // ~ wave
        if (rand > 0.56 + 0.1 * phase) glyph = 19.0; // = ripples
        if (rand < 0.19) glyph = 3.0; // -
        if (rand < 0.34 + 0.10 * phase) glyph = 0.0;
        if (lum < 0.10 && rand < 0.62) glyph = 0.0;
    } else if (green > 0.025) {
        glyph = 8.0; // i
        if (rand > 0.30) glyph = 10.0; // v
        if (rand > 0.58) glyph = 11.0; // Y
        if (rand > 0.81) glyph = 14.0; // *
        if (lum > 0.35) glyph = 16.0; // # sunlight on leaves
        if (lum < 0.30 && rand < 0.32) glyph = 0.0;
        if (lum < 0.21 && rand < 0.66) glyph = 0.0;
        if (lum < 0.12 && rand < 0.86) glyph = 0.0;
    } else if (warm > 0.03 || lum > 0.31) {
        glyph = 13.0; // x stone / leather
        if (lum > 0.43) glyph = 15.0; // %
        if (lum > 0.60) glyph = 16.0; // #
        if (lum > 0.76) glyph = 17.0; // @
        if (lum < 0.20) glyph = 3.0;
    } else {
        // Forest-floor negative space is deliberate, but still textured.
        glyph = 0.0;
        if (lum > 0.065 && rand > 0.78) glyph = 1.0;
        if (lum > 0.10 && rand > 0.87) glyph = 2.0;
        if (lum > 0.16 && rand > 0.94) glyph = 8.0;
    }

    if (max(dx_l, dy_l) > 0.19 && lum > 0.14) {
        glyph = dx_l > dy_l ? 6.0 : 3.0;
    }

    vec2 atlas_uv = (vec2(mod(glyph, 16.0), floor(glyph / 16.0)) + in_cell) / vec2(16.0, 2.0);
    float pixels = texture(atlas_tex, atlas_uv).r;

    vec3 text_color = pow(max(avg, vec3(0.0)), vec3(0.70)) * brightness;
    if (blue > 0.024 && avg.b > avg.g * 0.91) {
        text_color = max(text_color, vec3(0.11, 0.32, 0.48));
    } else if (green > 0.025) {
        text_color = max(text_color, vec3(0.15, 0.27, 0.16));
    }
    text_color = min(vec3(1.0), text_color);
    vec3 background = vec3(0.009, 0.019, 0.021);
    // The HUD is rendered in another CanvasItem and is never post-processed.
    COLOR = vec4(mix(background, text_color, pixels), 1.0);
}
