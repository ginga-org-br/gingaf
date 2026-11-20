#include "my_application.h"

#include <epoxy/egl.h>
#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "flutter/generated_plugin_registrant.h"
#include "usage.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

static void first_frame_cb(MyApplication* self, FlView* view) {
  GtkWindow* window = GTK_WINDOW(gtk_widget_get_toplevel(GTK_WIDGET(view)));
  gtk_widget_show_all(GTK_WIDGET(window));
  gtk_window_deiconify(window);
  gtk_window_present(window);
}

static gint get_window_monitor_index(GtkWindow* window) {
  GdkDisplay* display = gtk_widget_get_display(GTK_WIDGET(window));
  if (display == nullptr) return 0;
  GdkWindow* gdk_win = gtk_widget_get_window(GTK_WIDGET(window));
  GdkMonitor* current =
      gdk_win != nullptr ? gdk_display_get_monitor_at_window(display, gdk_win)
                         : nullptr;
  int n = gdk_display_get_n_monitors(display);
  for (int i = 0; i < n; ++i) {
    if (gdk_display_get_monitor(display, i) == current) {
      return i;
    }
  }
  return 0;
}

static void get_screen_dimensions(GtkWindow* window, gint* out_w, gint* out_h) {
  gint w = 1920;
  gint h = 1080;
  GdkDisplay* display = gtk_widget_get_display(GTK_WIDGET(window));
  if (display != nullptr) {
    GdkMonitor* monitor = nullptr;
    GdkWindow* gdk_win = gtk_widget_get_window(GTK_WIDGET(window));
    if (gdk_win != nullptr) {
      monitor = gdk_display_get_monitor_at_window(display, gdk_win);
    }
    if (monitor == nullptr) {
      monitor = gdk_display_get_primary_monitor(display);
    }
    if (monitor == nullptr && gdk_display_get_n_monitors(display) > 0) {
      monitor = gdk_display_get_monitor(display, 0);
    }
    if (monitor != nullptr) {
      GdkRectangle geom;
      gdk_monitor_get_geometry(monitor, &geom);
      if (geom.width > 0 && geom.height > 0) {
        w = geom.width;
        h = geom.height;
      }
    }
  }
  if (out_w) *out_w = w;
  if (out_h) *out_h = h;
}

static void wsl_toggle_maximize(GtkWindow* window) {
  gboolean is_max = GPOINTER_TO_INT(
      g_object_get_data(G_OBJECT(window), "wsl_maximized"));
  GtkWidget* max_img = GTK_WIDGET(
      g_object_get_data(G_OBJECT(window), "wsl_max_image"));
  if (!is_max) {
    gint mon_idx = get_window_monitor_index(window);
    gtk_window_fullscreen_on_monitor(window, gtk_window_get_screen(window),
                                     mon_idx);
    g_object_set_data(G_OBJECT(window), "wsl_maximized", GINT_TO_POINTER(1));
    if (max_img != nullptr && GTK_IS_IMAGE(max_img)) {
      gtk_image_set_from_icon_name(GTK_IMAGE(max_img),
                                   "window-restore-symbolic",
                                   GTK_ICON_SIZE_MENU);
    }
  } else {
    gtk_window_unfullscreen(window);
    g_object_set_data(G_OBJECT(window), "wsl_maximized", GINT_TO_POINTER(0));
    if (max_img != nullptr && GTK_IS_IMAGE(max_img)) {
      gtk_image_set_from_icon_name(GTK_IMAGE(max_img),
                                   "window-maximize-symbolic",
                                   GTK_ICON_SIZE_MENU);
    }
  }
}

static void wsl_minimize_clicked_cb(GtkButton*, gpointer user_data) {
  gtk_window_iconify(GTK_WINDOW(user_data));
}

static void wsl_maximize_clicked_cb(GtkButton*, gpointer user_data) {
  wsl_toggle_maximize(GTK_WINDOW(user_data));
}

static void wsl_close_clicked_cb(GtkButton*, gpointer user_data) {
  gtk_window_close(GTK_WINDOW(user_data));
}

static gboolean wsl_header_button_press_cb(GtkWidget*,
                                           GdkEventButton* event,
                                           gpointer user_data) {
  GtkWindow* window = GTK_WINDOW(user_data);
  if (event->button == 1) {
    if (event->type == GDK_2BUTTON_PRESS) {
      wsl_toggle_maximize(window);
      return TRUE;
    }
    if (event->type == GDK_BUTTON_PRESS &&
        !GPOINTER_TO_INT(
            g_object_get_data(G_OBJECT(window), "wsl_maximized"))) {
      gtk_window_begin_move_drag(window, event->button,
                                 static_cast<gint>(event->x_root),
                                 static_cast<gint>(event->y_root),
                                 event->time);
      return TRUE;
    }
  }
  return FALSE;
}

static GtkWidget* create_wsl_titlebutton(const gchar* icon_name,
                                         GCallback callback,
                                         GtkWindow* window,
                                         GtkWidget** out_image) {
  GtkWidget* btn = gtk_button_new();
  gtk_widget_set_can_focus(btn, FALSE);
  GtkStyleContext* sc = gtk_widget_get_style_context(btn);
  gtk_style_context_add_class(sc, "titlebutton");
  gtk_style_context_add_class(sc, "flat");
  GtkWidget* img = gtk_image_new_from_icon_name(icon_name, GTK_ICON_SIZE_MENU);
  gtk_container_add(GTK_CONTAINER(btn), img);
  g_signal_connect(btn, "clicked", callback, window);
  if (out_image != nullptr) {
    *out_image = img;
  }
  return btn;
}

static void window_method_call_cb(FlMethodChannel* channel,
                                  FlMethodCall* method_call,
                                  gpointer user_data) {
  GtkWindow* window = GTK_WINDOW(user_data);
  const gchar* name = fl_method_call_get_name(method_call);

  if (g_strcmp0(name, "resize") == 0) {
    FlValue* args = fl_method_call_get_args(method_call);
    if (args != nullptr && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      FlValue* w_val = fl_value_lookup_string(args, "width");
      FlValue* h_val = fl_value_lookup_string(args, "height");
      if (w_val != nullptr && h_val != nullptr) {
        int width = fl_value_get_int(w_val);
        int height = fl_value_get_int(h_val);
        gtk_window_resize(window, width, height);
      }
    }
    g_autoptr(FlMethodResponse) response =
        FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
    fl_method_call_respond(method_call, response, nullptr);
  } else if (g_strcmp0(name, "autoResize") == 0) {
    gboolean wsl_max = GPOINTER_TO_INT(
        g_object_get_data(G_OBJECT(window), "wsl_maximized"));
    if (!gtk_window_is_maximized(window) && !wsl_max) {
      gint sw = 1920;
      gint sh = 1080;
      get_screen_dimensions(window, &sw, &sh);
      int w = MIN(1280, sw - 60);
      int h = MIN(720, sh - 100);
      gtk_window_resize(window, w, h);
    }
    g_autoptr(FlMethodResponse) response =
        FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
    fl_method_call_respond(method_call, response, nullptr);
  } else if (g_strcmp0(name, "releaseMainThreadEgl") == 0) {
    if (gdk_gl_context_get_current() == nullptr) {
      EGLDisplay dpy = eglGetCurrentDisplay();
      EGLContext ctx = eglGetCurrentContext();
      if (dpy != EGL_NO_DISPLAY && ctx != EGL_NO_CONTEXT) {
        eglMakeCurrent(dpy, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
      }
    }
    g_autoptr(FlMethodResponse) response =
        FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
    fl_method_call_respond(method_call, response, nullptr);
  } else {
    g_autoptr(FlMethodResponse) response =
        FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
    fl_method_call_respond(method_call, response, nullptr);
  }
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  gboolean is_wsl = (g_getenv("WSL_DISTRO_NAME") != nullptr ||
                     g_getenv("WSL_INTEROP") != nullptr);

  GtkSettings* settings = gtk_settings_get_default();
  if (settings != nullptr) {
    g_object_set(settings, "gtk-decoration-layout",
                 ":minimize,maximize,close", nullptr);
  }

  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif

  GtkWidget* wsl_vbox = nullptr;
  if (is_wsl) {
    gtk_window_set_title(window, "gingaf");
    gtk_window_set_decorated(window, FALSE);
    wsl_vbox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
    GtkWidget* event_box = gtk_event_box_new();
    gtk_event_box_set_above_child(GTK_EVENT_BOX(event_box), FALSE);
    gtk_widget_add_events(event_box, GDK_BUTTON_PRESS_MASK);
    g_signal_connect(event_box, "button-press-event",
                     G_CALLBACK(wsl_header_button_press_cb), window);

    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_header_bar_set_title(header_bar, "gingaf");
    gtk_header_bar_set_show_close_button(header_bar, FALSE);

    GtkWidget* btn_box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 4);
    GtkWidget* min_btn = create_wsl_titlebutton(
        "window-minimize-symbolic", G_CALLBACK(wsl_minimize_clicked_cb),
        window, nullptr);
    GtkWidget* max_img = nullptr;
    GtkWidget* max_btn = create_wsl_titlebutton(
        "window-maximize-symbolic", G_CALLBACK(wsl_maximize_clicked_cb),
        window, &max_img);
    g_object_set_data(G_OBJECT(window), "wsl_max_image", max_img);
    GtkWidget* close_btn = create_wsl_titlebutton(
        "window-close-symbolic", G_CALLBACK(wsl_close_clicked_cb),
        window, nullptr);
    gtk_box_pack_start(GTK_BOX(btn_box), min_btn, FALSE, FALSE, 0);
    gtk_box_pack_start(GTK_BOX(btn_box), max_btn, FALSE, FALSE, 0);
    gtk_box_pack_start(GTK_BOX(btn_box), close_btn, FALSE, FALSE, 0);
    gtk_header_bar_pack_end(header_bar, btn_box);

    gtk_container_add(GTK_CONTAINER(event_box), GTK_WIDGET(header_bar));
    gtk_box_pack_start(GTK_BOX(wsl_vbox), event_box, FALSE, FALSE, 0);
    gtk_container_add(GTK_CONTAINER(window), wsl_vbox);
  } else if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "gingaf");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_header_bar_set_decoration_layout(header_bar,
                                         ":minimize,maximize,close");
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
    gtk_window_set_decorated(window, TRUE);
  } else {
    gtk_window_set_title(window, "gingaf");
    gtk_window_set_decorated(window, TRUE);
  }

  gint sw = 1920;
  gint sh = 1080;
  get_screen_dimensions(window, &sw, &sh);
  int default_w = MIN(1280, sw - 60);
  int default_h = MIN(720, sh - 100);

  gtk_window_set_default_size(window, default_w, default_h);
  gtk_window_set_resizable(window, TRUE);

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  GdkRGBA background_color;
  gdk_rgba_parse(&background_color, "#000000");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  if (wsl_vbox != nullptr) {
    gtk_box_pack_start(GTK_BOX(wsl_vbox), GTK_WIDGET(view), TRUE, TRUE, 0);
  } else {
    gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));
  }

  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  FlBinaryMessenger* messenger =
      fl_engine_get_binary_messenger(fl_view_get_engine(view));
  g_autoptr(FlStandardMethodCodec) window_codec = fl_standard_method_codec_new();
  FlMethodChannel* window_channel = fl_method_channel_new(
      messenger, "gingaf/window", FL_METHOD_CODEC(window_codec));
  fl_method_channel_set_method_call_handler(window_channel, window_method_call_cb,
                                            window, nullptr);

  gtk_widget_grab_focus(GTK_WIDGET(view));
  gtk_widget_show_all(GTK_WIDGET(window));
  gtk_window_present(window);
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application,
                                                  gchar*** arguments,
                                                  int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);

  for (gchar** arg = *arguments + 1; *arg != nullptr; ++arg) {
    if (g_strcmp0(*arg, "-h") == 0 || g_strcmp0(*arg, "--help") == 0) {
      g_print("%s", kUsageMessage);
      *exit_status = 0;
      return TRUE;
    }
  }

  gboolean has_args = (*arguments != nullptr && *(*arguments + 1) != nullptr);
  const gchar* app_env = g_getenv("APP");
  const gchar* config_env = g_getenv("CONFIG");
  const gchar* flutter_engine_env = g_getenv("FLUTTER_ENGINE_SWITCHES");
  gboolean has_env = (app_env != nullptr && *app_env != '\0') ||
                     (config_env != nullptr && *config_env != '\0') ||
                     (flutter_engine_env != nullptr && *flutter_engine_env != '\0');

  if (!has_args && !has_env) {
    g_printerr("%s", kUsageMessage);
    *exit_status = 1;
    return TRUE;
  }

  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
    g_warning("Failed to register: %s", error->message);
    *exit_status = 1;
    return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     G_APPLICATION_NON_UNIQUE, nullptr));
}
