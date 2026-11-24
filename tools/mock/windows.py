"""Makes the three tiling window patterns for the city's towers (needs numpy and ffmpeg)."""
import numpy as np, subprocess, sys, os
out = sys.argv[1]; N = 16; C = 64
for name, cols, lit, seed in (("warm", [(255, 178, 96), (255, 214, 160), (110, 190, 255)], .33, 1), ("neon", [(70, 130, 255), (225, 70, 235), (110, 170, 255)], .34, 2), ("cyan", [(60, 190, 255), (90, 235, 255), (200, 225, 255)], .42, 3)):
    g = np.random.default_rng(seed)
    a = np.zeros((N * C, N * C, 4), "u1")
    a[..., :3] = cols[0]
    rows = g.random((N, 4)).repeat(4, 1)
    on = g.random((N, N)) * .55 + rows * .45 > 1 - lit
    k = np.where(rows > .75, 1, np.where(g.random((N, N)) > .85, 2, 0))
    for y in range(N):
        for x in range(N):
            if on[y, x]:
                s = np.s_[y * C + 18 : y * C + 46, x * C + 9 : x * C + 55]
                a[s][..., :3] = cols[k[y, x]]
                a[s][..., 3] = int(255 * (.45 + .55 * g.random()))
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgba", "-s", f"{N*C}x{N*C}", "-i", "-", os.path.join(out, f"SBPP_windows_{name}.png")], input=a.tobytes(), check=True)
