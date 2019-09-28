#version 430 core

layout(points) in;

// TODO max_vertices??
layout(triangle_strip, max_vertices = 9) out;

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

layout(location = 5) uniform ivec2[12] adjacent_corners;

layout(location = 17) uniform mat4 view;
layout(location = 18) uniform mat4 projection;


const mat4[4][2] corner_offsets = mat4[4][2](
    mat4[2](
        mat4(
            vec4(0, 0, 0, 0),
            vec4(0, 1, 0, 0),
            vec4(0, 0, 1, 0),
            vec4(0, 0, 0, 1)
            ),
        mat4(
            vec4(0, 1, 1, 0),
            vec4(0, 1, 0, 1),
            vec4(0, 0, 1, 1),
            vec4(0, 1, 1, 1)
            )
        ),
    mat4[2](
        mat4(
            vec4(0, 0, 0, 0),
            vec4(1, 0, 0, 0),
            vec4(0, 0, 1, 0),
            vec4(0, 0, 0, 1)
            ),
        mat4(
            vec4(1, 0, 1, 0),
            vec4(1, 0, 0, 1),
            vec4(0, 0, 1, 1),
            vec4(1, 0, 1, 1)
            )
        ),
    mat4[2](
        mat4(
            vec4(0, 0, 0, 0),
            vec4(1, 0, 0, 0),
            vec4(0, 1, 0, 0),
            vec4(0, 0, 0, 1)
            ),
        mat4(
            vec4(1, 1, 0, 0),
            vec4(1, 0, 0, 1),
            vec4(0, 1, 0, 1),
            vec4(1, 1, 0, 1)
            )
        ),
    mat4[2](
        mat4(
            vec4(0, 0, 0, 0),
            vec4(1, 0, 0, 0),
            vec4(0, 1, 0, 0),
            vec4(0, 0, 1, 0)
            ),
        mat4(
            vec4(1, 1, 0, 0),
            vec4(1, 0, 1, 0),
            vec4(0, 1, 1, 0),
            vec4(1, 1, 1, 0)
            )
        )
    );

const vec3[8] colors = {
    vec3(.0, .8, .0),
    vec3(.8, .0, .0),
    vec3(.0, .0, .8),
    vec3(.0, .8, .8),
    vec3(.8, .0, .8),
    vec3(.8, .8, .0),
    vec3(.2, .2, .2),
    vec3(.7, .7, .7)
};


void main()
{
    // TODO these get compiled out, right??
    vec4 pos = gl_in[0].gl_Position;
    vec4 rel_corner = vertex_data[0].rel_corner;

    int unsigned_orientation = int(dot(step(0, -abs(rel_corner)), vec4(0, 1, 2, 3)));
    bool negative_orientation = dot(rel_corner, vec4(1, 1, 1, 1)) < 0;
    int signed_orientation = int(negative_orientation) * 4 + unsigned_orientation;

    vec4 rel_pos_v = pos - base_pos;

    if (false) {
        vec4 rel_center = rel_pos_v + vec4(0.5, 0.5, 0.5, 0.5);
        if (abs(dot(rel_center, normal)) > 1 || dot(rel_center, front) > 1) {
            EndPrimitive();
            return;
        }
    }

    mat4[2] rel_pos;
    bvec4[2] pos_side;

    // TODO can we skip this entirely, and instead calculate the intersection point for *every* edge and throw away the nonsense (i.e. nonintersecting) results?
    for (int i = 0; i < 2; i++) {
        float negative_orientation_factor = negative_orientation ? -1 : 1;
        if (false) {
            // TODO negative_orientation
            rel_pos[i] = matrixCompMult(
                corner_offsets[unsigned_orientation][i],
                mat4(rel_corner, rel_corner, rel_corner, rel_corner)
                ) + mat4(rel_pos_v, rel_pos_v, rel_pos_v, rel_pos_v);
            pos_side[i] = greaterThan(rel_pos[i] * normal, vec4(0));
        } else {
            for (int j = 0; j < 4; j++) {
                rel_pos[i][j] = negative_orientation_factor * corner_offsets[unsigned_orientation][i][j] + rel_pos_v;
                pos_side[i][j] = dot(rel_pos[i][j], normal) > 0;
            }
        }
    }

    if (true) {
        int num_verts_set = 0;
        vec4 first_vert_pos;

        for (int i = 0; i < 12; i++) {
            int corner_a = adjacent_corners[i][0];
            int corner_ah = corner_a >> 2;
            int corner_al = corner_a & 3;
            int corner_b = adjacent_corners[i][1];
            int corner_bh = corner_b >> 2;
            int corner_bl = corner_b & 3;
            if (pos_side[corner_ah][corner_al] != pos_side[corner_bh][corner_bl]) {
                if (num_verts_set > 1) {
                    gl_Position = first_vert_pos;
                    color_f = colors[signed_orientation];
                    EmitVertex();
                }
                vec4 diff = rel_pos[corner_ah][corner_al] - rel_pos[corner_bh][corner_bl];
                float scale = dot(rel_pos[corner_ah][corner_al], normal) * -1.0 / dot(normal, diff);
                vec4 rel_intersection_point = rel_pos[corner_ah][corner_al] + scale * diff;

                vec4 untransformed_vtx = vec4(
                    dot(right, rel_intersection_point),
                    dot(up, rel_intersection_point),
                    dot(front, rel_intersection_point),
                    1
                    );

                if (num_verts_set > 0) {
                    gl_Position = projection * view * untransformed_vtx;
                    color_f = colors[signed_orientation];
                    EmitVertex();
                } else {
                    first_vert_pos = projection * view * untransformed_vtx;
                }
                num_verts_set++;
            }

        }
    } else if (true) {
        for (int i = 0; i < 2; i++) {

            //vec4 v = corner_offsets[unsigned_orientation][1][3];
            vec4 v = vec4(1, 1, 1, 1);
            //vec4 v = step(0, -abs(rel_corner));
            //vec4 v = abs(sign(rel_pos[0][1] - rel_pos[0][3]));
            //vec4 v = vec4(pos_side[1]);
            //vec4 v = rel_pos[0] * normal;
            //vec4 v = 0.5 + 0.5 * tanh(0.5 * up);

            if (pos_side[i][0]) {
                v.x = 0;
            }
            if (pos_side[i][1]) {
                v.y = 0;
            }
            if (pos_side[i][2]) {
                v.z = 0;
            }
            if (pos_side[i][3]) {
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


        if (adjacent_corners[9][0] != 4) {
            v.x = 0;
        }
        if (adjacent_corners[9][1] != 7) {
            v.y = 0;
        }
        if (adjacent_corners[11][0] != 6) {
            v.z = 0;
        }
        if (adjacent_corners[11][1] != 7) {
            v.w = 0;
        }


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

