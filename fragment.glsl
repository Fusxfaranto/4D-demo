#version 330 core

in vec3 color_f;
in vec2 tex_coords;

out vec4 color;

uniform sampler2D tex1;
uniform sampler2D tex2;

void main()
{
    color = vec4(color_f, 1.0);
    //color = mix(texture(tex1, tex_coords), texture(tex2, tex_coords), 0.7);
}
