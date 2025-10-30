shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform sampler2D albedo_texture : source_color;
uniform float fade_distance : hint_range(0.0, 20.0) = 5.0;
uniform float fade_power : hint_range(0.5, 5.0) = 2.0;
uniform vec4 fog_color : source_color = vec4(0.646, 0.656, 0.67, 1.0);

void fragment() {
    // Get the texture color
    vec4 tex_color = texture(albedo_texture, UV);
    
    // Calculate distance from center (0.5, 0.5) in UV space
    vec2 center = vec2(0.5, 0.5);
    float dist = distance(UV, center);
    
    // Calculate fade based on distance from center
    // 0.5 is the max distance from center to edge in UV space
    float fade_start = 0.5 - (fade_distance / 20.0); // Normalize fade_distance
    float fade = smoothstep(fade_start, 0.5, dist);
    fade = pow(fade, fade_power);
    
    // Mix texture with fog color based on fade
    vec3 final_color = mix(tex_color.rgb, fog_color.rgb, fade);
    float final_alpha = mix(tex_color.a, 0.0, fade);
    
    ALBEDO = final_color;
    ALPHA = final_alpha;
}