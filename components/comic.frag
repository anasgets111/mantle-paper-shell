// Comic-ink finish for an app icon: a slight hand wobble, colours flattened to a few tones, a pencil
// ink line round the silhouette and paper tooth. Runs on the icon node with `padding` for the line;
// the sticker's white cut is cast after it, so the cut sits outside the ink.
uniform float seed;   // per app, so each icon wobbles its own way and holds still between frames
uniform float levels; // tones per icon, 4 to 5
uniform float line;   // ink width in px
uniform float wobble; // hand wobble in px

const vec3 INK = vec3(0.227, 0.212, 0.192);

vec4 at(vec2 p) {
    return mantle_input(p / u_size);
}

void main() {
    vec2 p = v_uv * u_size;
    // Two slow sine fields, about one wave across the icon.
    float f = 6.2832 / max(u_size.x, 1.0);
    vec2 wob = wobble * vec2(sin(p.y * f * 1.3 + seed), cos(p.x * f * 1.1 + seed * 1.7));
    vec2 q = p + wob;

    vec4 c = at(q);
    float outer = 0.0;
    float inner = 1.0;
    for (int i = 0; i < 8; i++) {
        float a = float(i) * 0.7854;
        vec2 d = vec2(cos(a), sin(a));
        outer = max(outer, at(q + d * line).a);
        inner = min(inner, at(q + d * line * 0.35).a);
    }
    // Thresholded, so the line is a hard band rather than two anti-aliasing ramps.
    float ink = smoothstep(0.3, 0.7, outer) * (1.0 - smoothstep(0.3, 0.7, inner));

    vec3 rgb = c.a > 0.001 ? c.rgb / c.a : vec3(0.0);
    // Flatten shading in brightness only, so hues stay the app's own.
    float y = dot(rgb, vec3(0.299, 0.587, 0.114));
    float yq = floor(y * levels + 0.5) / levels;
    rgb = clamp(rgb * (yq / max(y, 0.02)), 0.0, 1.0);
    vec3 g = texture(grain, fract(p / grain_size)).rgb;
    rgb *= 1.0 + (g.r - 0.5) * 0.22 + (g.b - 0.5) * 0.12;

    float a = max(c.a, ink);
    vec3 col = mix(rgb * c.a, INK * a, ink / max(a, 0.001));
    fragColor = vec4(col, a);
}
