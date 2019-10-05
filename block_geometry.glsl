#version 430 core

layout(points) in;

layout(triangle_strip, max_vertices = 6) out;

in VertexData {
    vec4 rel_corner;
} vertex_data[];

out FragData {
    vec3 color_f;
};

layout(location = 0) uniform vec4 base_pos;
layout(location = 1) uniform vec4 normal;
layout(location = 2) uniform vec4 right;
layout(location = 3) uniform vec4 up;
layout(location = 4) uniform vec4 front;

layout(location = 5) uniform mat4 view;
layout(location = 6) uniform mat4 projection;

layout(location = 7) uniform int[8][8][6] edge_ordering;


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

    float closest_neg_dist = -1e20;
    int closest = -1;
    int any_nonnegative = 0;

    float orientation_factor = positive_orientation ? 1 : -1;
    for (int i = 0; i < 8; i++) {
        rel_pos[i] = orientation_factor * corner_offsets[unsigned_orientation][i] + rel_pos_v;
        //pos_side[i] = dot(rel_pos[i], normal) > 0;
        float signed_dist = dot(rel_pos[i], normal);
        any_nonnegative |= int(signed_dist >= 0);

        if (signed_dist < 0 && signed_dist > closest_neg_dist) {
            closest = i;
            closest_neg_dist = signed_dist;
        }
    }

    if (closest == -1 || any_nonnegative == 0) {
        if (false) {
            vec4 v = vec4(1, 1, 1, 1) * any_nonnegative;
            float offset = 0.5;

            gl_Position = vec4(-0.5 + offset, -1, 0, 1);
            color_f = vec3(v.x, v.x, v.x);
            EmitVertex();
            gl_Position = vec4(-0.5 + offset, -1, 0, 1);
            color_f = vec3(v.x, v.x, v.x);
            EmitVertex();

            gl_Position = vec4(-0.5 + offset, -0.5, 0, 1);
            color_f = vec3(v.y, v.y, v.y);
            EmitVertex();

            gl_Position = vec4(-1 + offset, -1, 0, 1);
            color_f = vec3(v.z, v.z, v.z);
            EmitVertex();

            gl_Position = vec4(-1 + offset, -0.5, 0, 1);
            color_f = vec3(v.w, v.w, v.w);
            EmitVertex();
            gl_Position = vec4(-1 + offset, -0.5, 0, 1);
            color_f = vec3(v.w, v.w, v.w);
            EmitVertex();
        }
        EndPrimitive();
        return;
    }

    if (true) {
        for (int i = 0; i < 6; i++) {
            int edge = edge_ordering[signed_orientation][closest][i];
            if (edge == -1) {
                break;
            }

            int corner_a = adjacent_corners[edge][0];
            int corner_b = adjacent_corners[edge][1];
            
            color_f = colors[signed_orientation];
            //color_f = colors[closest];
            //color_f = vec3(1, 0, 0);

            // this is hopefully always true
            // assert(pos_side[corner_a] != pos_side[corner_b]);
            // if (sign(dot(rel_pos[corner_a], normal)) == sign(dot(rel_pos[corner_b], normal))) {
            //     //break;
            //     color_f = vec3(0, 0, 1);
            // }

            //color_f *= edge / 11.0;
            //color_f = colors[edge];
            
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
            EmitVertex();
        }
    } else if (true) {
        for (int i = 0; i < 1; i++) {

            //vec4 v = corner_offsets[unsigned_orientation][1][3];
            vec4 v = vec4(1, 1, 1, 1);
            //vec4 v = step(0, -abs(rel_corner));
            //vec4 v = abs(sign(rel_pos[0][1] - rel_pos[0][3]));
            //vec4 v = vec4(pos_side[1]);
            //vec4 v = rel_pos[0] * normal;
            //vec4 v = 0.5 + 0.5 * tanh(0.5 * up);

            if (edge_ordering[signed_orientation][i][0] == 3) {
                v.x = 0;
            }
            if (edge_ordering[signed_orientation][i][1] == 11) {
                v.y = 0;
            }
            if (edge_ordering[signed_orientation][i][2] == 1) {
                v.z = 0;
            }
            if (edge_ordering[signed_orientation][i][3] == 9) {
                v.w = 0;
            }

            float offset = 0.5 * i;

            //if (any(pos_side[1])) {
            if (true) {
                gl_Position = vec4(-0.5 + offset, -1, 0, 1);
                color_f = vec3(v.x, v.x, v.x);
                EmitVertex();
                gl_Position = vec4(-0.5 + offset, -1, 0, 1);
                color_f = vec3(v.x, v.x, v.x);
                EmitVertex();

                gl_Position = vec4(-0.5 + offset, -0.5, 0, 1);
                color_f = vec3(v.y, v.y, v.y);
                EmitVertex();

                gl_Position = vec4(-1 + offset, -1, 0, 1);
                color_f = vec3(v.z, v.z, v.z);
                EmitVertex();

                gl_Position = vec4(-1 + offset, -0.5, 0, 1);
                color_f = vec3(v.w, v.w, v.w);
                EmitVertex();
                gl_Position = vec4(-1 + offset, -0.5, 0, 1);
                color_f = vec3(v.w, v.w, v.w);
                EmitVertex();
            }
        }
    } else {
        vec4 v = vec4(1, 1, 1, 1);


        // if (adjacent_corners[9][0] != 4) {
        //     v.x = 0;
        // }
        // if (adjacent_corners[9][1] != 7) {
        //     v.y = 0;
        // }
        // if (adjacent_corners[11][0] != 6) {
        //     v.z = 0;
        // }
        // if (adjacent_corners[11][1] != 7) {
        //     v.w = 0;
        // }


        float offset = 0;

        gl_Position = vec4(-0.5 + offset, -1, 0, 1);
        color_f = vec3(v.x, v.x, v.x);
        EmitVertex();
        gl_Position = vec4(-0.5 + offset, -1, 0, 1);
        color_f = vec3(v.x, v.x, v.x);
        EmitVertex();

        gl_Position = vec4(-0.5 + offset, -0.5, 0, 1);
        color_f = vec3(v.y, v.y, v.y);
        EmitVertex();

        gl_Position = vec4(-1 + offset, -1, 0, 1);
        color_f = vec3(v.z, v.z, v.z);
        EmitVertex();

        gl_Position = vec4(-1 + offset, -0.5, 0, 1);
        color_f = vec3(v.w, v.w, v.w);
        EmitVertex();
        gl_Position = vec4(-1 + offset, -0.5, 0, 1);
        color_f = vec3(v.w, v.w, v.w);
        EmitVertex();
    }

    EndPrimitive();
}


// TODO make an optimized version of this for each of 1x1 vertical cubes, other 1x1 cubes, cuboids (more?)
// use some reserved glsl symbol to add some preprocessor nonsense to dedupe
