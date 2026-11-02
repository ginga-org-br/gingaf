#include "my_application.h"

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

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  GtkWindow* window = GTK_WINDOW(gtk_widget_get_toplevel(GTK_WIDGET(view)));
  gtk_widget_show_all(GTK_WIDGET(window));
  gtk_window_deiconify(window);
  gtk_window_present(window);
}

static void get_screen_dimensions(GtkWindow* window, gint* out_w, gint* out_h) {
  gint w = 1920;
  gint h = 1080;
  GdkDisplay* display = gtk_widget_get_display(GTK_WIDGET(window));
  if (display != nullptr) {
    GdkMonitor* monitor = gdk_display_get_primary_monitor(display);
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
    FlValue* args = fl_method_call_get_args(method_call);
    gboolean playground = FALSE;
    if (args != nullptr && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      FlValue* pg_val = fl_value_lookup_string(args, "playground");
      if (pg_val != nullptr) {
        playground = fl_value_get_bool(pg_val);
      }
    }
    gint sw = 1920;
    gint sh = 1080;
    get_screen_dimensions(window, &sw, &sh);
    int w = playground ? ((sw >= 1920) ? 1920 : (sw - 60)) : (MIN(1280, sw - 60));
    int h = playground ? ((sh >= 1080) ? 800 : (sh - 100)) : (MIN(720, sh - 100));
    gtk_window_resize(window, w, h);
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

  gboolean use_header_bar = TRUE;
  if (g_getenv("WSL_DISTRO_NAME") != nullptr || g_getenv("WSL_INTEROP") != nullptr) {
    use_header_bar = FALSE;
  }
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "gingaf");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "gingaf");
  }

  gboolean is_playground = FALSE;
  const gchar* pg_env = g_getenv("GINGA_PLAYGROUND");
  if (pg_env != nullptr && (g_strcmp0(pg_env, "true") == 0 || g_strcmp0(pg_env, "1") == 0 || g_strcmp0(pg_env, "yes") == 0)) {
    is_playground = TRUE;
  }
  const gchar* pg_env_lower = g_getenv("ginga_playground");
  if (pg_env_lower != nullptr && (g_strcmp0(pg_env_lower, "true") == 0 || g_strcmp0(pg_env_lower, "1") == 0 || g_strcmp0(pg_env_lower, "yes") == 0)) {
    is_playground = TRUE;
  }
  if (self->dart_entrypoint_arguments != nullptr) {
    for (gchar** arg = self->dart_entrypoint_arguments; *arg != nullptr; ++arg) {
      if (g_strcmp0(*arg, "--playground") == 0 || g_strcmp0(*arg, "-p") == 0 ||
          g_str_has_prefix(*arg, "--playground=") || g_str_has_prefix(*arg, "-p=") ||
          strstr(*arg, "GINGA_PLAYGROUND=true") != nullptr) {
        is_playground = TRUE;
        break;
      }
    }
  }
  const gchar* flutter_engine_env = g_getenv("FLUTTER_ENGINE_SWITCHES");
  if (flutter_engine_env != nullptr && strstr(flutter_engine_env, "GINGA_PLAYGROUND=true") != nullptr) {
    is_playground = TRUE;
  }

  gint sw = 1920;
  gint sh = 1080;
  get_screen_dimensions(window, &sw, &sh);
  int default_w = is_playground ? ((sw >= 1920) ? 1920 : (sw - 60)) : (MIN(1280, sw - 60));
  int default_h = is_playground ? ((sh >= 1080) ? 800 : (sh - 100)) : (MIN(720, sh - 100));

  gtk_window_set_default_size(window, default_w, default_h);
  gtk_window_set_position(window, GTK_WIN_POS_CENTER);
  gtk_window_set_decorated(window, TRUE);

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  GdkRGBA background_color;
  gdk_rgba_parse(&background_color, "#000000");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

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
