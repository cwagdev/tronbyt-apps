"""
Applet: PoE2 Price Check
Summary: Path of Exile 2 currency price, in any currency
Description: Displays the current Path of Exile 2 trade price of a chosen currency
             item, denominated in another chosen currency item, with a trend
             sparkline. Both items are configurable from the Currency category.
             Market data from poe2scout.com.
Author: cwagner
"""

load("http.star", "http")
load("render.star", "render")
load("schema.star", "schema")

# poe2scout.com public API: returns all PoE2 leagues. We use it only to pick the
# current league (its name feeds the currency listing below).
LEAGUES_URL = "https://poe2scout.com/api/poe2/Leagues"

# Currency-category listing for a league. Each row carries the item's IconUrl,
# its CurrentPrice, and daily PriceLogs - all denominated in the league's base
# currency (Exalted Orbs). %s is the URL-encoded league name.
CURRENCY_URL = "https://poe2scout.com/api/poe2/Leagues/%s/Currencies/ByCategory?Category=currency&PerPage=250"

# Refresh at most every 15 minutes. The market moves slowly and we want to be
# polite to the upstream API.
TTL_SECONDS = 900

# Icons rarely change; cache them for a day.
ICON_TTL_SECONDS = 86400

GOLD = "#d7af00"
WHITE = "#ffffff"
GREEN = "#00ff00"
RED = "#ff0000"

# Muted fill tones drawn beneath the bright trend line for added color.
GREEN_FILL = "#005f00"
RED_FILL = "#870000"

DEFAULT_ITEM = "divine"
DEFAULT_COST = "exalted"

# Currency-category items, value (ApiId) + display name. Drives the two configuration dropdowns.
# Live prices and icons are still fetched at render time; this list only needs
# the stable id/name.
CURRENCY_OPTIONS = [
    ("scrap", "Armourer's Scrap"),
    ("etcher", "Arcanist's Etcher"),
    ("artificers", "Artificer's Orb"),
    ("artificers-shard", "Artificer's Shard"),
    ("whetstone", "Blacksmith's Whetstone"),
    ("chance-shard", "Chance Shard"),
    ("chaos", "Chaos Orb"),
    ("cryptic-key", "Cryptic Key"),
    ("divine", "Divine Orb"),
    ("exalted", "Exalted Orb"),
    ("fracturing-orb", "Fracturing Orb"),
    ("gcp", "Gemcutter's Prism"),
    ("bauble", "Glassblower's Bauble"),
    ("greater-chaos-orb", "Greater Chaos Orb"),
    ("greater-exalted-orb", "Greater Exalted Orb"),
    ("greater-jewellers-orb", "Greater Jeweller's Orb"),
    ("greater-orb-of-augmentation", "Greater Orb of Augmentation"),
    ("greater-orb-of-transmutation", "Greater Orb of Transmutation"),
    ("greater-regal-orb", "Greater Regal Orb"),
    ("hinekoras-lock", "Hinekora's Lock"),
    ("lesser-jewellers-orb", "Lesser Jeweller's Orb"),
    ("mirror", "Mirror of Kalandra"),
    ("aug", "Orb of Augmentation"),
    ("alch", "Orb of Alchemy"),
    ("annul", "Orb of Annulment"),
    ("chance", "Orb of Chance"),
    ("transmute", "Orb of Transmutation"),
    ("perfect-chaos-orb", "Perfect Chaos Orb"),
    ("perfect-exalted-orb", "Perfect Exalted Orb"),
    ("perfect-jewellers-orb", "Perfect Jeweller's Orb"),
    ("perfect-orb-of-augmentation", "Perfect Orb of Augmentation"),
    ("perfect-orb-of-transmutation", "Perfect Orb of Transmutation"),
    ("perfect-regal-orb", "Perfect Regal Orb"),
    ("regal", "Regal Orb"),
    ("regal-shard", "Regal Shard"),
    ("wisdom", "Scroll of Wisdom"),
    ("transmutation-shard", "Transmutation Shard"),
    ("vaal", "Vaal Orb"),
]

def pick_league(leagues):
    """Return the current softcore league, falling back sensibly."""

    # Prefer the live (IsCurrent) softcore league - its Value does not start
    # with the "HC" hardcore prefix.
    for league in leagues:
        if league.get("IsCurrent") and not league.get("Value", "").startswith("HC"):
            return league

    # Fall back to any current league, then to the first league returned.
    for league in leagues:
        if league.get("IsCurrent"):
            return league
    return leagues[0] if len(leagues) > 0 else None

def one_dec(x):
    """One decimal place. Starlark's % has no precision specifier (no %.1f)."""
    tenths = int(x * 10 + 0.5)
    return "%d.%d" % (tenths // 10, tenths % 10)

def two_dec(x):
    hundredths = int(x * 100 + 0.5)
    return "%d.%02d" % (hundredths // 100, hundredths % 100)

def three_dec(x):
    thou = int(x * 1000 + 0.5)
    return "%d.%03d" % (thou // 1000, thou % 1000)

def format_value(v):
    """Format a price ratio compactly, adapting to its magnitude.

    Ratios span a huge range (a Mirror is ~360k Exalted; a Divine is a tiny
    fraction of a Mirror), so pick a representation that stays ~6 chars wide.
    """
    if v >= 1000000:
        return one_dec(v / 1000000.0) + "M"
    elif v >= 10000:
        return "%dk" % int(v / 1000.0 + 0.5)
    elif v >= 1000:
        return one_dec(v / 1000.0) + "k"
    elif v >= 100:
        return "%d" % int(v + 0.5)
    elif v >= 1:
        return one_dec(v)
    elif v >= 0.1:
        return two_dec(v)
    elif v >= 0.001:
        return three_dec(v)
    elif v > 0:
        return "<.001"
    return "0"

def format_pct(pct):
    """Format a percentage change compactly, e.g. '+53.8%' or '-7.0%'."""
    sign = "+" if pct >= 0 else "-"
    a = pct if pct >= 0 else -pct

    # Drop the decimal once we hit triple digits to keep the label narrow.
    if a >= 100:
        return "%s%d%%" % (sign, int(a + 0.5))
    return "%s%s%%" % (sign, one_dec(a))

def fetch_currencies(league_name):
    """Return a dict of ApiId -> item row for the league's currency category."""
    url = CURRENCY_URL % league_name.replace(" ", "%20")
    resp = http.get(url, ttl_seconds = TTL_SECONDS)
    if resp.status_code != 200:
        return {}

    by_id = {}
    for item in resp.json().get("Items", []):
        by_id[item.get("ApiId")] = item
    return by_id

def current_price(item):
    """Item price in Exalted Orbs (its CurrentPrice, else newest price log)."""
    if item.get("CurrentPrice") != None:
        return item["CurrentPrice"]
    logs = item.get("PriceLogs", [])
    return logs[0]["Price"] if len(logs) > 0 else None

def ratio_series(item, cost):
    """Daily series of item-price / cost-price, aligned by date, oldest-first.

    Both items' PriceLogs are denominated in Exalted Orbs, so dividing them at
    each shared timestamp yields the item's price expressed in the cost item.
    """
    cost_by_time = {}
    for log in cost.get("PriceLogs", []):
        if log.get("Price"):
            cost_by_time[log.get("Time")] = log["Price"]

    series = []
    for log in item.get("PriceLogs", []):
        cprice = cost_by_time.get(log.get("Time"))
        if log.get("Price") and cprice:
            series.append(log["Price"] / cprice)

    # PriceLogs arrive newest-first; reverse so the sparkline reads left (old)
    # to right (now).
    return [v for v in reversed(series)]

def fetch_icon(item):
    """Return raw icon image bytes for an item, or None on failure."""
    url = item.get("IconUrl")
    if not url:
        return None
    resp = http.get(url, ttl_seconds = ICON_TTL_SECONDS)
    if resp.status_code != 200:
        return None
    return resp.body()

# Sparkline geometry and draw-in animation tuning.
PLOT_WIDTH = 38
PLOT_HEIGHT = 13

# Animation timing. Pixlet/Tidbyt always encodes an infinitely-looping image,
# so there is no true "play once". Instead we hold the finished line long enough
# to fill the device's display slot (max_duration, 15s by default): the line
# draws in once (~1s) and then sits static for the rest of the slot, so within a
# single on-screen appearance it never visibly re-draws.
DELAY_MS = 45  # per-frame delay; also set on render.Root
SLOT_MS = 15000  # Tidbyt default app display slot / max_duration
DRAW_FRAMES = 22  # frames spent revealing the line left -> right
HOLD_FRAMES = SLOT_MS // DELAY_MS - DRAW_FRAMES  # pad the finished line to fill the slot

def partial_series(prices, frac):
    """Return the series revealed up to `frac` (0..1) of the x-range.

    The leading edge is linearly interpolated so the line grows smoothly rather
    than jumping point to point.
    """
    max_x = len(prices) - 1
    tx = frac * max_x
    last = int(tx)

    pts = [(float(i), prices[i]) for i in range(last + 1)]
    if tx > last and last < max_x:
        y = prices[last] + (prices[last + 1] - prices[last]) * (tx - last)
        pts.append((tx, y))
    return pts

def make_plot(data, color, fill_color, x_lim, y_lim):
    """A single sparkline frame. fill_color sets the surface tone explicitly;
    without it Plot derives a (buggy) dampened fill from the line color."""
    return render.Plot(
        data = data,
        width = PLOT_WIDTH,
        height = PLOT_HEIGHT,
        color = color,
        fill = True,
        fill_color = fill_color,
        x_lim = x_lim,
        y_lim = y_lim,
    )

def build_trend(prices):
    """Build the animated sparkline plus its trend color from a price series."""
    if len(prices) < 2:
        return None, GOLD

    # Color the line by the net move over the window, with a matching soft fill.
    net = prices[-1] - prices[0]
    if net > 0:
        color, fill_color = GREEN, GREEN_FILL
    elif net < 0:
        color, fill_color = RED, RED_FILL
    else:
        color, fill_color = GOLD, GOLD

    lo = prices[0]
    hi = prices[0]
    for p in prices:
        lo = min(lo, p)
        hi = max(hi, p)

    # Pad the y-range so the peaks and troughs aren't clipped at the edges.
    pad = (hi - lo) * 0.15
    if pad == 0:
        pad = hi * 0.05 + 1

    # Keep the axes fixed across frames so the line grows in place (left to
    # right) instead of rescaling as points are added.
    x_lim = (0, len(prices) - 1)
    y_lim = (lo - pad, hi + pad)

    frames = []
    for step in range(1, DRAW_FRAMES + 1):
        data = partial_series(prices, float(step) / DRAW_FRAMES)
        frames.append(make_plot(data, color, fill_color, x_lim, y_lim))

    # Hold the completed line for a beat before the animation loops.
    full = frames[-1]
    for _ in range(HOLD_FRAMES):
        frames.append(full)

    return render.Animation(children = frames), color

def icon_widget(icon_bytes, size):
    """An icon image if we have bytes, else a same-size empty spacer."""
    if icon_bytes == None:
        return render.Box(width = size, height = size)
    return render.Image(src = icon_bytes, width = size, height = size)

def main(config):
    item_id = config.get("item", DEFAULT_ITEM)
    cost_id = config.get("cost", DEFAULT_COST)

    resp = http.get(LEAGUES_URL, ttl_seconds = TTL_SECONDS)
    if resp.status_code != 200:
        return render_error("HTTP %d" % resp.status_code)

    league = pick_league(resp.json())
    if league == None:
        return render_error("No league")

    currencies = fetch_currencies(league["Value"])
    item = currencies.get(item_id)
    cost = currencies.get(cost_id)
    if item == None or cost == None:
        return render_error("No data")

    item_price = current_price(item)
    cost_price = current_price(cost)
    if not item_price or not cost_price:
        return render_error("No price")

    value_text = format_value(item_price / cost_price)

    item_icon = fetch_icon(item)
    cost_icon = fetch_icon(cost)

    prices = ratio_series(item, cost)
    plot, trend_color = build_trend(prices)

    # Top row: item icon, current price, cost-item icon as the unit marker.
    header = render.Row(
        expanded = True,
        main_align = "center",
        cross_align = "center",
        children = [
            icon_widget(item_icon, 18),
            render.Box(width = 3, height = 1),
            render.Text(content = value_text, font = "6x13", color = GOLD),
            render.Box(width = 2, height = 1),
            icon_widget(cost_icon, 11),
        ],
    )

    children = [header]
    if plot != None:
        # Bottom row: the trend sparkline plus its % change over the window,
        # colored to match the trend (green up / red down).
        pct = (prices[-1] - prices[0]) / prices[0] * 100
        children.append(
            render.Row(
                expanded = True,
                main_align = "center",
                cross_align = "center",
                children = [
                    plot,
                    render.Box(width = 2, height = 1),
                    render.Text(
                        content = format_pct(pct),
                        font = "tom-thumb",
                        color = trend_color,
                    ),
                ],
            ),
        )

    return render.Root(
        delay = DELAY_MS,
        show_full_animation = True,
        child = render.Column(
            expanded = True,
            main_align = "space_between" if plot != None else "center",
            cross_align = "center",
            children = children,
        ),
    )

def render_error(msg):
    return render.Root(
        child = render.Box(
            child = render.Column(
                expanded = True,
                main_align = "center",
                cross_align = "center",
                children = [
                    render.Text(content = "PoE2", font = "tom-thumb", color = GOLD),
                    render.Text(content = msg, font = "tom-thumb", color = WHITE),
                ],
            ),
        ),
    )

def _currency_options():
    return [schema.Option(display = name, value = api_id) for (api_id, name) in CURRENCY_OPTIONS]

def get_schema():
    options = _currency_options()
    return schema.Schema(
        version = "1",
        fields = [
            schema.Dropdown(
                id = "item",
                name = "Item",
                desc = "The currency item to price.",
                icon = "coins",
                default = DEFAULT_ITEM,
                options = options,
            ),
            schema.Dropdown(
                id = "cost",
                name = "Priced in",
                desc = "The currency item to express the price in.",
                icon = "scaleBalanced",
                default = DEFAULT_COST,
                options = options,
            ),
        ],
    )
