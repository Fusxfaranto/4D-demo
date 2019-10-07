#version 430 core

in flat vec4 cuboid_pos;
in vec3 tex_coords;
in flat int id;

out vec4 color;

const vec3[] colors = {
    vec3(0.90, 0.10, 0.29), //  0 red
    vec3(0.24, 0.71, 0.29), //  1 green
    vec3(1.00, 0.88, 0.10), //  2 yellow
    vec3(0.00, 0.51, 0.78), //  3 blue
    vec3(0.96, 0.51, 0.19), //  4 orange
    vec3(0.57, 0.12, 0.71), //  5 purple
    vec3(0.27, 0.94, 0.94), //  6 cyan
    vec3(0.94, 0.20, 0.90), //  7 magenta
    vec3(0.82, 0.96, 0.24), //  8 lime
    vec3(0.98, 0.75, 0.75), //  9 pink
    vec3(0.00, 0.50, 0.50), // 10 teal
    vec3(0.90, 0.75, 1.00), // 11 lavender
    vec3(0.67, 0.43, 0.16),
    vec3(1.00, 0.98, 0.78),
    vec3(0.50, 0.00, 0.00),
    vec3(0.67, 1.00, 0.76),
    vec3(0.50, 0.50, 0.00),
    vec3(1.00, 0.84, 0.71),
    vec3(0.00, 0.00, 0.50),
    vec3(0.50, 0.50, 0.50),
    vec3(1.00, 1.00, 1.00),
    vec3(0.00, 0.00, 0.00)
};

const vec3[] colors_alt = {
    vec3(0.35, 0.30, 0.33),
    vec3(0.22, 0.13, 0.09),
    vec3(0.22, 0.13, 0.09),
    vec3(0.22, 0.13, 0.09),
    vec3(0.22, 0.13, 0.09),
    vec3(0.20, 0.10, 0.08),
    vec3(0.20, 0.10, 0.08),
    vec3(0.20, 0.10, 0.08),
    vec3(0.26, 0.13, 0.11),
    vec3(0.26, 0.13, 0.11),
    vec3(0.26, 0.13, 0.11),
    vec3(0.26, 0.13, 0.11),
    vec3(0.22, 0.13, 0.09),
    vec3(0.20, 0.10, 0.08),
    vec3(0.20, 0.10, 0.08),
    vec3(0.20, 0.10, 0.08),
    vec3(0.26, 0.13, 0.11),
    vec3(0.26, 0.13, 0.11),
    vec3(0.26, 0.13, 0.11),
    vec3(0.22, 0.13, 0.09),
    vec3(0.22, 0.13, 0.09),
    vec3(0.22, 0.13, 0.09),
    vec3(0.22, 0.13, 0.09),
    vec3(0.20, 0.10, 0.08),
    vec3(0.20, 0.10, 0.08),
    vec3(0.20, 0.10, 0.08),
    vec3(0.26, 0.13, 0.11),
    vec3(0.26, 0.13, 0.11),
    vec3(0.26, 0.13, 0.11),
    vec3(0.22, 0.13, 0.09),
    vec3(0.22, 0.13, 0.09),
    vec3(0.22, 0.13, 0.09),
    vec3(0.22, 0.13, 0.09),
    vec3(0.20, 0.10, 0.08),
    vec3(0.20, 0.10, 0.08),
    vec3(0.20, 0.10, 0.08),
    vec3(0.26, 0.13, 0.11),
    vec3(0.26, 0.13, 0.11),
    vec3(0.26, 0.13, 0.11),
    vec3(0.42, 0.16, 0.09)
};

#define PI 3.1415926535897932384626433832795

void main()
{
    //color = vec4(color_f, 1.0);

    if (true) {
        const uvec4 seeds = uvec4(
            267840417,
            2412019164,
            3434269503,
            354219804
            );
        // const uvec3 seeds = uvec3(
        //     0,
        //     0,
        //     0
        //     );

        const uvec4 factors = uvec4(
            62549,
            75689,
            27073,
            51407
            );

        uvec4 v1 = ((uvec4(tex_coords * 8, 0) + uvec4(1, 1, 1, 1)) * factors) ^ seeds;

        //uvec4 v1 = uvec4(0, 0, 0, 0);
        uvec4 v2 = ((uvec4(abs(cuboid_pos))) * factors) ^ seeds;
        uvec4 v = v1 ^ v2;


        //uvec3 r = (1103515245 * v + 12345) & 0x7fffffff;

        v = ((v & 0xffff) << 16) | ((v >> 16) & 0xffff);

        uint r = v.x ^ v.y ^ v.z ^ v.w;
        //vec3 c = colors_alt[r % colors_alt.length];
        vec3 c = colors[id];
        float a = ((float((r >> 16) & 255) - 127) / 255.) * 0.1;
        color = vec4(
            clamp(
                c + a * vec3(1, 1, 1),
                vec3(0, 0, 0),
                vec3(1, 1, 1)
                ),
            1.0);
    } else {
        vec3 f = vec3(
            sin(tex_coords.x * 5 * PI),
            sin(tex_coords.y * 5 * PI + PI / 3),
            sin(tex_coords.z * 5 * PI + 2 * PI / 3)
            ) * 0.3 + 0.6;

        color = vec4(mix(colors[id], colors[id + 8], length(f)), 1.0);
    }
}
