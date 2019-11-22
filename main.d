
import core.atomic : atomicLoad, atomicStore;
import core.memory : GC;
import core.thread : Thread;
import std.conv : to;
import std.math : floor, PI, sin, cos, acos, sgn, abs;
import std.datetime : to, TickDuration;
import std.datetime.stopwatch : StopWatch;
import std.array : array;
import std.algorithm : sum, map;
import std.typecons : Tuple, tuple;

import util;
import render_bindings;
import matrix;
import movement;
import shapes;
import chunk;
import cross_section;
import world;
import workers;


__gshared World w = null;

BlockFace targeted_block = BlockFace.INVALID;


Vec3 camera_pos = Vec3(0, 0, 3);
// EMV3 camera_front = EMV3(0, 0, 0, -1);
// Vec3 camera_up = Vec3(0, 1, 0);
float fov;

PosDir pd = PosDir(
    Vec4(0, 0.4, 0, 0.5),
    Vec4(0, 0.3, 1, 0).normalized(),
    Vec4(0, 1, -0.3, 0).normalized(),
    Vec4(0, 0, 0, 1),
    Vec4(0, 0, 0, 0),
    );

Mat4 view_mat, projection_mat, compass_projection_mat;

bool char_enabled = false;
bool force_window_size_update = true;
bool cube_culling = true;


bool gravity_on = true;


enum TextDisplay
{
    NONE,
    BLOCK,
    POS,
    CHUNK,
}
TextDisplay text_display;
string[] scratch_strings;

//Mat4 test_rot_mat;
//Vec4[2] test_plane = [Vec4(0.5, 0.5, 0.5, 0.5), Vec4(-0.5, -0.5, 0.5, 0.5)];
//float test_angle = 0;


void main()
{
    string title_str = "\0";
    title = title_str.ptr;

    width = 1280;
    height = 800;
    display_mode = DisplayMode.NORMAL;

    // GC.disable();
    // scope(exit) GC.enable();


    cast(void)readable_tid();

    Vec3 compass_base_ = Vec3(0, 0, 0);
    compass_base = compass_base_.data();

    load_params.set(LoadParams(Vec4(0, 0, 0, 0), 0, 0));
    w = new World;
    scope(exit) {
        atomicStore(do_close, true);
        w.workers.join();
    }

/*
  w.scene ~= tesseract(Vec4(-30, -30, -30, -30), Vec4(60, 60, 60, 60));
  w.scene ~= tesseract(Vec4(-10, -2, -10, -10), Vec4(20, 2, 20, 20));
  w.scene ~= tesseract(Vec4(-3.5, 2, -6, 3), Vec4(1, 1, 1, 1),
  rot(Vec4(1, 1, 1, 1), Vec4(0, 0, 0, 1), deg_to_rad(45)));
  w.scene ~= tesseract(Vec4(-.5, 0, -3, 0), Vec4(1, 1, 1, 1));
  w.scene ~= tesseract(Vec4(1, 0, -3, 0), Vec4(1, 1, 1, 5));
  w.scene ~= tesseract(Vec4(0, 0, 3, 0));
  w.scene ~= tesseract(Vec4(0, 0, 4, 0));
  w.scene ~= tesseract(Vec4(0, 0, 5, 0));
  w.scene ~= tesseract(Vec4(1, 0, 4, 0));
  w.scene ~= tesseract(Vec4(-1, 0, 4, 0));
  w.scene ~= tesseract(Vec4(0, 0, 4, 1));
  w.scene ~= tesseract(Vec4(0, 0, 4, -1));
  w.scene ~= tesseract(Vec4(0, 1, 4, 0));
  w.scene ~= fivecell(Vec4(4, 2, 4, 0));
  w.scene ~= tesseract(Vec4(4, 0, -4, 0), Vec4(0.2, 1.5, 3, 1));
  w.scene ~= tesseract(Vec4(5.6, 0, -4, 0), Vec4(0.2, 1.5, 3, 1));
  w.scene ~= tesseract(Vec4(4.2, 0, -4, 0), Vec4(1.4, 1.5, 0.2, 1));
  w.scene ~= tesseract(Vec4(4.2, 0, -1.2, 0), Vec4(1.4, 1.5, 0.2, 1));
  w.scene ~= tesseract(Vec4(4, 1.5, -4, 0), Vec4(1.8, 0.2, 3, 1));*/


    w.scene.length = 0;
    //w.scene ~= tesseract!(false, solid_color_gen!(0.5, 0.5, 0.5))(Vec4(-30, -30, -30, -30), Vec4(60, 60, 60, 60));
    //w.scene ~= tesseract!(false, solid_color_gen!(0.5, 0.5, 0.5))(Vec4(-500, -500, -500, -500), Vec4(1000, 1000, 1000, 1000));
    //w.scene ~= tesseract!(false, solid_color_gen!(0.6, 0.5, 0.1))(Vec4(-10, -2, -10, -10), Vec4(20, 2, 20, 20));
    //w.scene ~= tesseract!(false, solid_color_gen!(0.8, 0.1, 0.1))(Vec4(5, 0, 5, 0), Vec4(1, 3, 1, 1));
    //w.scene ~= tesseract!(false, solid_color_gen!(0.8, 0.1, 0.1))(Vec4(5, 0, -5, 0), Vec4(1, 3, 1, 1));
    //w.scene ~= tesseract!(false, solid_color_gen!(0.8, 0.1, 0.1))(Vec4(-5, 0, 5, 0), Vec4(1, 3, 1, 1));
    //w.scene ~= tesseract!(false, solid_color_gen!(0.8, 0.1, 0.1))(Vec4(-5, 0, -5, 0), Vec4(1, 3, 1, 1));
    //w.scene ~= tesseract!(true)(Vec4(0, 1, 1, 0.5), Vec4(1, 1, 1, 1));


    //w.scene ~= tesseract(Vec4(1, 1, 1, 0));

    //view_mat = look_at(camera_pos, Vec3(0, 0, 0), Vec3(0, 1, 0));
    view_mat = Mat4.init;
    view = view_mat.data;
    projection = projection_mat.data;

    compass_projection = compass_projection_mat.data;

    handle_errors!init();
    scope(exit) cleanup();

    {
        auto selected_edges = gen_selected_edges();
        assign_static_cs_data(&selected_edges[0][0]);
    }

    glfwSetKeyCallback(window, &key_callback);
    glfwSetMouseButtonCallback(window, &mouse_button_callback);

    int t = 0;
    int last_width = -1, last_height = -1;
    //float last_fov = fov;
    TickDuration last_time;
    TickDuration extra_time;
    float[30] fpss;
    debug(prof) sw.start();

    while (!glfwWindowShouldClose(window) && !atomicLoad(do_close))
    {
        debug(prof) writeln("tick start");
        debug(prof) sw.reset();

        //dwritef!"lock"("sl state %s", sl_tracker);

        fpss[t % fpss.length] = 1.0e9 / (TickDuration.currSystemTick() - last_time).nsecs();
        float fps = sum(fpss[]) / fpss.length;
        title_str = format("%s %s\0", fps.to!string(), extra_time.to!("usecs", long));
        last_time = TickDuration.currSystemTick();

        process_input();
        if (gravity_on) {
            pd.process_gravity(w);
        }
        pd.fixup();

        debug(prof) profile_checkpoint();

        if (force_window_size_update || last_width != width || last_height != height)
        {
            fov = deg_to_rad(45);
            float r = cast(float)(width) / height;
            final switch (display_mode.to!DisplayMode)
            {
            case DisplayMode.NORMAL:
                break;

            case DisplayMode.SPLIT:
                r /= 2;
                fov *= 1.5;
                break;
            }
            projection_mat = perspective(fov, r, 0.1, 1000);
            compass_projection_mat = perspective(deg_to_rad(45), width, 0.1, 1000);
            //projection_mat = orthographic(-width / 400.0, width / 400.0, -height / 400.0, height / 400.0, -10, 100);
            last_height = height;
            last_width = width;
            //last_fov = fov;
            force_window_size_update = false;

            handle_errors!window_size_update();
        }
        debug(prof) profile_checkpoint();

        //test_rot_mat = rot(test_plane[0], test_plane[1], test_angle);
        Vec4 char_right = pd.right();

        screen_text_data[0].x = -1;
        screen_text_data[0].y = 1;
        screen_text_data[0].x_scale = 0.0005;
        screen_text_data[0].y_scale = 0.0005;
        screen_text_data[0].line_spacing = 0.1;
        screen_text_data[0].a.unsafe_reset();
        screen_text_data[0].a ~= title_str.ptr;

        screen_text_data[1].x = -0.7;
        screen_text_data[1].y = 1;
        screen_text_data[1].x_scale = 0.0008;
        screen_text_data[1].y_scale = 0.0008;
        screen_text_data[1].line_spacing = 0.1;
        final switch (text_display)
        {
        case TextDisplay.NONE:
            screen_text_data[1].a.unsafe_reset();
            break;

        case TextDisplay.BLOCK:
            screen_text_data[1].a = map!"a.toStringz"(scratch_strings).array;
            break;

        case TextDisplay.POS:
            screen_text_data[1].a = [
                format("front:    %6.3f, %6.3f, %6.3f, %6.3f (%6.3f)\0",
                       pd.front.x, pd.front.y, pd.front.z, pd.front.w, pd.front.magnitude()).ptr,
                format("up:       %6.3f, %6.3f, %6.3f, %6.3f (%6.3f)\0",
                       pd.up.x, pd.up.y, pd.up.z, pd.up.w, pd.up.magnitude()).ptr,
                format("right:    %6.3f, %6.3f, %6.3f, %6.3f (%6.3f)\0",
                       char_right.x, char_right.y, char_right.z, char_right.w, char_right.magnitude()).ptr,
                format("normal:   %6.3f, %6.3f, %6.3f, %6.3f (%6.3f)\0",
                       pd.normal.x, pd.normal.y, pd.normal.z, pd.normal.w, pd.normal.magnitude()).ptr,
                format("position: %6.3f, %6.3f, %6.3f, %6.3f (%6.3f)\0",
                       pd.pos.x, pd.pos.y, pd.pos.z, pd.pos.w, pd.pos.magnitude()).ptr,
                ];
            break;

        case TextDisplay.CHUNK: {
            ChunkPos cp = ChunkPos(pd.pos);
            auto c = cp in w.loaded_chunks;
            if (c) {
                screen_text_data[1].a = [
                    format("%s\0", cp).ptr,
                    format("%s\0", c.get_state()).ptr,
                    ];
            }
            break;
        }
        }
        scratch_strings.unsafe_reset();
        debug(prof) profile_checkpoint();

        scratch_strings ~= format("cps_to_load len %s", cps_to_load.length());

        Vec4 flat_front = (pd.front - proj(pd.front, GLOBAL_UP)).normalized();
        Vec4 flat_normal = (pd.normal - proj(pd.normal, GLOBAL_UP)).normalized();
        Vec4 flat_right = cross_p(GLOBAL_UP, flat_front, flat_normal);

        if (char_enabled)
        {
            Mat4 r = Mat4(
                flat_right.x, flat_right.y, flat_right.z, flat_right.w,
                GLOBAL_UP.x, GLOBAL_UP.y, GLOBAL_UP.z, GLOBAL_UP.w,
                flat_front.x, flat_front.y, flat_front.z, flat_front.w,
                flat_normal.x, flat_normal.y, flat_normal.z, flat_normal.w,
                );
            w.character = tesseract!true(pd.pos, 0.6 * Vec4(0.3, 0.8, 0.3, 0.3), r);
        }
        else
        {
            w.character = [];
        }

        Vec3 compass_ = Vec3(-flat_front.x, flat_front.w, flat_front.z) + compass_base_;
        compass = compass_.data();
        debug(prof) profile_checkpoint();

        //assert(0);
        float render_radius = 56;
        float render_height = render_radius * 0.6;
        int chunk_radius = cast(int)(render_radius / CHUNK_SIZE) + 2;
        int chunk_height = cast(int)(render_height / CHUNK_SIZE) + 2;
        load_params.set(LoadParams(pd.pos, chunk_radius, chunk_height));
        //w.load_chunks(load_params.get());

        //scratch_strings ~= to!string(w.loaded_chunks.length);
        //scratch_strings ~= to!string(coords_to_chunkpos(pd.pos));
        {
            // TODO i don't really get why pd.front is "backwards" like this
            targeted_block = w.target_nonempty(pd.pos, -1 * pd.front);
            //BlockPos b = w.target_nonempty(Vec4(1, 2, 3, 4), Vec4(0, -1, 0, 0));
            if (targeted_block != BlockFace.INVALID) {
                scratch_strings ~= to!string(targeted_block);
                enum F = 0.0003;
                size_t loc;
                final switch (targeted_block.face) {
                case Vec4BasisSigned.NX:
                    loc = 2 * 5;
                    break;

                case Vec4BasisSigned.NY:
                    loc = 4 * 5;
                    break;

                case Vec4BasisSigned.NZ:
                    loc = 6 * 5;
                    break;

                case Vec4BasisSigned.NW:
                    loc = 0 * 5;
                    break;

                case Vec4BasisSigned.X:
                    loc = 3 * 5;
                    break;

                case Vec4BasisSigned.Y:
                    loc = 5 * 5;
                    break;

                case Vec4BasisSigned.Z:
                    loc = 7 * 5;
                    break;

                case Vec4BasisSigned.W:
                    loc = 1 * 5;
                    break;

                }
                if (!ui_hidden) {
                    w.scene = tesseract!(false, solid_color_gen!(0.6, 0.6, 0.6))(
                        targeted_block.pos.to_vec4() - F * Vec4(1, 1, 1, 1),
                        (1 + 2 * F) * Vec4(1, 1, 1, 1),
                        )[loc..(loc + 5)];
                } else {
                    w.scene = [];
                }
            } else {
                //scratch_strings ~= "none";
                w.scene = [];
            }
        }
        debug(prof) profile_checkpoint();

        final switch (display_mode.to!DisplayMode)
        {
        case DisplayMode.SPLIT:
        {
            Vec4 vert_pos = pd.pos;
            if (targeted_block != BlockFace.INVALID) {
                int target_y = targeted_block.pos.y;
                switch (targeted_block.face) {
                case Vec4BasisSigned.Y:
                    target_y += 1;
                    break;
                case Vec4BasisSigned.NY:
                    target_y -= 1;
                    break;
                default:
                    break;
                }

                // TODO this doesn't actually catch all occlusions
                int inc = target_y > vert_pos.y ? 1 : -1;
                int x = 0;
                while (cast(int)(floor(vert_pos.y)) != target_y) {
                    vert_pos.y += inc;
                    if (!w.get_block(BlockPos(vert_pos)).is_transparent()) {
                        vert_pos.y -= inc;
                        break;
                    }
                    x++;
                    // TODO lol
                    assert(x < 500);
                }
            }
            {
                // TODO don't do these each frame
                cuboid_uniforms_vertical.base_pos = vert_pos.data();
                cuboid_uniforms_vertical.normal = GLOBAL_UP.data();
                cuboid_uniforms_vertical.right = flat_right.data();
                cuboid_uniforms_vertical.up = flat_normal.data();
                cuboid_uniforms_vertical.front = flat_front.data();

                cuboid_uniforms_vertical.view = view_mat.data();
                cuboid_uniforms_vertical.projection = projection_mat.data();
            }
            generate_cross_section(w, &cuboid_data_vertical[0], vertical_objects, render_radius, render_height, cube_culling,
                                   vert_pos, flat_normal, flat_front, GLOBAL_UP, flat_right);
            debug(prof) profile_checkpoint();
            goto case DisplayMode.NORMAL;

        }

        case DisplayMode.NORMAL:
        {
            {
                // TODO don't do these each frame
                cuboid_uniforms.base_pos = pd.pos.data();
                cuboid_uniforms.normal = pd.normal.data();
                cuboid_uniforms.right = char_right.data();
                cuboid_uniforms.up = pd.up.data();
                cuboid_uniforms.front = pd.front.data();

                cuboid_uniforms.view = view_mat.data();
                cuboid_uniforms.projection = projection_mat.data();
            }

            //scratch_strings.length = 0;
            generate_cross_section(w, &cuboid_data[0], objects, render_radius, render_height, cube_culling,
                                   pd.pos, pd.up, pd.front, pd.normal, char_right);
            debug(prof) profile_checkpoint();
        }
        }

        w.sync_assign_chunk_gl_data();
        render();
        debug(prof) profile_checkpoint();

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

        {
            StopWatch extra_time_sw;
            extra_time_sw.start();
            wait_for_next_frame();
            extra_time = extra_time_sw.peek().to!TickDuration();

        }
        debug(prof) profile_checkpoint();

        t++;
    }
}

extern (C) void mouse_button_callback(GLFWwindow* window, int button, int action, int mods)
{
    if (action != GLFWKeyStatus.GLFW_PRESS) {
        return;
    }

    if (targeted_block == BlockFace.INVALID) {
        return;
    }

    switch (button) {
    case GLFWMouseButton.GLFW_MOUSE_BUTTON_LEFT:
        if (true) {
            writeln(targeted_block);
            BlockPos new_pos = targeted_block.pos + targeted_block.face.to_ipos!BlockPos();
            writefln("creating at %s", new_pos);
            w.set_block(new_pos, BlockType.TEST);
        }
        break;

    case GLFWMouseButton.GLFW_MOUSE_BUTTON_RIGHT:
        if (true) {
            writefln("deleting at %s", targeted_block.pos);
            w.set_block(targeted_block.pos, BlockType.NONE);
            targeted_block = BlockFace.INVALID;
        }
        break;

    default:
        break;
    }
}

extern (C) void key_callback(GLFWwindow* window, int key, int scancode, int action, int mods)
{
    if (action != GLFWKeyStatus.GLFW_PRESS)
    {
        return;
    }

    switch (key)
    {
    case GLFWKey.GLFW_KEY_SPACE: {
        gravity_on = true;
        pd.jump();
        break;
    }

    case GLFWKey.GLFW_KEY_BACKSPACE: {
        ui_hidden ^= true;
        break;
    }

        version(none) {
            writeln("front: ", pd.front);
            writeln("up: ", pd.up);
            writeln("normal: ", pd.normal);
            writeln("right: ", pd.right());
            writeln("position: ", pd.pos);

            writeln(dot_p(pd.normal, pd.up));
            writeln(dot_p(pd.front, pd.up));
            writeln(dot_p(pd.front, pd.normal));

            Vec4 flat_front = pd.front - proj(pd.front, GLOBAL_UP);
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

    case GLFWKey.GLFW_KEY_LEFT_BRACKET:
    {
        if (targeted_block != BlockFace.INVALID) {
            writeln(targeted_block);
            BlockPos new_pos = targeted_block.pos + targeted_block.face.to_ipos!BlockPos();
            writefln("creating at %s", new_pos);
            w.set_block(new_pos, BlockType.TEST);
        }
        break;
    }

    case GLFWKey.GLFW_KEY_RIGHT_BRACKET:
    {
        if (targeted_block != BlockFace.INVALID) {
            writefln("deleting at %s", targeted_block.pos);
            w.set_block(targeted_block.pos, BlockType.NONE);
            targeted_block = BlockFace.INVALID;
        }
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
        pd.pos = Vec4(0, 0.7, 0, 0.5);
        pd.front = Vec4(0, 0.3, 1, 0).normalized();
        pd.up = Vec4(0, 1, -0.3, 0).normalized();
        pd.normal = Vec4(0, 0, 0, 1);
        camera_pos.z = 3;
        view_mat = look_at(camera_pos, Vec3(0, 0, 0), Vec3(0, 1, 0));
        break;
    }

    case GLFWKey.GLFW_KEY_2:
    {
        pd.pos = Vec4(0, .7, 0, 0);
        pd.front = Vec4(-.01, 0, 1, 0).normalized();
        pd.up = Vec4(0, 1, 0, 0);
        pd.normal = Vec4(0, 0, 0, 1);
        break;
    }

    case GLFWKey.GLFW_KEY_3:
    {
        pd.front = Vec4(0, 0, -1, 1).normalized();
        pd.up = Vec4(0, 1, 0, 0).normalized();
        pd.normal = Vec4(1, 0, -1, -1).normalized();
        break;
    }

    case GLFWKey.GLFW_KEY_4:
    {
        pd.front = Vec4(0, 0, -1, 1).normalized();
        pd.up = Vec4(0, 1, 0, 0).normalized();
        pd.normal = Vec4(1, 0, 1, 1).normalized();
        break;
    }

    case GLFWKey.GLFW_KEY_EQUAL:
    {
        text_display = inc_enum!TextDisplay(text_display);
        break;
    }

    case GLFWKey.GLFW_KEY_ESCAPE:
    {
        atomicStore(do_close, true);
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
        pd.move_flat!"front"(-speed, w);
    }
    if (get_key(GLFWKey.GLFW_KEY_S) == GLFWKeyStatus.GLFW_PRESS)
    {
        pd.move_flat!"front"(speed, w);
    }
    if (get_key(GLFWKey.GLFW_KEY_R) == GLFWKeyStatus.GLFW_PRESS)
    {
        gravity_on = false;
        pd.move!"GLOBAL_UP"(speed, w);
    }
    if (get_key(GLFWKey.GLFW_KEY_F) == GLFWKeyStatus.GLFW_PRESS)
    {
        gravity_on = false;
        pd.move!"GLOBAL_UP"(-speed, w);
    }
    if (get_key(GLFWKey.GLFW_KEY_Q) == GLFWKeyStatus.GLFW_PRESS)
    {
        pd.move!"normal"(speed, w);
    }
    if (get_key(GLFWKey.GLFW_KEY_E) == GLFWKeyStatus.GLFW_PRESS)
    {
        pd.move!"normal"(-speed, w);
    }
    if (get_key(GLFWKey.GLFW_KEY_A) == GLFWKeyStatus.GLFW_PRESS)
    {
        pd.move!"right()"(-speed, w);
    }
    if (get_key(GLFWKey.GLFW_KEY_D) == GLFWKeyStatus.GLFW_PRESS)
    {
        pd.move!"right()"(speed, w);
    }


    if (get_key(GLFWKey.GLFW_KEY_J) == GLFWKeyStatus.GLFW_PRESS)
    {
        pd.rotate!("GLOBAL_UP", "normal")(-rot_speed);
    }
    if (get_key(GLFWKey.GLFW_KEY_L) == GLFWKeyStatus.GLFW_PRESS)
    {
        pd.rotate!("GLOBAL_UP", "normal")(rot_speed);
    }
    if (get_key(GLFWKey.GLFW_KEY_U) == GLFWKeyStatus.GLFW_PRESS)
    {
        pd.rotate!("GLOBAL_UP", "right()")(-other_rot_speed);
    }
    if (get_key(GLFWKey.GLFW_KEY_O) == GLFWKeyStatus.GLFW_PRESS)
    {
        pd.rotate!("GLOBAL_UP", "right()")(other_rot_speed);
    }
    if (get_key(GLFWKey.GLFW_KEY_M) == GLFWKeyStatus.GLFW_PRESS)
    {
        pd.rotate!("GLOBAL_UP", "front")(-other_rot_speed);
    }
    if (get_key(GLFWKey.GLFW_KEY_PERIOD) == GLFWKeyStatus.GLFW_PRESS)
    {
        pd.rotate!("GLOBAL_UP", "front")(other_rot_speed);
    }
    if (get_key(GLFWKey.GLFW_KEY_I) == GLFWKeyStatus.GLFW_PRESS)
    {
        pd.y_rotate(rot_speed);
    }
    if (get_key(GLFWKey.GLFW_KEY_K) == GLFWKeyStatus.GLFW_PRESS)
    {
        pd.y_rotate(-rot_speed);
    }

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


    // mouse movement
    {
        immutable double mouse_speed = 0.001;
        double xpos, ypos;
        glfwGetCursorPos(window, &xpos, &ypos);
        //writefln("%f %f", xpos, ypos);


        if (get_key(GLFWKey.GLFW_KEY_LEFT_ALT) == GLFWKeyStatus.GLFW_PRESS || get_key(GLFWKey.GLFW_KEY_LEFT) == GLFWKeyStatus.GLFW_PRESS) {
            if (xpos != 0) {
                pd.rotate!("GLOBAL_UP", "normal")(xpos * mouse_speed);
            }
            if (ypos != 0) {
                pd.rotate!("GLOBAL_UP", "right()")(ypos * mouse_speed);
            }
        } else {
            if (xpos != 0) {
                pd.rotate!("GLOBAL_UP", "normal")(xpos * mouse_speed);
            }
            if (ypos != 0) {
                pd.y_rotate(-ypos * mouse_speed);
            }
        }

        glfwSetCursorPos(window, 0, 0);
    }
}


/*
 * plan:
 * - memory pool of tesseract chunks
 * - load and render chunks inside surrounding 3-sphere (or similar)
 * - block-based lighting
 *
 */
