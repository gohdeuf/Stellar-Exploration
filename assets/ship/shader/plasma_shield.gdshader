shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, unshaded;

uniform vec4 shield_color : source_color = vec4(0.0, 0.4, 1.0, 0.2); // Plasma-Blau
uniform vec4 hit_color : source_color = vec4(0.3, 0.9, 1.0, 0.8);    // Grelles Treffor-Weißblau
uniform float hit_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float integrity_pct : hint_range(0.0, 1.0) = 1.0;

void fragment() {
    // Fresnel-Effekt sorgt für Star-Trek-Style Leuchtränder
    float fresnel = pow(1.0 - dot(NORMAL, VIEW), 3.0);
    
    // Simuliert das magnetische Plasma-Wabern über 3D-Koordinaten und Zeit
    float plasma_wave = sin(VERTEX.x * 40.0 + TIME * 4.0) * cos(VERTEX.y * 40.0 + TIME * 3.0);
    float active_glow = fresnel * (0.3 + 0.15 * plasma_wave);
    
    vec4 final_color = mix(shield_color, hit_color, hit_intensity);
    
    // Kritisches Flackern, wenn die Magnetfelder/Schildkapazität unter 30% fällt
    if (integrity_pct < 0.3) {
        final_color.a *= step(0.3, sin(TIME * 25.0));
    }

    ALBEDO = final_color.rgb;
    ALPHA = clamp(active_glow + (hit_intensity * 0.6), 0.0, 1.0) * final_color.a;
}
