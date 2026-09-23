"""
Applet: Ticker
Summary: Compact stock ticker
Description: Shows a ticker symbol, the current value of an upcoming vesting
             tranche, its date, and the percent change against the tranche's
             original value - handy for tracking a position's gain/loss.
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
DEFAULT_START_VALUE = "100"
DEFAULT_SHARES = "100"
DEFAULT_GRANT_DATE = "2024-01-01T00:00:00Z"

VEST_INTERVAL_MONTHS = 6
VEST_COUNT = 8  # every 6 months over 4 years

def with_commas(digits):
    """Insert thousands-separator commas into a digit string."""
    groups = []
    remaining = digits
    for _ in range(len(digits)):
        if len(remaining) <= 3:
            groups.append(remaining)
            break
        groups.append(remaining[-3:])
        remaining = remaining[:-3]
    return ",".join(groups[::-1])

def format_num(n):
    """Format a float with one decimal place and thousands commas
    (no %.1f in Starlark)."""
    sign = "-" if n < 0 else ""
    a = -n if n < 0 else n
    tenths = int(a * 10 + 0.5)
    return "%s%s.%d" % (sign, with_commas(str(tenths // 10)), tenths % 10)

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

def is_leap(year):
    return (year % 4 == 0 and year % 100 != 0) or (year % 400 == 0)

def days_in_month(year, month):
    if month == 2:
        return 29 if is_leap(year) else 28
    if month in (4, 6, 9, 11):
        return 30
    return 31

def add_months(t, months):
    """Add a whole number of months to a time.Time, clamping the day so it
    never overflows into a later month (e.g. Jan 31 + 1mo -> Feb 28/29)."""
    total_month = t.month - 1 + months
    year = t.year + total_month // 12
    month = total_month % 12 + 1
    day = min(t.day, days_in_month(year, month))
    return time.time(
        year = year,
        month = month,
        day = day,
        hour = t.hour,
        minute = t.minute,
        second = t.second,
    )

def vesting_schedule(grant_date_str):
    """Return the list of vesting dates (time.Time) for the grant."""
    grant_date = time.parse_time(grant_date_str, format = "2006-01-02T15:04:05Z07:00")
    return [add_months(grant_date, VEST_INTERVAL_MONTHS * n) for n in range(1, VEST_COUNT + 1)]

def next_vesting_date(schedule):
    """First vesting date still in the future; falls back to the last one."""
    now = time.now()
    for d in schedule:
        if d > now:
            return d
    return schedule[-1]

def main(config):
    symbol = config.str("symbol", DEFAULT_SYMBOL).upper()
    start_value = safe_float(config.str("start_value", DEFAULT_START_VALUE), 100.0)
    total_shares = safe_float(config.str("total_shares", DEFAULT_SHARES), 100.0)
    grant_date_str = config.str("grant_date", DEFAULT_GRANT_DATE)

    schedule = vesting_schedule(grant_date_str)
    next_date = next_vesting_date(schedule)

    tranche_shares = total_shares / VEST_COUNT
    tranche_original_value = start_value / VEST_COUNT

    resp = http.get(
        QUOTE_URL % symbol,
        headers = {"User-Agent": "Mozilla/5.0 (compatible; Tronbyt/1.0)"},
        ttl_seconds = TTL_SECONDS,
    )
    if resp.status_code != 200:
        return render_ticker(symbol, None, None, next_date)

    body = resp.json()
    result = body.get("chart", {}).get("result")
    if not result:
        return render_ticker(symbol, None, None, next_date)

    meta = result[0].get("meta", {})
    price = meta.get("regularMarketPrice")
    if price == None:
        return render_ticker(symbol, None, None, next_date)

    tranche_value = price * tranche_shares
    pct = (tranche_value - tranche_original_value) / tranche_original_value * 100 if tranche_original_value != 0 else 0.0

    return render_ticker(symbol, tranche_value, pct, next_date)

def render_ticker(symbol, tranche_value, pct, next_date):
    display_symbol = symbol[:5]
    value_text = format_num(tranche_value) if tranche_value != None else "--.-"
    date_text = next_date.format("1/2") if next_date != None else "--/--"

    pct_color = GREY
    pct_text = "--.-%"
    if pct != None:
        pct_color = GREEN if pct >= 0 else RED
        pct_text = format_pct(pct)

    ticker = render.Box(
        child = render.Padding(
            pad = (2, 1, 2, 1),
            child = render.Column(
                expanded = True,
                main_align = "center",
                cross_align = "center",
                children = [
                    render.Text(content = display_symbol, font = "tom-thumb", color = GOLD),
                    render.Text(content = value_text, font = "6x13", color = WHITE),
                    render.Row(
                        expanded = True,
                        main_align = "space_between",
                        cross_align = "center",
                        children = [
                            render.Text(content = pct_text, font = "tom-thumb", color = pct_color),
                            render.Text(content = date_text, font = "tom-thumb", color = GREY),
                        ],
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
            schema.DateTime(
                id = "grant_date",
                name = "Grant Date",
                desc = "The date the grant was issued. Vests every 6 months for 4 years (8 tranches).",
                icon = "calendar",
            ),
            schema.Text(
                id = "start_value",
                name = "Starting Value",
                desc = "Total dollar value of the entire grant on the grant date.",
                icon = "dollarSign",
                default = DEFAULT_START_VALUE,
            ),
            schema.Text(
                id = "total_shares",
                name = "Total Shares",
                desc = "Total number of shares across the entire grant.",
                icon = "hashtag",
                default = DEFAULT_SHARES,
            ),
        ],
    )
