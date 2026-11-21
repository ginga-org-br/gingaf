#include <cstdlib>
#include <cstring>
#include <dlfcn.h>
#include <epoxy/gl.h>
#include <mpv/client.h>
#include <mpv/render.h>
#include <string>
#include <unistd.h>

#include "my_application.h"

extern "C" __attribute__((visibility("default"))) int mpv_set_option_string(
    mpv_handle* ctx,
    const char* name,
    const char* data) {
  using MpvOptFn = int (*)(mpv_handle*, const char*, const char*);
  static MpvOptFn real_fn = reinterpret_cast<MpvOptFn>(
      dlsym(RTLD_NEXT, "mpv_set_option_string"));
  if (real_fn == nullptr) {
    return MPV_ERROR_UNINITIALIZED;
  }
  if (name != nullptr && std::strcmp(name, "video-sync") == 0) {
    real_fn(ctx, "profile", "fast");
    real_fn(ctx, "vd-lavc-threads", "4");
    if (g_file_test("/usr/lib/wsl/lib/libnvcuvid.so.1", G_FILE_TEST_EXISTS)) {
      real_fn(ctx, "hwdec", "nvdec-copy,auto-safe");
    } else {
      real_fn(ctx, "hwdec", "auto-safe");
    }
  }
  return real_fn(ctx, name, data);
}

extern "C" __attribute__((visibility("default"))) int
mpv_render_context_render(
    mpv_render_context* ctx,
    mpv_render_param* params) {
  using MpvRenderFn = int (*)(mpv_render_context*, mpv_render_param*);
  static MpvRenderFn real_fn = reinterpret_cast<MpvRenderFn>(
      dlsym(RTLD_NEXT, "mpv_render_context_render"));
  if (real_fn == nullptr) {
    return MPV_ERROR_UNINITIALIZED;
  }
  int no_block = 0;
  mpv_render_param patched[8];
  int i = 0;
  while (params != nullptr && params[i].type != MPV_RENDER_PARAM_INVALID &&
         i < 6) {
    patched[i] = params[i];
    i++;
  }
  patched[i] = mpv_render_param{MPV_RENDER_PARAM_BLOCK_FOR_TARGET_TIME,
                                &no_block};
  patched[i + 1] = mpv_render_param{MPV_RENDER_PARAM_INVALID, nullptr};
  int ret = real_fn(ctx, patched);
  glFinish();
  return ret;
}

int main(int argc, char** argv) {
  if (g_getenv("WSL_DISTRO_NAME") != nullptr ||
      g_getenv("WSL_INTEROP") != nullptr) {
    setenv("GALLIUM_DRIVER", "d3d12", 0);
    if (g_file_test("/usr/lib/wsl/lib/libcuda.so.1", G_FILE_TEST_EXISTS)) {
      setenv("MESA_D3D12_DEFAULT_ADAPTER_NAME", "NVIDIA", 0);
    } else {
      setenv("LIBVA_DRIVER_NAME", "d3d12", 0);
    }
    if (g_getenv("WAYLAND_DISPLAY") != nullptr) {
      setenv("GDK_BACKEND", "wayland", 0);
    }
    if (g_file_test("/usr/share/icons/Adwaita/cursors", G_FILE_TEST_IS_DIR)) {
      setenv("XCURSOR_THEME", "Adwaita", 0);
      setenv("XCURSOR_SIZE", "24", 0);
    }
    setenv("PIPEWIRE_DEBUG", "0", 0);

    if (g_getenv("GINGA_WSL_LD_READY") == nullptr &&
        g_file_test("/usr/lib/wsl/lib/libd3d12.so", G_FILE_TEST_EXISTS)) {
      const char* ld_path = std::getenv("LD_LIBRARY_PATH");
      if (ld_path == nullptr ||
          std::strstr(ld_path, "/usr/lib/wsl/lib") == nullptr) {
        std::string new_ld = "/usr/lib/wsl/lib";
        if (ld_path != nullptr && *ld_path != '\0') {
          new_ld += ":";
          new_ld += ld_path;
        }
        setenv("LD_LIBRARY_PATH", new_ld.c_str(), 1);
        setenv("GINGA_WSL_LD_READY", "1", 1);
        g_autofree gchar* exe_path =
            g_file_read_link("/proc/self/exe", nullptr);
        if (exe_path != nullptr) {
          execv(exe_path, argv);
        }
      }
    }
  }

  g_autoptr(MyApplication) app = my_application_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
}
