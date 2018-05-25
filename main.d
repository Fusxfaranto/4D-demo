
import std.stdio : writeln;
import std.conv : to;
import std.math : PI, sin, cos, acos, sgn;
import std.datetime : TickDuration, StopWatch;
import std.array : array;
import std.algorithm : sum, map;
import std.typecons : Tuple, tuple;

import util;
import render_bindings;
import matrix;
import shapes;
import chunk;


struct World
{
    Vertex[4][] scene;
    Vertex[4][] character;

    Chunk[ChunkPos] loaded_chunks;
}



Vec3 camera_pos = Vec3(0, 0, 3);
// EMV3 camera_front = EMV3(0, 0, 0, -1);
// Vec3 camera_up = Vec3(0, 1, 0);
float fov = deg_to_rad(45);

Vec4 char_pos = Vec4(0, 0.4, 0, 0.5);
Vec4 char_front = Vec4(0, 0.3, 1, 0).normalized();
Vec4 char_up = Vec4(0, 1, -0.3, 0).normalized();
Vec4 char_normal = Vec4(0, 0, 0, 1);
enum Vec4 global_up = Vec4(0, 1, 0, 0);

Mat4 view_mat, projection_mat, compass_projection_mat;

bool char_enabled = true;
bool force_window_size_update = false;
bool cube_culling = true;

debug(prof) StopWatch sw;


enum TextDisplay
{
    NONE,
    BLOCK,
    POS,
}
TextDisplay text_display;
string[] scratch_strings;

//Mat4 test_rot_mat;
//Vec4[2] test_plane = [Vec4(0.5, 0.5, 0.5, 0.5), Vec4(-0.5, -0.5, 0.5, 0.5)];
//float test_angle = 0;




void main()
{
    string title_str = "asdf\0";
    title = title_str.ptr;

    width = 1280;
    height = 800;
    display_mode = DisplayMode.NORMAL;


    Vec3 compass_base_ = Vec3(0, 0, 0);
    compass_base = compass_base_.data();


    World world;/*
                  world.scene ~= tesseract(Vec4(-30, -30, -30, -30), Vec4(60, 60, 60, 60));
                  world.scene ~= tesseract(Vec4(-10, -2, -10, -10), Vec4(20, 2, 20, 20));
                  world.scene ~= tesseract(Vec4(-3.5, 2, -6, 3), Vec4(1, 1, 1, 1),
                  rot(Vec4(1, 1, 1, 1), Vec4(0, 0, 0, 1), deg_to_rad(45)));
                  world.scene ~= tesseract(Vec4(-.5, 0, -3, 0), Vec4(1, 1, 1, 1));
                  world.scene ~= tesseract(Vec4(1, 0, -3, 0), Vec4(1, 1, 1, 5));
                  world.scene ~= tesseract(Vec4(0, 0, 3, 0));
                  world.scene ~= tesseract(Vec4(0, 0, 4, 0));
                  world.scene ~= tesseract(Vec4(0, 0, 5, 0));
                  world.scene ~= tesseract(Vec4(1, 0, 4, 0));
                  world.scene ~= tesseract(Vec4(-1, 0, 4, 0));
                  world.scene ~= tesseract(Vec4(0, 0, 4, 1));
                  world.scene ~= tesseract(Vec4(0, 0, 4, -1));
                  world.scene ~= tesseract(Vec4(0, 1, 4, 0));
                  world.scene ~= fivecell(Vec4(4, 2, 4, 0));
                  world.scene ~= tesseract(Vec4(4, 0, -4, 0), Vec4(0.2, 1.5, 3, 1));
                  world.scene ~= tesseract(Vec4(5.6, 0, -4, 0), Vec4(0.2, 1.5, 3, 1));
                  world.scene ~= tesseract(Vec4(4.2, 0, -4, 0), Vec4(1.4, 1.5, 0.2, 1));
                  world.scene ~= tesseract(Vec4(4.2, 0, -1.2, 0), Vec4(1.4, 1.5, 0.2, 1));
                  world.scene ~= tesseract(Vec4(4, 1.5, -4, 0), Vec4(1.8, 0.2, 3, 1));*/
    //scene ~= tesseract(Vec4(1, 0, 0, 0));
    //scene ~= tesseract(Vec4(0, 1, 0, 0));
    //scene ~= tesseract(Vec4(1, 1, 0, 0));
    //scene ~= tesseract(Vec4(0, 0, 1, 0));
    //scene ~= tesseract(Vec4(1, 0, 1, 0));
    //scene ~= tesseract(Vec4(0, 1, 1, 0));
    //scene ~= tesseract(Vec4(1, 1, 1, 0));
    //scene ~= tesseract(Vec4(0, 0, 0, 1));
    //scene ~= tesseract(Vec4(1, 0, 0, 1));
    //scene ~= tesseract(Vec4(0, 1, 0, 1));
    //scene ~= tesseract(Vec4(1, 1, 0, 1));
    //scene ~= tesseract(Vec4(0, 0, 1, 1));
    //scene ~= tesseract(Vec4(1, 0, 1, 1));
    //scene ~= tesseract(Vec4(0, 1, 1, 1));
    //scene ~= tesseract(Vec4(1, 1, 1, 1));


    world.scene = [];
    world.scene ~= tesseract!(false, solid_color_gen!(0.5, 0.5, 0.5))(Vec4(-30, -30, -30, -30), Vec4(60, 60, 60, 60));
    world.scene ~= tesseract!(false, solid_color_gen!(0.6, 0.5, 0.1))(Vec4(-10, -2, -10, -10), Vec4(20, 2, 20, 20));
    world.scene ~= tesseract!(false, solid_color_gen!(0.8, 0.1, 0.1))(Vec4(5, 0, 5, 0), Vec4(1, 3, 1, 1));
    world.scene ~= tesseract!(false, solid_color_gen!(0.8, 0.1, 0.1))(Vec4(5, 0, -5, 0), Vec4(1, 3, 1, 1));
    world.scene ~= tesseract!(false, solid_color_gen!(0.8, 0.1, 0.1))(Vec4(-5, 0, 5, 0), Vec4(1, 3, 1, 1));
    world.scene ~= tesseract!(false, solid_color_gen!(0.8, 0.1, 0.1))(Vec4(-5, 0, -5, 0), Vec4(1, 3, 1, 1));
    world.scene ~= tesseract!(true)(Vec4(0, 1.1, 0, 0.5), Vec4(1, 1, 1, 1));

    view_mat = look_at(Vec3(0, 0, 3), Vec3(0, 0, 0), Vec3(0, 1, 0));
    view = view_mat.data;
    projection = projection_mat.data;

    compass_projection = compass_projection_mat.data;

    handle_errors!init();
    scope(exit) cleanup();

    glfwSetKeyCallback(w, &key_callback);

    int t = 0;
    int last_width = -1, last_height = -1;
    float last_fov = fov;
    TickDuration last_time;
    float[30] fpss;
    debug(prof) sw.start();

    while (!glfwWindowShouldClose(w))
    {
        debug(prof) writeln("tick start");
        debug(prof) sw.reset();

        fpss[t % fpss.length] = 1.0e9 / (TickDuration.currSystemTick() - last_time).nsecs();
        title_str = (sum(fpss[]) / fpss.length).to!string() ~ '\0';
        //title = title_str.ptr;
        last_time = TickDuration.currSystemTick();

        process_input();
        debug(prof) profile_checkpoint(__LINE__, sw);

        if (force_window_size_update || last_width != width || last_height != height || last_fov != fov)
        {
            float r = cast(float)(width) / height;
            final switch (display_mode.to!DisplayMode)
            {
            case DisplayMode.NORMAL:
                break;

            case DisplayMode.SPLIT:
                r /= 2;
                break;
            }
            projection_mat = perspective(fov, r, 0.1, 100);
            compass_projection_mat = perspective(deg_to_rad(45), width, 0.1, 100);
            //projection_mat = orthographic(-width / 400.0, width / 400.0, -height / 400.0, height / 400.0, -10, 100);
            last_height = height;
            last_width = width;
            last_fov = fov;
            force_window_size_update = false;

            handle_errors!window_size_update();
        }
        debug(prof) profile_checkpoint(__LINE__, sw);

        Vec4 char_right = cross_p(char_up, char_front, char_normal);

        //test_rot_mat = rot(test_plane[0], test_plane[1], test_angle);

        screen_text_data[0].x = -1;
        screen_text_data[0].y = 1;
        screen_text_data[0].x_scale = 0.0005;
        screen_text_data[0].y_scale = 0.0005;
        screen_text_data[0].line_spacing = 0.1;
        screen_text_data[0].a = [title_str.ptr];

        screen_text_data[1].x = -0.6;
        screen_text_data[1].y = 1;
        screen_text_data[1].x_scale = 0.001;
        screen_text_data[1].y_scale = 0.001;
        screen_text_data[1].line_spacing = 0.1;
        final switch (text_display)
        {
        case TextDisplay.NONE:
            screen_text_data[1].a = [];
            break;

        case TextDisplay.BLOCK:
            screen_text_data[1].a = map!"a.toStringz"(scratch_strings).array;
            break;

        case TextDisplay.POS:
            screen_text_data[1].a = [
                format("front:    %6.3f, %6.3f, %6.3f, %6.3f\0",
                       char_front.x, char_front.y, char_front.z, char_front.w).ptr,
                format("up:       %6.3f, %6.3f, %6.3f, %6.3f\0",
                       char_up.x, char_up.y, char_up.z, char_up.w).ptr,
                format("right:    %6.3f, %6.3f, %6.3f, %6.3f\0",
                       char_right.x, char_right.y, char_right.z, char_right.w).ptr,
                format("normal:   %6.3f, %6.3f, %6.3f, %6.3f\0",
                       char_normal.x, char_normal.y, char_normal.z, char_normal.w).ptr,
                format("position: %6.3f, %6.3f, %6.3f, %6.3f\0",
                       char_pos.x, char_pos.y, char_pos.z, char_pos.w).ptr,
                ];
            break;
        }
        scratch_strings.length = 0;
        debug(prof) profile_checkpoint(__LINE__, sw);

        Vec4 flat_front = (char_front - proj(char_front, global_up)).normalized();
        Vec4 flat_normal = (char_normal - proj(char_normal, global_up)).normalized();
        Vec4 flat_right = cross_p(global_up, flat_front, flat_normal);
        Mat4 r = Mat4(
            flat_right.x, flat_right.y, flat_right.z, flat_right.w,
            global_up.x, global_up.y, global_up.z, global_up.w,
            flat_front.x, flat_front.y, flat_front.z, flat_front.w,
            flat_normal.x, flat_normal.y, flat_normal.z, flat_normal.w,
            );
        world.character = tesseract!true(char_pos, 0.6 * Vec4(0.3, 0.8, 0.3, 0.3), r);

        Vec3 compass_ = Vec3(-flat_front.x, flat_front.w, flat_front.z) + compass_base_;
        compass = compass_.data();
        debug(prof) profile_checkpoint(__LINE__, sw);

        load_chunks(char_pos, 1.5f, world.loaded_chunks);
        debug(prof) profile_checkpoint(__LINE__, sw);

        cross_section(world, vertical_objects,
                      char_pos, flat_normal, flat_front, global_up, flat_right);
        debug(prof) profile_checkpoint(__LINE__, sw);

        scratch_strings.length = 0;
        cross_section(world, objects,
                      char_pos, char_up, char_front, char_normal, char_right);
        debug(prof) profile_checkpoint(__LINE__, sw);

        render();
        debug(prof) profile_checkpoint(__LINE__, sw);

        for (;;)
        {
            GLError err = glGetError().to!GLError;
            if (err == GLError.GL_NO_ERROR)
            {
                break;
            }
            else
            {
                writeln("OpenGL error: ", err);
            }
        }

        wait_for_next_frame();
        debug(prof) profile_checkpoint(__LINE__, sw);

        t++;
    }
}


void cross_section(ref World world, ref float[] objects,
                   Vec4 base_pos, Vec4 up, Vec4 front, Vec4 normal, Vec4 right)
{
    // reset contents without deallocating (in theory at least)
    objects.length = 0;

    static ChunkPos[] cs_stack;
    static ChunkPos[] processed_cps;

    assert(processed_cps.length == 0);

    ChunkPos center_cp = coords_to_chunkpos(base_pos);
    cs_stack.length = 1;
    cs_stack[0] = center_cp;

    void process_cube(Vec4 pos, Vec4BasisSigned dir)
    {
        if (cube_culling && dot_p(pos - base_pos, dir.from_basis()) > 0)
        {
            return;
        }

        Vec4[8] corner_offsets;
        final switch (dir)
        {
        case Vec4BasisSigned.X: case Vec4BasisSigned.nX:
            corner_offsets = [
                Vec4(0, 0, 0, 0),
                Vec4(0, 1, 0, 0),
                Vec4(0, 0, 1, 0),
                Vec4(0, 0, 0, 1),
                Vec4(0, 1, 1, 0),
                Vec4(0, 1, 0, 1),
                Vec4(0, 0, 1, 1),
                Vec4(0, 1, 1, 1),
                ];
            break;

        case Vec4BasisSigned.Y: case Vec4BasisSigned.nY:
            corner_offsets = [
                Vec4(0, 0, 0, 0),
                Vec4(1, 0, 0, 0),
                Vec4(0, 0, 1, 0),
                Vec4(0, 0, 0, 1),
                Vec4(1, 0, 1, 0),
                Vec4(1, 0, 0, 1),
                Vec4(0, 0, 1, 1),
                Vec4(1, 0, 1, 1),
                ];
            break;

        case Vec4BasisSigned.Z: case Vec4BasisSigned.nZ:
            corner_offsets = [
                Vec4(0, 0, 0, 0),
                Vec4(1, 0, 0, 0),
                Vec4(0, 1, 0, 0),
                Vec4(0, 0, 0, 1),
                Vec4(1, 1, 0, 0),
                Vec4(1, 0, 0, 1),
                Vec4(0, 1, 0, 1),
                Vec4(1, 1, 0, 1),
                ];
            break;

        case Vec4BasisSigned.W: case Vec4BasisSigned.nW:
            corner_offsets = [
                Vec4(0, 0, 0, 0),
                Vec4(1, 0, 0, 0),
                Vec4(0, 1, 0, 0),
                Vec4(0, 0, 1, 0),
                Vec4(1, 1, 0, 0),
                Vec4(1, 0, 1, 0),
                Vec4(0, 1, 1, 0),
                Vec4(1, 1, 1, 0),
                ];
            break;
        }

        float[3] color;
        final switch (dir)
        {
        case Vec4BasisSigned.X:
            color = [.0, .8, .0];
            break;

        case Vec4BasisSigned.nX:
            color = [.8, .0, .0];
            break;

        case Vec4BasisSigned.Y:
            color = [.0, .0, .8];
            break;

        case Vec4BasisSigned.nY:
            color = [.0, .8, .8];
            break;

        case Vec4BasisSigned.Z:
            color = [.8, .0, .8];
            break;

        case Vec4BasisSigned.nZ:
            color = [.8, .8, .0];
            break;

        case Vec4BasisSigned.W:
            color = [.2, .2, .2];
            break;

        case Vec4BasisSigned.nW:
            color = [.7, .7, .7];
            break;
        }

        enum Tuple!(int, int)[12] adjacent_corners = [
            tuple(0, 1),
            tuple(0, 2),
            tuple(0, 3),
            tuple(1, 4),
            tuple(1, 5),
            tuple(2, 4),
            tuple(2, 6),
            tuple(3, 5),
            tuple(3, 6),
            tuple(4, 7),
            tuple(5, 7),
            tuple(6, 7),
            ];

        Vec4[8] rel_pos;
        bool[8] pos_side;
        for (int i = 0; i < 8; i++)
        {
            rel_pos[i] = corner_offsets[i] + pos - base_pos;
            pos_side[i] = dot_p(rel_pos[i], normal) > 0;
        }

        static size_t[] verts;
        verts.length = 0;

        foreach (i, t; adjacent_corners)
        {
            if (pos_side[t[0]] != pos_side[t[1]])
            {
                verts ~= i;
                //writeln(t);
            }
        }

        // i don't like this but it'll have to do for now
        // if this looks like it's here to stay, at least replace it with a trie or something
        if (verts.length >= 5)
        {
            if (verts.length == 6)
            {
                if (verts == [3, 4, 5, 6, 7, 8])
                {
                    swap(verts[3], verts[4]);
                }
            }
            else
            {
                if (verts == [0, 5, 6, 7, 8])
                {
                    swap(verts[0], verts[1]);
                }
                else if (verts == [0, 1, 6, 7, 11])
                {
                    swap(verts[0], verts[1]);
                }
                else if (verts == [3, 5, 6, 8, 10])
                {
                    swap(verts[0], verts[1]);
                    swap(verts[1], verts[2]);
                }
                else if (verts == [1, 2, 4, 5, 9])
                {
                    swap(verts[0], verts[1]);
                }
                else if (verts == [4, 6, 7, 8, 9])
                {
                    swap(verts[0], verts[3]);
                    swap(verts[3], verts[4]);
                }
                else if (verts == [2, 3, 4, 5, 6])
                {
                    swap(verts[0], verts[2]);
                }
                else if (verts == [1, 3, 4, 7, 8])
                {
                    swap(verts[0], verts[1]);
                    swap(verts[3], verts[4]);
                }
            }
        }

        foreach (i, v; verts)
        {
            //writeln(i, " ", verts);
            Vec4 diff = rel_pos[adjacent_corners[v][0]] - rel_pos[adjacent_corners[v][1]];
            float d = dot_p(normal, diff);
            Vec4 rel_intersection_point = rel_pos[adjacent_corners[v][0]] +
                diff * (-dot_p(rel_pos[adjacent_corners[v][0]], normal) / d);

            if (i >= 3)
            {
                objects ~= objects[($ - 2 * 6)..($ - 1 * 6)];
                objects ~= objects[($ - 2 * 6)..($ - 1 * 6)];
            }

            objects ~= [
                dot_p(right, rel_intersection_point),
                dot_p(up, rel_intersection_point),
                dot_p(front, rel_intersection_point),
                color[0], color[1], color[2]
                ];
        }
        if (verts.length >= 1)
        {
            scratch_strings ~= verts.to!string();
        }
        //writeln(verts);

        //writeln(objects[($ - ((verts.length - 2) * 3) * 6)..$]);

        assert(objects.length % 3 == 0);
    }

    void process_chunk(ref Chunk c, ChunkPos cp)
    {
        //writeln("processing ", cp);
        processed_cps ~= cp;
        c.status = ChunkStatus.PROCESSED;

        foreach (x; 0..CHUNK_SIZE)
        {
            foreach (y; 0..CHUNK_SIZE)
            {
                foreach (z; 0..CHUNK_SIZE)
                {
                    foreach (w; 0..CHUNK_SIZE)
                    {
                        // TODO: first check if block is viable to have any intersection at all, and only then check each cube

                        if (c.grid[x][y][z][w] != BlockType.NONE)
                        {
                            debug(prof) profile_checkpoint(__LINE__, sw);
                            Vec4 pos = cp.to_vec4() + Vec4(x, y, z, w);

                            process_cube(pos + Vec4(0, 0, 0, 0), Vec4BasisSigned.nX);
                            process_cube(pos + Vec4(0, 0, 0, 0), Vec4BasisSigned.nY);
                            process_cube(pos + Vec4(0, 0, 0, 0), Vec4BasisSigned.nZ);
                            process_cube(pos + Vec4(0, 0, 0, 0), Vec4BasisSigned.nW);
                            process_cube(pos + Vec4(1, 0, 0, 0), Vec4BasisSigned.X);
                            process_cube(pos + Vec4(0, 1, 0, 0), Vec4BasisSigned.Y);
                            process_cube(pos + Vec4(0, 0, 1, 0), Vec4BasisSigned.Z);
                            process_cube(pos + Vec4(0, 0, 0, 1), Vec4BasisSigned.W);
                            debug(prof) profile_checkpoint(__LINE__, sw);
                        }
                    }
                }
            }
        }
    }

    assert(center_cp in world.loaded_chunks);
    process_chunk(world.loaded_chunks[center_cp], center_cp);

    while (!cs_stack.empty())
    {
        ChunkPos cp = cs_stack.back();
        cs_stack.popBack();

        foreach (new_cp; [
                     cp.shift!"x"(1),
                     cp.shift!"y"(1),
                     cp.shift!"z"(1),
                     cp.shift!"w"(1),
                     cp.shift!"x"(-1),
                     cp.shift!"y"(-1),
                     cp.shift!"z"(-1),
                     cp.shift!"w"(-1),
                     ])
        {
            // TODO if intersects hplane

            Chunk* p = new_cp in world.loaded_chunks;
            if (p && p.status == ChunkStatus.NOT_PROCESSED)
            {
                cs_stack ~= new_cp;
                process_chunk(*p, new_cp);
            }
        }
    }

    //writeln(processed_cps);
    foreach (cp; processed_cps)
    {
        world.loaded_chunks[cp].status = ChunkStatus.NOT_PROCESSED;
    }
    processed_cps.length = 0;

    //writeln(objects[0..10]);
    debug(prof) profile_checkpoint(__LINE__, sw);


    void run(ref in Vertex[4][] tets)
    {
        foreach (ref tet; tets)
        {
            Vec4[4] rel_pos;  // potentially slower to store this instead of just recomputing?
            bool[4] pos_side;
            for (int i = 0; i < 4; i++)
            {
                rel_pos[i] = tet[i].loc - base_pos;
                pos_side[i] = dot_p(rel_pos[i], normal) > 0;
            }

            int verts_added = 0;
            for (int i = 0; i < 4; i++)
            {
                for (int j = i; j < 4; j++)
                {
                    if (pos_side[i] != pos_side[j])
                    {
                        Vec4 diff = tet[i].loc - tet[j].loc;
                        float d = dot_p(normal, diff);
                        // this would fire sometimes, but i don't think it's actually important to ensure
                        //assert(abs(d) > 1e-6);
                        Vec4 rel_intersection_point = tet[i].loc +
                            diff * (-dot_p(rel_pos[i], normal) / d) - base_pos;

                        if (verts_added == 3)
                        {
                            objects ~= objects[($ - 2 * 6)..($ - 1 * 6)];
                            objects ~= objects[($ - 2 * 6)..($ - 1 * 6)];
                            verts_added += 2;
                        }

                        // http://stackoverflow.com/questions/23472048/projecting-3d-points-to-2d-plane i guess
                        objects ~= [
                            dot_p(right, rel_intersection_point),
                            dot_p(up, rel_intersection_point),
                            dot_p(front, rel_intersection_point),
                            tet[i].color_r, tet[i].color_g, tet[i].color_b
                            ];
                        verts_added++;
                    }
                }
            }

            assert(verts_added == 0 || verts_added == 3 || verts_added == 6);
        }
    }

    run(world.scene);
    if (char_enabled)
    {
        run(world.character);
    }
    debug(prof) profile_checkpoint(__LINE__, sw);
}



extern (C) void key_callback(GLFWwindow* window, int key, int scancode, int action, int mods)
{
    if (action != GLFWKeyStatus.GLFW_PRESS)
    {
        return;
    }

    switch (key)
    {
    case GLFWKey.GLFW_KEY_SPACE:
    {
        writeln("front: ", char_front);
        writeln("up: ", char_up);
        writeln("normal: ", char_normal);
        writeln("right: ", cross_p(char_up, char_front, char_normal));
        writeln("position: ", char_pos);

        writeln(dot_p(char_normal, char_up));
        writeln(dot_p(char_front, char_up));
        writeln(dot_p(char_front, char_normal));

        Vec4 flat_front = char_front - proj(char_front, global_up);
        writeln(flat_front);
        writeln(acos(dot_p(Vec4(1, 0, 0, 0), flat_front)
                     / flat_front.magnitude()) * 180 / PI);
        writeln(rot(Vec4(1, 0, 0, 0), flat_front,
                    acos(dot_p(Vec4(1, 0, 0, 0), flat_front)
                         / flat_front.magnitude())));

        writeln();
        break;
    }

    case GLFWKey.GLFW_KEY_ENTER:
    {
        if (view_mat == Mat4.init)
        {
            view_mat = look_at(camera_pos, Vec3(0, 0, 0), Vec3(0, 1, 0));
            char_enabled = true;
        }
        else
        {
            view_mat = Mat4.init;
            char_enabled = false;
        }
        break;
    }

    case GLFWKey.GLFW_KEY_BACKSLASH:
    {
        display_mode++;
        if (display_mode > DisplayMode.max)
        {
            display_mode = DisplayMode.min;
        }
        assert(display_mode == display_mode.to!DisplayMode);
        force_window_size_update = true;
        break;
    }

    case GLFWKey.GLFW_KEY_BACKSPACE:
    {
        char_enabled ^= true;
        break;
    }

    case GLFWKey.GLFW_KEY_C:
    {
        cube_culling ^= true;
        break;
    }

    case GLFWKey.GLFW_KEY_1:
    {
        char_enabled = true;
        char_pos = Vec4(0, 0.7, 0, 0.5);
        char_front = Vec4(0, 0.3, 1, 0).normalized();
        char_up = Vec4(0, 1, -0.3, 0).normalized();
        char_normal = Vec4(0, 0, 0, 1);
        camera_pos.z = 3;
        view_mat = look_at(camera_pos, Vec3(0, 0, 0), Vec3(0, 1, 0));
        break;
    }

    case GLFWKey.GLFW_KEY_2:
    {
        char_pos = Vec4(0, .7, 0, 0);
        char_front = Vec4(-.01, 0, 1, 0).normalized();
        char_up = Vec4(0, 1, 0, 0);
        char_normal = Vec4(0, 0, 0, 1);
        break;
    }

    case GLFWKey.GLFW_KEY_3:
    {
        char_front = Vec4(0, 0, 1, 0);
        char_up = Vec4(0, 0, 0, 1);
        char_normal = Vec4(0, 1, 0, 0);
        break;
    }

    case GLFWKey.GLFW_KEY_EQUAL:
    {
        text_display = inc_enum!TextDisplay(text_display);
        break;
    }

    default:
        break;
    }
}

void process_input()
{
    glfwPollEvents();

    float speed = 0.05;
    float rot_speed = 0.02;
    float other_rot_speed = rot_speed; // remove?
    float y_limit = 0.99;

    if (get_key(GLFWKey.GLFW_KEY_LEFT_SHIFT) == GLFWKeyStatus.GLFW_PRESS)
    {
        speed *= 5;
        rot_speed *= 5;
        other_rot_speed *= 5;
    }
    if (get_key(GLFWKey.GLFW_KEY_LEFT_CONTROL) == GLFWKeyStatus.GLFW_PRESS)
    {
        speed /= 10;
        rot_speed /= 10;
        other_rot_speed /= 10;
    }

    if (get_key(GLFWKey.GLFW_KEY_W) == GLFWKeyStatus.GLFW_PRESS)
    {
        char_pos -= speed * (char_front - proj(char_front, global_up)).normalized();
    }
    if (get_key(GLFWKey.GLFW_KEY_S) == GLFWKeyStatus.GLFW_PRESS)
    {
        char_pos += speed * (char_front - proj(char_front, global_up)).normalized();
    }
    if (get_key(GLFWKey.GLFW_KEY_R) == GLFWKeyStatus.GLFW_PRESS)
    {
        char_pos += speed * global_up;
    }
    if (get_key(GLFWKey.GLFW_KEY_F) == GLFWKeyStatus.GLFW_PRESS)
    {
        char_pos -= speed * global_up;
    }
    if (get_key(GLFWKey.GLFW_KEY_Q) == GLFWKeyStatus.GLFW_PRESS)
    {
        char_pos += speed * char_normal;
    }
    if (get_key(GLFWKey.GLFW_KEY_E) == GLFWKeyStatus.GLFW_PRESS)
    {
        char_pos -= speed * char_normal;
    }
    if (get_key(GLFWKey.GLFW_KEY_A) == GLFWKeyStatus.GLFW_PRESS)
    {
        char_pos -= speed * normalized(cross_p(char_up, char_front, char_normal));
    }
    if (get_key(GLFWKey.GLFW_KEY_D) == GLFWKeyStatus.GLFW_PRESS)
    {
        char_pos += speed * normalized(cross_p(char_up, char_front, char_normal));
    }


    if (get_key(GLFWKey.GLFW_KEY_J) == GLFWKeyStatus.GLFW_PRESS)
    {
        Mat4 r = rot!false(global_up, char_normal, /*char_normal.w.sgn() * */-rot_speed);
        char_front = (r * char_front).normalized();
        char_up = (r * char_up).normalized();
    }
    if (get_key(GLFWKey.GLFW_KEY_L) == GLFWKeyStatus.GLFW_PRESS)
    {
        Mat4 r = rot!false(global_up, char_normal, /*char_normal.w.sgn() **/ rot_speed);
        char_front = (r * char_front).normalized();
        char_up = (r * char_up).normalized();
    }
    if (get_key(GLFWKey.GLFW_KEY_U) == GLFWKeyStatus.GLFW_PRESS)
    {
        //writeln(rot!false(char_up, char_front, -rot_speed));
        // testo -= other_rot_speed;
        // writeln(testo * 180 / PI);
        Mat4 r = rot!false(global_up, cross_p(char_up, char_front, char_normal), -other_rot_speed);
        char_front = (r * char_front).normalized();
        char_normal = (r * char_normal).normalized();
        char_up = (r * char_up).normalized();
        //char_normal = (rot(char_normal, char_front, -other_rot_speed) * char_normal).normalized();
    }
    if (get_key(GLFWKey.GLFW_KEY_O) == GLFWKeyStatus.GLFW_PRESS)
    {
        //writeln(rot!false(char_up, char_front, rot_speed));
        // testo += other_rot_speed;
        // writeln(testo * 180 / PI);
        Mat4 r = rot!false(global_up, cross_p(char_up, char_front, char_normal), other_rot_speed);
        char_front = (r * char_front).normalized();
        char_normal = (r * char_normal).normalized();
        char_up = (r * char_up).normalized();
        //char_normal = (rot(char_normal, char_front, other_rot_speed) * char_normal).normalized();
    }
    if (get_key(GLFWKey.GLFW_KEY_M) == GLFWKeyStatus.GLFW_PRESS)
    {
        Mat4 r = rot!false(global_up, char_front, -other_rot_speed);
        char_normal = (r * char_normal).normalized();
        char_up = (r * char_up).normalized();
    }
    if (get_key(GLFWKey.GLFW_KEY_PERIOD) == GLFWKeyStatus.GLFW_PRESS)
    {
        Mat4 r = rot!false(global_up, char_front, other_rot_speed);
        char_normal = (r * char_normal).normalized();
        char_up = (r * char_up).normalized();
    }
    if (get_key(GLFWKey.GLFW_KEY_I) == GLFWKeyStatus.GLFW_PRESS)
    {
        if (char_front.y > -y_limit)
        {
            Mat4 r = rot(char_up, char_front, rot_speed);
            char_front = (r * char_front).normalized();
            char_up = (r * char_up).normalized();
        }
    }
    if (get_key(GLFWKey.GLFW_KEY_K) == GLFWKeyStatus.GLFW_PRESS)
    {
        if (char_front.y < y_limit)
        {
            Mat4 r = rot(char_up, char_front, -rot_speed);
            char_front = (r * char_front).normalized();
            char_up = (r * char_up).normalized();
        }
    }
    // if (get_key(GLFWKey.GLFW_KEY_Y) == GLFWKeyStatus.GLFW_PRESS)
    // {
    //     Mat4 r = rot!false(char_front, char_normal, -rot_speed);
    //     char_up = (r * char_up).normalized();
    // }
    // if (get_key(GLFWKey.GLFW_KEY_H) == GLFWKeyStatus.GLFW_PRESS)
    // {
    //     Mat4 r = rot!false(char_front, char_normal, rot_speed);
    //     char_up = (r * char_up).normalized();
    // }
    // if (get_key(GLFWKey.GLFW_KEY_P) == GLFWKeyStatus.GLFW_PRESS)
    // {
    //     Mat4 r = rot(char_up, char_normal, -rot_speed);
    //     char_up = (r * char_up).normalized();
    //     char_normal = (r * char_normal).normalized();
    // }
    // if (get_key(GLFWKey.GLFW_KEY_SEMICOLON) == GLFWKeyStatus.GLFW_PRESS)
    // {
    //     Mat4 r = rot(char_up, char_normal, rot_speed);
    //     char_up = (r * char_up).normalized();
    //     char_normal = (r * char_normal).normalized();
    // }

    if (get_key(GLFWKey.GLFW_KEY_Z) == GLFWKeyStatus.GLFW_PRESS)
    {
        if (char_enabled && camera_pos.z > 0.1)
        {
            camera_pos.z -= speed;
            view_mat = look_at(camera_pos, Vec3(0, 0, 0), Vec3(0, 1, 0));
        }
    }
    if (get_key(GLFWKey.GLFW_KEY_X) == GLFWKeyStatus.GLFW_PRESS)
    {
        if (char_enabled)
        {
            camera_pos.z += speed;
            view_mat = look_at(camera_pos, Vec3(0, 0, 0), Vec3(0, 1, 0));
        }
    }



    // if (get_key(GLFWKey.GLFW_KEY_T) == GLFWKeyStatus.GLFW_PRESS)
    // {
    //     test_angle += rot_speed;
    // }
    // if (get_key(GLFWKey.GLFW_KEY_G) == GLFWKeyStatus.GLFW_PRESS)
    // {
    //     test_angle -= rot_speed;
    // }



    // TODO: else if?
    if (abs(dot_p(char_normal, char_up)) > 1e-7)
    {
        //writeln("normal/up offset");
        Vec4 right = cross_p(char_up, char_front, char_normal);
        char_normal = cross_p(char_up, right, char_front).normalized();
    }
    if (abs(dot_p(char_front, char_up)) > 1e-7)
    {
        //writeln("front/up offset");
        Vec4 right = cross_p(char_up, char_front, char_normal);
        char_front = cross_p(right, char_up, char_normal).normalized();
    }
    if (abs(dot_p(char_front, char_normal)) > 1e-7)
    {
        //writeln("front/normal offset");
        Vec4 right = cross_p(char_up, char_front, char_normal);
        char_front = cross_p(right, char_up, char_normal).normalized();
    }
}


/*
 * plan:
 * - memory pool of tesseract chunks
 * - load and render chunks inside surrounding 3-sphere (or similar)
 * - block-based lighting
 *
 */
