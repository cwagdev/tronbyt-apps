"""
Applet: Ticker
Summary: Compact stock ticker
Description: Shows a ticker symbol, its current price, and percent change
             against a reference value you configure - handy for tracking
             a position's gain/loss against its original cost basis.
Author: cwagner
"""

load("render.star", "render")
load("http.star", "http")
load("time.star", "time")
load("schema.star", "schema")

# Yahoo Finance's chart endpoint - no API key required.
QUOTE_URL = "https://query1.finance.yahoo.com/v8/finance/chart/%s?interval=1d&range=1d"

# Quotes move constantly but there's no need to refetch more than every few
# minutes, and it keeps us polite to the upstream API.
TTL_SECONDS = 300

WHITE = "#ffffff"
GREY = "#888888"
GOLD = "#f5c542"
GREEN = "#00ff00"
RED = "#ff0000"

DEFAULT_SYMBOL = "AAPL"
DEFAULT_REF_VALUE = "1000"
DEFAULT_QUANTITY = "1"
DEFAULT_DATE = "2026-12-31T00:00:00Z"

def format_num(n):
    """Format a float with one decimal place (no %.1f in Starlark)."""
    sign = "-" if n < 0 else ""
    a = -n if n < 0 else n
    tenths = int(a * 10 + 0.5)
    return "%s%d.%d" % (sign, tenths // 10, tenths % 10)

def format_pct(pct):
    """Format a percentage change compactly, e.g. '+53.8%' or '-7.0%'."""
    sign = "+" if pct >= 0 else "-"
    a = pct if pct >= 0 else -pct
    if a >= 100:
        return "%s%d%%" % (sign, int(a + 0.5))
    tenths = int(a * 10 + 0.5)
    return "%s%d.%d%%" % (sign, tenths // 10, tenths % 10)

def safe_float(s, fallback):
    v = float(s) if s != None and s != "" else fallback
    return v if v != None else fallback

def days_until(date_str):
    """Days remaining until date_str (RFC3339), or None if unparseable."""
    target = time.parse_time(date_str, format = "2006-01-02T15:04:05Z07:00")
    now = time.now()
    delta = target - now
    days = int(delta.hours / 24)
    return days

def main(config):
    symbol = config.str("symbol", DEFAULT_SYMBOL).upper()
    ref_value = safe_float(config.str("ref_value", DEFAULT_REF_VALUE), 1000.0)
    quantity = safe_float(config.str("quantity", DEFAULT_QUANTITY), 1.0)
    target_date = config.str("target_date", DEFAULT_DATE)

    resp = http.get(
        QUOTE_URL % symbol,
        headers = {"User-Agent": "Mozilla/5.0 (compatible; Tronbyt/1.0)"},
        ttl_seconds = TTL_SECONDS,
    )
    if resp.status_code != 200:
        return render_ticker(symbol, None, None, None)

    body = resp.json()
    result = body.get("chart", {}).get("result")
    if not result:
        return render_ticker(symbol, None, None, None)

    meta = result[0].get("meta", {})
    price = meta.get("regularMarketPrice")
    if price == None:
        return render_ticker(symbol, None, None, None)

    current_value = price * quantity
    pct = (current_value - ref_value) / ref_value * 100 if ref_value != 0 else 0.0

    days_left = None
    if target_date:
        days_left = days_until(target_date)

    return render_ticker(symbol, price, pct, days_left)

def render_ticker(symbol, price, pct, days_left):
    display_symbol = symbol[:5]
    price_text = format_num(price) if price != None else "--.-"
    pct_color = GREY
    pct_text = "--.-%"
    if pct != None:
        pct_color = GREEN if pct >= 0 else RED
        pct_text = format_pct(pct)

    bottom_row_children = [render.Text(content = pct_text, font = "tom-thumb", color = pct_color)]
    if days_left != None and days_left >= 0:
        bottom_row_children.append(render.Text(content = str(days_left), font = "tom-thumb", color = GREY))

    ticker = render.Box(
        child = render.Padding(
            pad = (2, 1, 2, 1),
            child = render.Column(
                expanded = True,
                main_align = "center",
                cross_align = "center",
                children = [
                    render.Text(content = display_symbol, font = "tom-thumb", color = GOLD),
                    render.Text(content = price_text, font = "6x13", color = WHITE),
                    render.Row(
                        expanded = True,
                        main_align = "space_between",
                        cross_align = "center",
                        children = bottom_row_children,
                    ),
                ],
            ),
        ),
    )

    return render.Root(child = ticker)

def get_schema():
    return schema.Schema(
        version = "1",
        fields = [
            schema.Text(
                id = "symbol",
                name = "Stock Symbol",
                desc = "Ticker symbol to track (e.g. AAPL).",
                icon = "chartLine",
                default = DEFAULT_SYMBOL,
            ),
            schema.Text(
                id = "ref_value",
                name = "Grant Value",
                desc = "Original dollar value of the grant, used to compute gain/loss.",
                icon = "dollarSign",
                default = DEFAULT_REF_VALUE,
            ),
            schema.Text(
                id = "quantity",
                name = "Vesting Quantity",
                desc = "Number of shares vesting on the next vesting date.",
                icon = "hashtag",
                default = DEFAULT_QUANTITY,
            ),
            schema.DateTime(
                id = "target_date",
                name = "Next Vesting Date",
                desc = "The date of the next vesting event.",
                icon = "calendar",
            ),
        ],
    )
