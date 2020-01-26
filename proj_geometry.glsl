#version 430 core

layout(lines) in;

layout(triangle_strip, max_vertices = 4) out;

in VertexData {
    vec3 color;
    //float width;
} vertex_data[];

uniform mat4 view;
uniform mat4 projection;

out vec3 color_f;

void main()
{
    vec4[2] view_pos;
    view_pos[0] = view * gl_in[0].gl_Position;
    view_pos[1] = view * gl_in[1].gl_Position;

    float width = 0.013;
    vec4 shift = vec4(width * normalize(cross(
        vec3(0, 0, 1),
        (view_pos[0] - view_pos[1]).xyz
        )), 0.0);

    color_f = vertex_data[0].color;
    gl_Position = projection * (view_pos[0] + shift);
    EmitVertex();

    color_f = vertex_data[0].color;
    gl_Position = projection * (view_pos[0] - shift);
    EmitVertex();

    color_f = vertex_data[1].color;
    gl_Position = projection * (view_pos[1] + shift);
    EmitVertex();

    color_f = vertex_data[1].color;
    gl_Position = projection * (view_pos[1] - shift);
    EmitVertex();

    EndPrimitive();
}
