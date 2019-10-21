#version 430 core

layout(points) in;

layout(triangle_strip, max_vertices = 6) out;

in VertexData {
    vec4 rel_corner;
} vertex_data[];

out vec4 blended_pos;
out flat int signed_orientation_f;

layout(location = 0) uniform vec4 base_pos;
layout(location = 1) uniform vec4 normal;
layout(location = 2) uniform vec4 right;
layout(location = 3) uniform vec4 up;
layout(location = 4) uniform vec4 front;

layout(location = 5) uniform mat4 view;
layout(location = 6) uniform mat4 projection;


layout (std140, binding = 2) uniform StaticCrossSectionData {
    ivec4[0x80][2] selected_edges;
};


const vec4[4][8] corner_offsets = {
    {
        vec4(0, 0, 0, 0),
        vec4(0, 1, 0, 0),
        vec4(0, 0, 1, 0),
        vec4(0, 0, 0, 1),
        vec4(0, 1, 1, 0),
        vec4(0, 1, 0, 1),
        vec4(0, 0, 1, 1),
        vec4(0, 1, 1, 1)
    },
    {
        vec4(0, 0, 0, 0),
        vec4(1, 0, 0, 0),
        vec4(0, 0, 1, 0),
        vec4(0, 0, 0, 1),
        vec4(1, 0, 1, 0),
        vec4(1, 0, 0, 1),
        vec4(0, 0, 1, 1),
        vec4(1, 0, 1, 1)
    },
    {
        vec4(0, 0, 0, 0),
        vec4(1, 0, 0, 0),
        vec4(0, 1, 0, 0),
        vec4(0, 0, 0, 1),
        vec4(1, 1, 0, 0),
        vec4(1, 0, 0, 1),
        vec4(0, 1, 0, 1),
        vec4(1, 1, 0, 1)
    },
    {
        vec4(0, 0, 0, 0),
        vec4(1, 0, 0, 0),
        vec4(0, 1, 0, 0),
        vec4(0, 0, 1, 0),
        vec4(1, 1, 0, 0),
        vec4(1, 0, 1, 0),
        vec4(0, 1, 1, 0),
        vec4(1, 1, 1, 0)
    }
};

const vec3[8] local_corners = {
    vec3(0, 0, 0),
    vec3(1, 0, 0),
    vec3(0, 1, 0),
    vec3(0, 0, 1),
    vec3(1, 1, 0),
    vec3(1, 0, 1),
    vec3(0, 1, 1),
    vec3(1, 1, 1)
};

/*
  const vec3[8] colors = {
  vec3(.0, .8, .0), // 0 green
  vec3(.8, .0, .0), // 1 red
  vec3(.0, .0, .8), // 2 blue
  vec3(.0, .8, .8), // 3 cyan
  vec3(.8, .0, .8), // 4 magenta
  vec3(.8, .8, .0), // 5 yellow
  vec3(.2, .2, .2), // 6 black
  vec3(.7, .7, .7)  // 7 white
  };*/


const ivec2[12] adjacent_corners = {
    ivec2(6, 7),
    ivec2(7, 4),
    ivec2(4, 2),
    ivec2(2, 6),

    ivec2(3, 6),
    ivec2(5, 7),
    ivec2(1, 4),
    ivec2(0, 2),

    ivec2(3, 5),
    ivec2(5, 1),
    ivec2(1, 0),
    ivec2(0, 3),
};



void draw_debug_rectangle(vec4 v, float offset)
{
    gl_Position = vec4(-0.5 + offset, -1, 0, 1);
    //color_f = vec3(v.x, v.x, v.x);
    EmitVertex();
    gl_Position = vec4(-0.5 + offset, -1, 0, 1);
    //color_f = vec3(v.x, v.x, v.x);
    EmitVertex();

    gl_Position = vec4(-0.5 + offset, -0.5, 0, 1);
    //color_f = vec3(v.y, v.y, v.y);
    EmitVertex();

    gl_Position = vec4(-1 + offset, -1, 0, 1);
    //color_f = vec3(v.z, v.z, v.z);
    EmitVertex();

    gl_Position = vec4(-1 + offset, -0.5, 0, 1);
    //color_f = vec3(v.w, v.w, v.w);
    EmitVertex();
    gl_Position = vec4(-1 + offset, -0.5, 0, 1);
    //color_f = vec3(v.w, v.w, v.w);
}



void main()
{
    // TODO these get compiled out, right??
    vec4 pos = gl_in[0].gl_Position;
    vec4 rel_corner = vertex_data[0].rel_corner;

    int unsigned_orientation = int(dot(step(0, -abs(rel_corner)), vec4(0, 1, 2, 3)));
    bool positive_orientation = dot(rel_corner, vec4(1, 1, 1, 1)) > 0;
    // positive_orientation is true for negative basis dirs
    int signed_orientation = int(positive_orientation) * 4 + unsigned_orientation;

    vec4 rel_pos_v = pos - base_pos;

    // TODO doesn't seem to be quite correct, also only very slightly faster?
    if (false) {
        vec4 rel_center = rel_pos_v + vec4(0.5, 0.5, 0.5, 0.5);
        if (abs(dot(rel_center, normal)) > 1 || dot(rel_center, front) > 1) {
            EndPrimitive();
            return;
        }
    }

    vec4[8] rel_pos;
    //bool[8] pos_side;
    int pos_side_b = 0;

    for (int i = 0; i < 8; i++) {
        rel_pos[i] = rel_corner * corner_offsets[unsigned_orientation][i] + rel_pos_v;
        //pos_side[i] = dot(rel_pos[i], normal) > 0;
        pos_side_b += int(dot(rel_pos[i], normal) > 0) << i;
    }

    if ((pos_side_b & 0x80) != 0) {
        pos_side_b = ~pos_side_b & 0xff;
    }


    for (int i = 0; i < 6; i++) {
        int edge = selected_edges[pos_side_b][int(i > 3)][i & 3];
        if (edge == -1) {
            break;
        }

        int corner_a = adjacent_corners[edge][0];
        int corner_b = adjacent_corners[edge][1];

        vec4 diff = rel_pos[corner_a] - rel_pos[corner_b];
        float scale = dot(rel_pos[corner_a], normal) * -1.0 / dot(normal, diff);
        vec4 rel_intersection_point = rel_pos[corner_a] + scale * diff;

        vec4 untransformed_vtx = vec4(
            dot(right, rel_intersection_point),
            dot(up, rel_intersection_point),
            dot(front, rel_intersection_point),
            1
            );

        gl_Position = projection * view * untransformed_vtx;
        //tex_coords = mix(local_corners[corner_a], local_corners[corner_b], scale / length(diff));
        //tex_coords = local_corners[corner_a] + scale * (local_corners[corner_a] - local_corners[corner_b]);
        blended_pos = rel_pos[corner_a] + scale * (rel_pos[corner_a] - rel_pos[corner_b]) + base_pos;
        signed_orientation_f = signed_orientation;
        //cuboid_pos = gl_in[0].gl_Position;
        //rel_corner_pos = rel_corner;
        EmitVertex();
    }

    EndPrimitive();
}


// TODO make an optimized version of this for each of 1x1 vertical cubes, other 1x1 cubes, cuboids (more?)
// use some reserved glsl symbol to add some preprocessor nonsense to dedupe
