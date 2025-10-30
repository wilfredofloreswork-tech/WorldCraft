shader_type spatial;
render_mode cull_back, ambient_light_disabled, specular_disabled;

uniform bool  snap_vertices = false;     // Snap mesh to grid at render-time (blocky silhouette)
uniform float voxel_size    = 0.1;       // World-ish size of each “voxel”
uniform bool  use_triplanar = true;      // Tri-planar texture mapping
uniform sampler2D albedo_tex : source_color;
uniform float tex_scale     = 1.0;       // Bigger = larger texels on each face

uniform int   light_steps   = 4;         // 1 = smooth, 3–6 = chunky bands
uniform int   shade_steps   = 8;         // Posterize final shade (optional)
uniform float rim_power     = 0.0;       // >0 adds a hard rim light accent

// Optional color tint if you want to override texture a bit
uniform vec3 tint = vec3(1.0);

// Varyings
varying vec3 v_local_pos;
varying vec3 v_local_normal;

// Snap a value to a grid
float snap_f(float v, float s) {
    return floor(v / s) * s;
}

vec3 snap_v(vec3 v, float s) {
    return floor(v / s) * s;
}

// Tri-planar sampling with snapped coords per “voxel”
vec3 triplanar_color(vec3 local_pos, vec3 n, float scale) {
    vec3 an = abs(n) + 1e-5;
    vec3 w  = an / (an.x + an.y + an.z);

    // Snap the sampling coords so each voxel gets a constant UV footprint
    vec3 p = snap_v(local_pos, voxel_size) / max(scale, 1e-6);

    vec2 uvx = p.zy; // X face uses YZ
    vec2 uvy = p.xz; // Y face uses XZ
    vec2 uvz = p.xy; // Z face uses XY

    vec3 cx = texture(albedo_tex, uvx).rgb;
    vec3 cy = texture(albedo_tex, uvy).rgb;
    vec3 cz = texture(albedo_tex, uvz).rgb;

    return cx * w.x + cy * w.y + cz * w.z;
}

// Quantize a 0..1 value into N steps
float quantize01(float v, int steps) {
    if (steps <= 1) return v;
    float s = float(steps);
    return floor(v * s) / s;
}

void vertex() {
    v_local_pos = VERTEX;
    v_local_normal = NORMAL;

    if (snap_vertices && voxel_size > 0.0) {
        VERTEX = snap_v(VERTEX, voxel_size);
        // Keep normals “boxy” by snapping to dominant axis
        vec3 n = NORMAL;
        vec3 an = abs(n);
        if (an.x > an.y && an.x > an.z) n = vec3(sign(n.x), 0.0, 0.0);
        else if (an.y > an.x && an.y > an.z) n = vec3(0.0, sign(n.y), 0.0);
        else n = vec3(0.0, 0.0, sign(n.z));
        NORMAL = normalize(n);
    }
}

void fragment() {
    // Base color: tri-planar (snapped) or flat tint
    vec3 base_col = use_triplanar ? triplanar_color(v_local_pos, NORMAL, tex_scale) : tint;

    // Minimal ambient so unlit faces aren’t pure black
    float hemi = 0.15;

    // “Rim” accent (optional), quantized so it feels chunky
    float rim = 0.0;
    if (rim_power > 0.0) {
        float v = 1.0 - max(dot(normalize(NORMAL), normalize(VIEW)), 0.0);
        rim = pow(v, max(rim_power, 0.001));
        rim = quantize01(rim, max(light_steps, 1));
    }

    // Store color; lighting() will add bands
    ALBEDO = clamp(base_col * tint, 0.0, 1.0);
    EMISSION = rim * ALBEDO * 0.3; // subtle colored rim
    AO = 1.0;
    ROUGHNESS = 1.0;
    METALLIC = 0.0;

    // Posterize the base a touch for that “chunky” palette feel
    if (shade_steps > 1) {
        ALBEDO = floor(ALBEDO * float(shade_steps)) / float(shade_steps);
    }

    // Cheap ambient
    EMISSION += ALBEDO * hemi;
}

// Custom per-light function to band the shading like voxels
void light() {
    // Make normals face-axis dominant for boxy light rolloff
    vec3 n = NORMAL;
    vec3 an = abs(n);
    if (an.x > an.y && an.x > an.z) n = vec3(sign(n.x), 0.0, 0.0);
    else if (an.y > an.x && an.y > an.z) n = vec3(0.0, sign(n.y), 0.0);
    else n = vec3(0.0, 0.0, sign(n.z));

    float ndl = max(dot(n, LIGHT), 0.0);
    ndl = quantize01(ndl, max(light_steps, 1));

    // Engine multiplies DIFFUSE_LIGHT by ALBEDO later
    DIFFUSE_LIGHT = LIGHT_COLOR * ndl;
    SPECULAR_LIGHT = vec3(0.0);
}
