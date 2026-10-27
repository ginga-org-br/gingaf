import os
import sys
import shutil
import subprocess

def build_eac_to_equirect_map(out_w=1280, out_h=640, in_w=960, in_h=852):
    import numpy as np

    ORIENT_POS_X = np.array([[0, -1, 1], [-1, 0, 1], [0, 0, 1]], dtype=np.float32)
    ORIENT_NEG_X = np.array([[-1, 0, 1], [0, -1, 1], [0, 0, 1]], dtype=np.float32)
    ORIENT_POS_Y = np.array([[0, 1, 0], [1, 0, 0], [0, 0, 1]], dtype=np.float32)
    ORIENT_NEG_Y = np.array([[0, -1, 1], [1, 0, 0], [0, 0, 1]], dtype=np.float32)
    ORIENT_POS_Z = np.array([[0, 1, 0], [-1, 0, 1], [0, 0, 1]], dtype=np.float32)
    ORIENT_NEG_Z = np.array([[0, -1, 1], [-1, 0, 1], [0, 0, 1]], dtype=np.float32)

    OFFSET_POS_X = np.array([0.0, 1.0 / 3.0], dtype=np.float32)
    OFFSET_NEG_X = np.array([0.25, 1.0 / 3.0], dtype=np.float32)
    OFFSET_POS_Y = np.array([0.25, 2.0 / 3.0], dtype=np.float32)
    OFFSET_NEG_Y = np.array([0.25, 0.0], dtype=np.float32)
    OFFSET_POS_Z = np.array([0.0, 0.0], dtype=np.float32)
    OFFSET_NEG_Z = np.array([0.0, 2.0 / 3.0], dtype=np.float32)

    u = (np.arange(out_w, dtype=np.float32) + 0.5) / out_w
    v = (np.arange(out_h, dtype=np.float32) + 0.5) / out_h
    U, V = np.meshgrid(u, v)

    lat = (0.5 - V) * np.pi
    phi = (U - 0.5) * 2.0 * np.pi

    cos_lat = np.cos(lat)
    coords_x = cos_lat * np.cos(phi)
    coords_z = cos_lat * np.sin(phi)
    coords_y = np.sin(lat)

    abs_x = np.abs(coords_x)
    abs_y = np.abs(coords_y)
    abs_z = np.abs(coords_z)

    is_x = (abs_x >= abs_y) & (abs_x >= abs_z)
    is_y = (~is_x) & (abs_y >= abs_z)
    is_z = (~is_x) & (~is_y)

    map_x = np.zeros((out_h, out_w), dtype=np.float32)
    map_y = np.zeros((out_h, out_w), dtype=np.float32)

    faces = [
        ('POS_X', is_x & (coords_x > 0), ORIENT_POS_X, OFFSET_POS_X),
        ('NEG_X', is_x & (coords_x <= 0), ORIENT_NEG_X, OFFSET_NEG_X),
        ('POS_Y', is_y & (coords_y > 0), ORIENT_POS_Y, OFFSET_POS_Y),
        ('NEG_Y', is_y & (coords_y <= 0), ORIENT_NEG_Y, OFFSET_NEG_Y),
        ('POS_Z', is_z & (coords_z > 0), ORIENT_POS_Z, OFFSET_POS_Z),
        ('NEG_Z', is_z & (coords_z <= 0), ORIENT_NEG_Z, OFFSET_NEG_Z),
    ]

    edge_x = 1.0 / in_w
    edge_y = 1.0 / in_h

    for name, mask, orient, offset in faces:
        if not np.any(mask):
            continue
        cx = coords_x[mask]
        cy = coords_y[mask]
        cz = coords_z[mask]

        if name in ('POS_X', 'NEG_X'):
            tc_x = cz
            tc_y = cy
            tc_z = cx
        elif name in ('POS_Y', 'NEG_Y'):
            tc_x = cx
            tc_y = cz
            tc_z = cy
        else:
            tc_x = -cx
            tc_y = -cy
            tc_z = cz

        tc_raw_x = tc_x / tc_z
        tc_raw_y = tc_y / tc_z

        tc_eac_x = (2.0 / np.pi) * np.arctan(tc_raw_x) + 0.5
        tc_eac_y = (2.0 / np.pi) * np.arctan(tc_raw_y) + 0.5

        tc_rot_x = orient[0, 0] * tc_eac_x + orient[0, 1] * tc_eac_y + orient[0, 2]
        tc_rot_y = orient[1, 0] * tc_eac_x + orient[1, 1] * tc_eac_y + orient[1, 2]

        tc_scale_x = tc_rot_x * 0.25
        tc_scale_y = tc_rot_y * (1.0 / 3.0)

        tc_scale_x = np.clip(tc_scale_x, edge_x, 0.25 - edge_x)
        tc_scale_y = np.clip(tc_scale_y, edge_y, (1.0 / 3.0) - edge_y)

        uv_u = tc_scale_x + offset[0]
        uv_v = tc_scale_y + offset[1]

        map_x[mask] = uv_u * in_w
        map_y[mask] = (1.0 - uv_v) * in_h

    import cv2
    return cv2.convertMaps(map_x, map_y, cv2.CV_16SC2)

def transcode_eac_to_equirect(input_path, output_path=None, out_w=1280, out_h=640):
    if not shutil.which("ffmpeg"):
        sys.exit("Error: ffmpeg is required but not found in PATH.")

    if output_path is None:
        base, ext = os.path.splitext(input_path)
        output_path = f"{base}.equirect{ext}"

    try:
        import cv2
        import numpy as np
    except ImportError:
        print("Error: opencv-python and numpy are required for EAC transcode.")
        return

    cap = cv2.VideoCapture(input_path)
    if not cap.isOpened():
        raise RuntimeError(f"Cannot open video: {input_path}")

    fps = cap.get(cv2.CAP_PROP_FPS) or 29.97
    in_w = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    in_h = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))

    print(f"Transcoding SBS EAC '{input_path}' ({in_w}x{in_h}) -> Equirectangular '{output_path}' ({out_w}x{out_h})...")
    map1, map2 = build_eac_to_equirect_map(out_w, out_h, in_w, in_h)

    temp_video = output_path + ".temp.mp4"
    ffmpeg_cmd = [
        "ffmpeg", "-y",
        "-f", "rawvideo",
        "-vcodec", "rawvideo",
        "-s", f"{out_w}x{out_h}",
        "-pix_fmt", "bgr24",
        "-r", str(fps),
        "-i", "-",
        "-c:v", "libx264",
        "-preset", "veryfast",
        "-crf", "20",
        "-pix_fmt", "yuv420p",
        temp_video
    ]
    proc = subprocess.Popen(ffmpeg_cmd, stdin=subprocess.PIPE)

    while True:
        ret, frame = cap.read()
        if not ret:
            break
        remapped = cv2.remap(frame, map1, map2, interpolation=cv2.INTER_LINEAR)
        proc.stdin.write(remapped.tobytes())

    proc.stdin.close()
    proc.wait()
    cap.release()

    mux_cmd = [
        "ffmpeg", "-y",
        "-i", temp_video,
        "-i", input_path,
        "-map", "0:v:0",
        "-map", "1:a:0?",
        "-c:v", "copy",
        "-c:a", "copy",
        output_path
    ]
    subprocess.run(mux_cmd, check=True)
    if os.path.exists(temp_video):
        os.remove(temp_video)
    print(f"Successfully converted to {output_path}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        default_file = os.path.join(
            os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
            "guarana", "media", "louvre360.mp4"
        )
        if os.path.exists(default_file):
            transcode_eac_to_equirect(default_file)
        else:
            print("Usage: python transcode_eac.py <input_eac_video> [output_equirect_video]")
            sys.exit(1)
    else:
        in_file = sys.argv[1]
        out_file = sys.argv[2] if len(sys.argv) > 2 else None
        transcode_eac_to_equirect(in_file, out_file)
