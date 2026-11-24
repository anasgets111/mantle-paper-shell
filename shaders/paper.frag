// Paper finish for a node's painted subtree: grain, a torn-fibre rim and optional pencil hatching.
// Samples img/grain.png (R fine tooth, G mottle, B fibres) tiled at 1:1, so grain never stretches.
uniform float grain_amt;     // fine tooth strength, 0..1
uniform float mottle_amt;    // soft blotches, 0..1
uniform float rim;           // px of pale torn fibres inside the edge; 0 for none
uniform float hatch;         // 0..1 pencil hatching coverage
uniform vec4 hatch_color;    // straight RGBA
uniform float hatch_spacing; // px between strokes

void main() {
    vec4 c = mantle_input(v_uv);
    if (c.a <= 0.001) {
        fragColor = c;
        return;
    }
    vec2 p = v_uv * u_size;
    vec3 g = texture(grain, fract(p / grain_size)).rgb;
    float m = texture(grain, fract(p / (grain_size * 4.0) + 0.37)).g;
    vec3 rgb = c.rgb * (1.0 + (g.r - 0.5) * grain_amt + (m - 0.5) * mottle_amt + (g.b - 0.5) * grain_amt * 0.6);
    float d = mantle_sdf(p);

    if (hatch > 0.0) {
        float u = (p.x - p.y) * 0.7071;
        float v = (p.x + p.y) * 0.7071;
        // Each stroke wanders a little and breaks where the tooth is high, like graphite.
        float wobble = (texture(grain, fract(vec2(floor(u / hatch_spacing) * 0.137, v / 300.0))).g - 0.5) * 1.6;
        float off = abs(fract((u + wobble) / hatch_spacing) - 0.5) * hatch_spacing;
        float stroke = (1.0 - smoothstep(0.3, 0.95, off)) * (0.55 + 0.45 * g.r);
        float inside = 1.0 - smoothstep(-3.5, -1.5, d);
        float a = clamp(stroke * inside * hatch * hatch_color.a, 0.0, 1.0);
        rgb = mix(rgb, hatch_color.rgb * c.a, a);
    }

    if (rim > 0.0) {
        float edge = smoothstep(-rim, 0.0, d);
        float fib = texture(grain, fract(p / grain_size * 1.7)).b;
        rgb = mix(rgb, vec3(0.985, 0.975, 0.95) * c.a, edge * (0.45 + 0.55 * fib));
    }
    fragColor = vec4(rgb, c.a);
}
