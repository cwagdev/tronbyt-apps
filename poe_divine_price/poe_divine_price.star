"""
Applet: PoE2 Divine Price
Summary: Divine Orb price in Exalted Orbs
Description: Displays the current Path of Exile 2 trade price of a Divine Orb,
             denominated in Exalted Orbs, using market data from poe2scout.com.
Author: cwagner
"""

load("encoding/base64.star", "base64")
load("render.star", "render")
load("http.star", "http")

# poe2scout.com public API: returns all PoE2 leagues, each with a DivinePrice
# field expressed in the league's base currency (Exalted Orbs).
LEAGUES_URL = "https://poe2scout.com/api/poe2/Leagues"

# Currency-category listing for a league. Each row carries daily PriceLogs -
# the same series the poe2scout.com table charts (and from which its % change
# is computed). %s is the URL-encoded league name.
CURRENCY_URL = "https://poe2scout.com/api/poe2/Leagues/%s/Currencies/ByCategory?Category=currency&PerPage=250"

# Refresh at most every 15 minutes. The market moves slowly and we want to be
# polite to the upstream API.
TTL_SECONDS = 900

GOLD = "#d7af00"
WHITE = "#ffffff"
GREY = "#9a9a9a"
GREEN = "#00ff00"
RED = "#ff0000"

# Muted fill tones drawn beneath the bright trend line for added color.
GREEN_FILL = "#005f00"
RED_FILL = "#870000"

# Divine Orb icon (18x18), pre-rendered from the poecdn art for the pixel display.
DIVINE_ICON = "iVBORw0KGgoAAAANSUhEUgAAABIAAAASCAYAAABWzo5XAAAEOElEQVR4nGWUbUxbZRTH//f2trct3AtdS1u6McgodGUdOpjodC90yhYNJlUT0S1p9mFRPyzxJWbxy5zRTLMvajJdNEY020zAJaMWs2w4RtlQQLAZMF4EoRuFzuEqfeXe297ea263Gabn23lynl/+/3PO8wD/iUOHoHrwpJY+cOBDw79ZbS0NgARArK56IPF4PJTP5xOrq42GXXWPbZdIXbPLtWUbx8UYMSMMs3rjZ28cPdpbWVmpm52dzQLIAZAfAN2H7KitaNrkqjnJMEX2khIzytZZkeGTSKU5JJMZ1NU9dGTPi68ce8RmKxiKRLh7IIlYDXl7n6eR0lFd5Xa7evZmJFdkWIPiQoq4MXeT+DvN5WgtoyqvsBNP1Dtf3fnsvm9tNpsmchcmUYrf530+qbD5UInWRH6hUafUgkovpjIctWUtA5PZiqadTgwNT1HzizHp9q2ELIrmz+V0eoYoKBjweBxqn+/3DHnKc4r0AtK2Rx8+IvBqR+XaQrGyVEMlElnM/LEAVS6BVEaGnKORFfVkncskiwJHfXmytUWxNTdHa5QWkV6fF7Isk1KWczU2VEllZfXEV61nYS+3glYX41LgN3xzuhNdgQCq7AYgHYck87JaoykxGAz6cDicd0W+73YTICCTdDKxt3E3GQpHsXXzVtTbDTCyHHY9vhnO6nVYYynFd+0d+KS1DTPTQWJjdZV+OZPRMgyjrAtJwu3G6VMgHOurcPbHQSm0mMFh7wsQ4kmQuSysxTRqKsww6YBndrSgxLKB8F/sRf8vPaxJp1PH5ueVgRHk0tIS4fUSUo2zvn164TbZsvcpXLgaRGqlGBeujGP3/g/w0Qk/+oI3MDjejY/feRdlZU74z7dbTYxJm7g7foJsaGgQAdDf9/kvZjPRrksDfapP2zqkycVFPLenHmWlDAAeGzaY8eSOjQiO9MrbXXY0N7knpkJTaZZllS2X87IAqG2waSKIqANtV09AiO2/dv2KZK+kyfOBPjzduAVFDIPewTEYaIt8J2OQg9f7vf7uQKCoqEiIx+PJPA2A6HA7JMDBzccWWne91Cy9fvg93Inx4HkBY5Pz6PxpEMPB8RxbqANdwF72dwd+NWqNmng8rjwVSQEpIff09Ai1lpjG+9rLA/3nOjqgo8k7y4WirpABl6NwaykGmSAxEQoRXZd/6NTr9QKv4jMA8iDqPkhJYLEIjuJi4sylc8e4eKJprcXKjEyLufDitIpLxUWr2UyFItGxnoGBXq1WS/E8n1LcrFaUh42OjmZXVlZUJ78+Mz4SmnwznYgSmypcKhNLyyzLUn8tC7GfRyaOAkiqeJ4HIOQFAPJqUB4WDocFi8Wifev48TZOyB4sNZluRZeT0s0/k9eGxucOLtyOjiqX00D6vq3//Uf3QoGrjEZjQTQaVQqdANYDmFGU3KtJAFBevdKjvKJ/AHRa1jjPBTF+AAAAAElFTkSuQmCC"

# Exalted Orb icon (11x11), used as the price unit marker.
EXALT_ICON = "iVBORw0KGgoAAAANSUhEUgAAAAsAAAALCAYAAACprHcmAAAB60lEQVR4nE2QP2gTYRyGf99337W5SJqmjaSNhEaERotmSVoQ0UFKEBfp5KINOjjoQXVQ10IRHPRQi0NxKdFNECl0E4lGKilJY2mMJGebvzWtSfOnvSaXS777pKWDz/DyDg/v8AIAAGMMhUIh/qAXVz8+WgvOS0+np4bhCFEUOfgPdBAfZkU/YypjnQ32Vrpfn5u5vXD96iX7kYNRIBDAPp+Pj35bvJNPJ6QOpXh8zKnncgWSy5WBGI7FNCTcMNjU34eLjGVeQL029Vya1dPpPG6obfC6h9mY9zSNxWSCu4T1ha8rF5HH4+m/d3P8F8doXyy6jPp6BKwSI1RKNXj55BYsR2V9O5PqFPZa19Cc9Ph8MLj0xT1yis/Ka1DbbYJcbMLgcRNYengYGjCzcnmnZe0V7uI25S447RYuEs/SQtsG6xUM+w0VrEYEO9WmjhhiFrNZWYqrcSw+fPUus5HJ60qRS/6MU2jVgPAcqJQwoZsAx3djTdWzu5XNBkagbJ0YcszrxgHFSHTOxEPnjF1g7nMudNLpwKW/1fCnH5UHEbn0B3tHR7uevVmcsTrOTpr7B+sq6SV72IZAJ6mqQvyv33+fXE0kUgDQPrzO5QJDMgn0ysTEZROn+be2qyvhcOSzpmmbZgBaB9gHgNY/K1Xd9cEDY/oAAAAASUVORK5CYII="

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

def format_price(price):
    """Format the Exalted price with one decimal place.

    Starlark's % operator does not support precision (e.g. %.1f), so we round
    to the nearest tenth with integer math and assemble the string by hand.
    """
    tenths = int(price * 10 + 0.5)
    return "%d.%d" % (tenths // 10, tenths % 10)

def format_pct(pct):
    """Format a percentage change compactly, e.g. '+53.8%' or '-7.0%'."""
    sign = "+" if pct >= 0 else "-"
    a = pct if pct >= 0 else -pct

    # Drop the decimal once we hit triple digits to keep the label narrow.
    if a >= 100:
        return "%s%d%%" % (sign, int(a + 0.5))
    tenths = int(a * 10 + 0.5)
    return "%s%d.%d%%" % (sign, tenths // 10, tenths % 10)

def fetch_price_logs(league_name):
    """Return the Divine Orb daily price series (oldest-first) for the league.

    Uses the same ByCategory listing the poe2scout.com table is built from, so
    our sparkline and % change match the website.
    """
    url = CURRENCY_URL % league_name.replace(" ", "%20")
    resp = http.get(url, ttl_seconds = TTL_SECONDS)
    if resp.status_code != 200:
        return []

    for item in resp.json().get("Items", []):
        if item.get("ApiId") == "divine":
            logs = item.get("PriceLogs", [])

            # PriceLogs arrive newest-first; reverse so the sparkline reads left
            # (old) to right (now). Keep only entries with a usable price.
            return [l["Price"] for l in reversed(logs) if l.get("Price") != None]

    return []

# Sparkline geometry and draw-in animation tuning.
PLOT_WIDTH = 38
PLOT_HEIGHT = 13

# Animation timing. Pixlet/Tidbyt always encodes an infinitely-looping image,
# so there is no true "play once". Instead we hold the finished line long enough
# to fill the device's display slot (max_duration, 15s by default): the line
# draws in once (~1s) and then sits static for the rest of the slot, so within a
# single on-screen appearance it never visibly re-draws. show_full_animation on
# the Root makes the device play the whole sequence before rotating apps.
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

def main():
    resp = http.get(LEAGUES_URL, ttl_seconds = TTL_SECONDS)
    if resp.status_code != 200:
        return render_error("HTTP %d" % resp.status_code)

    leagues = resp.json()
    league = pick_league(leagues)
    if league == None:
        return render_error("No data")

    price_text = format_price(league["DivinePrice"])

    prices = fetch_price_logs(league["Value"])
    plot, trend_color = build_trend(prices)

    # Top row: Divine icon, current price in gold, Exalted Orb unit marker.
    header = render.Row(
        expanded = True,
        main_align = "center",
        cross_align = "center",
        children = [
            render.Image(src = base64.decode(DIVINE_ICON), width = 18, height = 18),
            render.Box(width = 3, height = 1),
            render.Text(content = price_text, font = "6x13", color = GOLD),
            render.Box(width = 2, height = 1),
            render.Image(src = base64.decode(EXALT_ICON), width = 9, height = 9),
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
                    render.Text(content = "Divine", font = "tom-thumb", color = GOLD),
                    render.Text(content = msg, font = "tom-thumb", color = WHITE),
                ],
            ),
        ),
    )
