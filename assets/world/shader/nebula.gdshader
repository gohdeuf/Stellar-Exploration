shader_type fog;

uniform vec3 fog_colour : source_color = vec3(0.18, 0.28, 0.72);
uniform vec3 fog_colour_secondary : source_color = vec3(0.72, 0.20, 0.52);
uniform vec3 fog_colour_accent : source_color = vec3(0.12, 0.68, 0.76);
uniform float density : hint_range(0.0, 0.2, 0.001) = 0.03;
uniform float edge_fade : hint_range(1.0, 300.0, 1.0) = 35.0;
uniform float emission_strength : hint_range(0.0, 3.0, 0.01) = 0.35;
uniform float drift_speed : hint_range(0.0, 0.1, 0.001) = 0.006;
uniform float color_drift_speed : hint_range(0.0, 0.1, 0.001) = 0.012;
uniform vec3 cloud_scale = vec3(5.0, 3.0, 5.0);

float hash_3d(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

vec2 worley_noise(vec3 p) {
	vec3 cell = floor(p);
	vec3 local = fract(p);
	float nearest = 10.0;
	float second_nearest = 10.0;

	for (int z = -1; z <= 1; z++) {
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec3 neighbor = vec3(float(x), float(y), float(z));
				vec3 feature_cell = cell + neighbor;
				vec3 feature = vec3(
					hash_3d(feature_cell + vec3(17.1, 3.7, 11.8)),
					hash_3d(feature_cell + vec3(5.2, 19.3, 7.1)),
					hash_3d(feature_cell + vec3(13.4, 2.6, 23.7))
				);
				float distance_to_feature = length(neighbor + feature - local);
				if (distance_to_feature < nearest) {
					second_nearest = nearest;
					nearest = distance_to_feature;
				} else if (distance_to_feature < second_nearest) {
					second_nearest = distance_to_feature;
				}
			}
		}
	}
	return vec2(nearest, second_nearest);
}

void fog() {
	vec3 p = UVW * cloud_scale;
	p += vec3(TIME * drift_speed, 0.0, TIME * drift_speed * 0.6);

	vec2 warp = worley_noise(p * 0.48 + vec3(0.0, TIME * drift_speed, 0.0));
	p += vec3(warp.x - 0.5, warp.y - 0.5, warp.x - warp.y) * 1.35;

	vec2 cells = worley_noise(p);
	vec2 fine_cells = worley_noise(p * vec3(2.3, 1.65, 2.3) + 4.7);
	vec2 micro_cells = worley_noise(p * vec3(5.2, 3.4, 5.2) - 8.1);
	float cloud_body = 1.0 - smoothstep(0.16, 0.9, cells.x);
	float fine_clouds = 1.0 - smoothstep(0.18, 0.92, fine_cells.x);
	float micro_clouds = 1.0 - smoothstep(0.2, 0.95, micro_cells.x);

	float coarse_ridges = 1.0 - smoothstep(0.018, 0.19, cells.y - cells.x);
	float fine_ridges = 1.0 - smoothstep(0.012, 0.13, fine_cells.y - fine_cells.x);
	float micro_ridges = 1.0 - smoothstep(0.008, 0.09, micro_cells.y - micro_cells.x);
	float filaments = max(
		coarse_ridges * 0.55,
		max(fine_ridges * 0.78, micro_ridges * 0.48));
	float cloud_detail = cloud_body * (0.48 + fine_clouds * 0.34 + micro_clouds * 0.18);
	float filament_detail = filaments * (0.3 + cloud_body * 0.7);
	float color_phase = fract(
		(cells.x * 0.48 + fine_cells.x * 0.34 + micro_cells.x * 0.18) * 0.9
		+ TIME * color_drift_speed);
	vec3 palette_weights = max(
		cos(TAU * color_phase + vec3(0.0, 2.094, 4.189)),
		vec3(0.0));
	palette_weights /= max(
		palette_weights.x + palette_weights.y + palette_weights.z,
		0.001);
	vec3 nebula_color =
		fog_colour * palette_weights.x
		+ fog_colour_secondary * palette_weights.y
		+ fog_colour_accent * palette_weights.z;
	float inside_volume = 1.0 - smoothstep(-edge_fade, 0.0, SDF);

	ALBEDO = nebula_color;
	EMISSION = nebula_color * emission_strength
		* (0.25 + cloud_detail * 0.8 + filament_detail * 2.0);
	DENSITY = density * inside_volume
		* (0.08 + cloud_detail * 0.88 + filament_detail * 1.35);
}
