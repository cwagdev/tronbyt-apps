"""
Applet: Pool Temp
Summary: Pool temperature now, with 24h high/low
Description: Shows the current pool temperature plus the 24-hour high and low,
with a sparkline of the recent history. Data from a local CSV API.
Author: cwagner118
"""

load("render.star", "render")
load("http.star", "http")
load("time.star", "time")

DATA_URL = "http://192.168.1.2:1880/poolTempHistory"
TTL_SECONDS = 300  # refresh ~5 min
WINDOW = 24 * 60 * 60  # 24 hours in seconds

def c_to_f(c):
    return c * 9.0 / 5.0 + 32.0

def round_int(x):
    # Starlark has no %.1f / round(); nudge and truncate
    return int(x + 0.5)

def parse_csv(body):
    rows = []
    lines = body.split("\n")
    for line in lines[1:]:  # skip header
        line = line.strip()
        if not line:
            continue
        parts = line.split(",")
        if len(parts) < 2:
            continue
        ts = parts[0]
        pool = parts[1]
        if pool == "":
            continue
        rows.append((ts, float(pool)))
    return rows

def main(config):
    resp = http.get(DATA_URL, ttl_seconds = TTL_SECONDS)
    if resp.status_code != 200:
        return render_error("HTTP %d" % resp.status_code)

    rows = parse_csv(resp.body())
    if len(rows) == 0:
        return render_error("no data")

    # Current = most recent row
    current_f = c_to_f(rows[-1][1])

    # Latest timestamp -> 24h window
    latest = time.parse_time(rows[-1][0])
    cutoff = latest - time.parse_duration("%ds" % WINDOW)

    hi = None
    lo = None
    spark = []
    for ts, pool_c in rows:
        t = time.parse_time(ts)
        if t < cutoff:
            continue
        f = c_to_f(pool_c)
        if hi == None or f > hi:
            hi = f
        if lo == None or f < lo:
            lo = f
        spark.append(f)

    if hi == None:
        hi = current_f
        lo = current_f
        spark = [current_f]

    plot_pts = [(i, spark[i]) for i in range(len(spark))]

    return render.Root(
        child = render.Column(
            children = [
                render.Row(
                    expanded = True,
                    main_align = "space_between",
                    cross_align = "center",
                    children = [
                        render.Padding(
                            pad = (1, 0, 0, 0),
                            child = render.Column(
                                children = [
                                    render.Text("POOL \u00B0F", font = "tom-thumb", color = "#4a9cff"),
                                    render.Text(str(round_int(current_f)) + "\u00B0", font = "6x13", color = "#ffffff"),
                                ],
                            ),
                        ),
                        render.Column(
                            cross_align = "end",
                            children = [
                                render.Row(
                                    children = [
                                        render.Text("HI ", font = "tom-thumb", color = "#888888"),
                                        render.Text(str(round_int(hi)), font = "tom-thumb", color = "#ff5a5a"),
                                    ],
                                ),
                                render.Box(width = 1, height = 3),
                                render.Row(
                                    children = [
                                        render.Text("LO ", font = "tom-thumb", color = "#888888"),
                                        render.Text(str(round_int(lo)), font = "tom-thumb", color = "#4a9cff"),
                                    ],
                                ),
                            ],
                        ),
                    ],
                ),
                render.Box(
                    height = 9,
                    width = 64,
                    child = render.Plot(
                        data = plot_pts,
                        width = 64,
                        height = 9,
                        color = "#33dd66",
                        fill_color = "#13501f",
                        y_lim = (lo - 1, hi + 1),
                    ),
                ),
            ],
        ),
    )

def render_error(msg):
    return render.Root(
        child = render.Box(
            child = render.Text(content = msg, font = "tom-thumb", color = "#ffffff"),
        ),
    )
