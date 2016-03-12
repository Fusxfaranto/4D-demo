#version 330 core
  
layout (location = 0) in vec3 position;
layout (location = 1) in vec3 color_in;
layout (location = 2) in vec2 tex_coords_in;

out vec3 color_f;
out vec2 tex_coords;

uniform mat4 view;
uniform mat4 projection;

void main()
{
    gl_Position = projection * view * vec4(position, 1.0);
    //color_f = position + vec3(0.5, 0.5, 0);
    color_f = color_in;
    tex_coords = tex_coords_in;
}
