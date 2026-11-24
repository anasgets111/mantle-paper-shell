// Re-inks a tray pixmap drawn for a dark bar: pale, unsaturated pixels become pencil ink, so a white
// glyph reads on paper while a coloured logo keeps its colours.
void main() {
    vec4 c = mantle_input(v_uv);
    if (c.a <= 0.001) {
        fragColor = c;
        return;
    }
    vec3 rgb = c.rgb / c.a;
    float hi = max(rgb.r, max(rgb.g, rgb.b));
    float lo = min(rgb.r, min(rgb.g, rgb.b));
    float pale = smoothstep(0.55, 0.9, hi) * (1.0 - smoothstep(0.12, 0.3, hi - lo));
    vec3 ink = vec3(0.227, 0.212, 0.192);
    fragColor = vec4(mix(rgb, ink, pale) * c.a, c.a);
}
