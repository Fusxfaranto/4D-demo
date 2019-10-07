#version 330 core

in vec2 tex_coords;

out vec4 color;

uniform sampler2D tex;

#define OUTER_THRESH 0.48
#define INNER_THRESH 0.498

void main()
{ 
    color = texture(tex, tex_coords);
    //color = vec4(1, 1, 1, 1);

    vec2 outer_clamp = clamp(tex_coords, OUTER_THRESH, 1 - OUTER_THRESH);
    if (all(equal(tex_coords, outer_clamp))) {
        vec2 inner_clamp = clamp(tex_coords, INNER_THRESH, 1 - INNER_THRESH);
        if (any(equal(tex_coords, inner_clamp))) {
            color = 1 - color;
        }
    }
}
