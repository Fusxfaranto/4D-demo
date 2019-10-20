
import std.stdio : writeln;
import std.conv : to;
import std.math : PI, sin, cos, acos, sgn, abs;
import std.datetime : TickDuration;
import std.datetime.stopwatch : StopWatch;
import std.array : array;
import std.algorithm : sum, map;
import std.typecons : Tuple, tuple;

import util;
import render_bindings;
import matrix;
import shapes;
import chunk;
import cross_section;
import world;


World w;

BlockFace targeted_block = BlockFace.INVALID;


Vec3 camera_pos = Vec3(0, 0, 3);
// EMV3 camera_front = EMV3(0, 0, 0, -1);
// Vec3 camera_up = Vec3(0, 1, 0);
float fov;

Vec4 char_pos = Vec4(0, 0.4, 0, 0.5);
Vec4 char_front = Vec4(0, 0.3, 1, 0).normalized();
Vec4 char_up = Vec4(0, 1, -0.3, 0).normalized();
Vec4 char_normal = Vec4(0, 0, 0, 1);
enum Vec4 global_up = Vec4(0, 1, 0, 0);

Mat4 view_mat, projection_mat, compass_projection_mat;

bool char_enabled = false;
bool force_window_size_update = true;
bool cube_culling = true;


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

bool do_close = false;


void main()
{
    string title_str = "\0";
    title = title_str.ptr;

    width = 1280;
    height = 800;
    display_mode = DisplayMode.NORMAL;

    // GC.disable();
    // scope(exit) GC.enable();


    Vec3 compass_base_ = Vec3(0, 0, 0);
    compass_base = compass_base_.data();

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
    float[30] fpss;
    debug(prof) sw.start();

    while (!glfwWindowShouldClose(window) && !do_close)
    {
        debug(prof) writeln("tick start");
        debug(prof) sw.reset();

        fpss[t % fpss.length] = 1.0e9 / (TickDuration.currSystemTick() - last_time).nsecs();
        float fps = sum(fpss[]) / fpss.length;
        title_str = fps.to!string() ~ '\0';
        last_time = TickDuration.currSystemTick();

        process_input();
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

        Vec4 char_right = cross_p(char_up, char_front, char_normal);

        //test_rot_mat = rot(test_plane[0], test_plane[1], test_angle);

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
                       char_front.x, char_front.y, char_front.z, char_front.w, char_front.magnitude()).ptr,
                format("up:       %6.3f, %6.3f, %6.3f, %6.3f (%6.3f)\0",
                       char_up.x, char_up.y, char_up.z, char_up.w, char_up.magnitude()).ptr,
                format("right:    %6.3f, %6.3f, %6.3f, %6.3f (%6.3f)\0",
                       char_right.x, char_right.y, char_right.z, char_right.w, char_right.magnitude()).ptr,
                format("normal:   %6.3f, %6.3f, %6.3f, %6.3f (%6.3f)\0",
                       char_normal.x, char_normal.y, char_normal.z, char_normal.w, char_normal.magnitude()).ptr,
                format("position: %6.3f, %6.3f, %6.3f, %6.3f (%6.3f)\0",
                       char_pos.x, char_pos.y, char_pos.z, char_pos.w, char_pos.magnitude()).ptr,
                ];
            break;
        }
        scratch_strings.unsafe_reset();
        debug(prof) profile_checkpoint();

        Vec4 flat_front = (char_front - proj(char_front, global_up)).normalized();
        Vec4 flat_normal = (char_normal - proj(char_normal, global_up)).normalized();
        Vec4 flat_right = cross_p(global_up, flat_front, flat_normal);

        if (char_enabled)
        {
            Mat4 r = Mat4(
                flat_right.x, flat_right.y, flat_right.z, flat_right.w,
                global_up.x, global_up.y, global_up.z, global_up.w,
                flat_front.x, flat_front.y, flat_front.z, flat_front.w,
                flat_normal.x, flat_normal.y, flat_normal.z, flat_normal.w,
                );
            w.character = tesseract!true(char_pos, 0.6 * Vec4(0.3, 0.8, 0.3, 0.3), r);
        }
        else
        {
            w.character = [];
        }

        Vec3 compass_ = Vec3(-flat_front.x, flat_front.w, flat_front.z) + compass_base_;
        compass = compass_.data();
        debug(prof) profile_checkpoint();

        float render_radius = 700;
        //load_chunks(char_pos, cast(int)(render_radius / CHUNK_SIZE) + 1, w.loaded_chunks);
        w.load_chunks(char_pos, 3);

        //scratch_strings ~= to!string(w.loaded_chunks.length);
        //scratch_strings ~= to!string(coords_to_chunkpos(char_pos));
        {
            // TODO i don't really get why char_front is "backwards" like this
            targeted_block = w.target_nonempty(char_pos, -1 * char_front);
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
                w.scene = tesseract!(false, solid_color_gen!(0.6, 0.6, 0.6))(
                    targeted_block.pos.to_vec4() - F * Vec4(1, 1, 1, 1),
                    (1 + 2 * F) * Vec4(1, 1, 1, 1),
                    )[loc..(loc + 5)];
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
            {
                // TODO don't do these each frame
                cuboid_uniforms_vertical.base_pos = char_pos.data();
                cuboid_uniforms_vertical.normal = global_up.data();
                cuboid_uniforms_vertical.right = flat_right.data();
                cuboid_uniforms_vertical.up = flat_normal.data();
                cuboid_uniforms_vertical.front = flat_front.data();

                cuboid_uniforms_vertical.view = view_mat.data();
                cuboid_uniforms_vertical.projection = projection_mat.data();
            }
            generate_cross_section(w, &cuboid_data_vertical[0], vertical_objects, render_radius, cube_culling,
                                   char_pos, flat_normal, flat_front, global_up, flat_right);
            debug(prof) profile_checkpoint();
            goto case DisplayMode.NORMAL;

        }

        case DisplayMode.NORMAL:
        {
            {
                // TODO don't do these each frame
                cuboid_uniforms.base_pos = char_pos.data();
                cuboid_uniforms.normal = char_normal.data();
                cuboid_uniforms.right = char_right.data();
                cuboid_uniforms.up = char_up.data();
                cuboid_uniforms.front = char_front.data();

                cuboid_uniforms.view = view_mat.data();
                cuboid_uniforms.projection = projection_mat.data();
            }

            //scratch_strings.length = 0;
            generate_cross_section(w, &cuboid_data[0], objects, render_radius, cube_culling,
                          char_pos, char_up, char_front, char_normal, char_right);
            debug(prof) profile_checkpoint();
        }
        }

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

        wait_for_next_frame();
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
        char_front = Vec4(0, 0, -1, 1).normalized();
        char_up = Vec4(0, 1, 0, 0).normalized();
        char_normal = Vec4(1, 0, -1, -1).normalized();
        break;
    }

    case GLFWKey.GLFW_KEY_4:
    {
        char_front = Vec4(0, 0, -1, 1).normalized();
        char_up = Vec4(0, 1, 0, 0).normalized();
        char_normal = Vec4(1, 0, 1, 1).normalized();
        break;
    }

    case GLFWKey.GLFW_KEY_EQUAL:
    {
        text_display = inc_enum!TextDisplay(text_display);
        break;
    }

    case GLFWKey.GLFW_KEY_ESCAPE:
    {
        do_close = true;
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


    // mouse movement
    {
        immutable double mouse_speed = 0.001;
        double xpos, ypos;
        glfwGetCursorPos(window, &xpos, &ypos);
        //writefln("%f %f", xpos, ypos);


        if (get_key(GLFWKey.GLFW_KEY_LEFT_ALT) == GLFWKeyStatus.GLFW_PRESS) {
            if (xpos != 0) {
                Mat4 r = rot!false(global_up, char_normal, xpos * mouse_speed);
                char_front = (r * char_front).normalized();
                char_up = (r * char_up).normalized();
            }
            if (ypos != 0) {
                Mat4 r = rot!false(global_up, cross_p(char_up, char_front, char_normal), ypos * mouse_speed);
                char_front = (r * char_front).normalized();
                char_normal = (r * char_normal).normalized();
                char_up = (r * char_up).normalized();
            }
        } else {
            if (xpos != 0) {
                Mat4 r = rot!false(global_up, char_normal, xpos * mouse_speed);
                char_front = (r * char_front).normalized();
                char_up = (r * char_up).normalized();
            }
            if (ypos != 0) {
                if (
                    (char_front.y > -y_limit && ypos < 0) ||
                    (char_front.y < y_limit && ypos > 0)
                    )
                {
                    Mat4 r = rot(char_up, char_front, -ypos * mouse_speed);
                    char_front = (r * char_front).normalized();
                    char_up = (r * char_up).normalized();
                }
            }
        }

        glfwSetCursorPos(window, 0, 0);
    }


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
