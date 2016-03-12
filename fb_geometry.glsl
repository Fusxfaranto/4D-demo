#version 330 core
layout (points) in;
layout (triangle_strip, max_vertices = 4) out;

out vec2 tex_coords; 

void main()
{
    gl_Position = vec4(gl_in[0].gl_Position.z, gl_in[0].gl_Position.y, 1, 1);
    //gl_Position = vec4(1, 1, 1, 1);
    tex_coords = vec2(1, 0);
    EmitVertex();
    gl_Position = vec4(gl_in[0].gl_Position.z, gl_in[0].gl_Position.w, 1, 1);
    //gl_Position = vec4(1, 0, 1, 1);
    tex_coords = vec2(1, 1);
    EmitVertex();
    gl_Position = vec4(gl_in[0].gl_Position.x, gl_in[0].gl_Position.y, 1, 1);
    //gl_Position = vec4(0, 1, 1, 1);
    tex_coords = vec2(0, 0);
    EmitVertex();
    gl_Position = vec4(gl_in[0].gl_Position.x, gl_in[0].gl_Position.w, 1, 1);
    //gl_Position = vec4(0, 0, 1, 1);
    tex_coords = vec2(0, 1);
    EmitVertex();
    EndPrimitive();
}
