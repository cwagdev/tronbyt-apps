"""
Applet: OG Clock Remake
Summary: OG Clock Remake
Description: A remake of the original Tidbyt Clock App (Reddit initiative).
Author: bendiep

TODO:
- Get real weather data from API
- Get more weather icons
- Get timezone from location
- Add display location toggle option
- Add 24-hour clock toggle option
- Add display weather toggle option
- Add blinking separator toggle option
- Add temperature units option (Celsius/Fahrenheit)
- Add time color option
"""

load("encoding/base64.star", "base64")
load("render.star", "render")
load("time.star", "time")
load("http.star", "http")

API_URL = "http://192.168.1.2:1880/currentWeatherCondition"

ICON_CLEAR = "iVBORw0KGgoAAAANSUhEUgAAABEAAAAQCAYAAADwMZRfAAAABGdBTUEAA1teXP8meAAAAERlWElmTU0AKgAAAAgAAYdpAAQAAAABAAAAGgAAAAAAA6ABAAMAAAABAAEAAKACAAQAAAABAAAAEaADAAQAAAABAAAAEAAAAACz87qxAAABxUlEQVQ4EX1SPUgcQRT+ZvdgbxZSmKiHCGnSeVyRIhFEQdIE0ulxTdo0IYH0QvwpTJMqhDRWlimCYmORKhyHQsDKuz07EQJHCm3ica7knOd3q3vO7Q0ODPPe933vzXtvBrhnSRS+labeukeSUF4qkF/IpXb/FHgQ+H3/1shq+0kwrr/z1m8DAZ7ZhZEvNiaRrqAQtmSNF2QXycdMcizN/Jssl/pSD55Q15Zm8CrFeqeyHTnECP6hiwcw8PUK2UXukJoquvIR2/EJynpSlS7+2HEDSXpE0m9BV5l/xhbSPsWleaaeMlFmDfc1ln/tSNALG0XgrWXiEzfHZ9ykNQFlamoq/gTPm3UJE0wk4ZKZiP+Brf7HlbzL8Qm34ZlxXKmjm2BpZ0Zl5VTkuC5VE4H5wcl1cR6fDs+krmfgqz0r0jLNMqtdt4DEHJoJJ78PMatZISv+CYk/D+EEBiqRRvAS4p+pUueA/+E5+QVuzbKrKF3sIOIXQFhRxc6GKxmkrhcZeC5Rfs4pICi/8Sj5kJH+amvu2lFShDFlVYxrqYAJX3Avpb6axhnbmqf/0PntU6F9SiN8z+p2bMxl31XiYiF/CbeclAVeA3uqnEu9eP1MAAAAAElFTkSuQmCC"
ICON_FEW_CLOUDS = "iVBORw0KGgoAAAANSUhEUgAAABIAAAANCAYAAACkTj4ZAAAABGdBTUEAALGPC/xhBQAAACBjSFJNAAB6JgAAgIQAAPoAAACA6AAAdTAAAOpgAAA6mAAAF3CculE8AAAAUGVYSWZNTQAqAAAACAACARIAAwAAAAEAAQAAh2kABAAAAAEAAAAmAAAAAAADoAEAAwAAAAEAAQAAoAIABAAAAAEAAAASoAMABAAAAAEAAAANAAAAAGrEnBgAAAIwaVRYdFhNTDpjb20uYWRvYmUueG1wAAAAAAA8eDp4bXBtZXRhIHhtbG5zOng9ImFkb2JlOm5zOm1ldGEvIiB4OnhtcHRrPSJYTVAgQ29yZSA2LjAuMCI+CiAgIDxyZGY6UkRGIHhtbG5zOnJkZj0iaHR0cDovL3d3dy53My5vcmcvMTk5OS8wMi8yMi1yZGYtc3ludGF4LW5zIyI+CiAgICAgIDxyZGY6RGVzY3JpcHRpb24gcmRmOmFib3V0PSIiCiAgICAgICAgICAgIHhtbG5zOmV4aWY9Imh0dHA6Ly9ucy5hZG9iZS5jb20vZXhpZi8xLjAvIgogICAgICAgICAgICB4bWxuczp0aWZmPSJodHRwOi8vbnMuYWRvYmUuY29tL3RpZmYvMS4wLyI+CiAgICAgICAgIDxleGlmOlBpeGVsWURpbWVuc2lvbj4xMzwvZXhpZjpQaXhlbFlEaW1lbnNpb24+CiAgICAgICAgIDxleGlmOlBpeGVsWERpbWVuc2lvbj4xODwvZXhpZjpQaXhlbFhEaW1lbnNpb24+CiAgICAgICAgIDxleGlmOkNvbG9yU3BhY2U+MTwvZXhpZjpDb2xvclNwYWNlPgogICAgICAgICA8dGlmZjpPcmllbnRhdGlvbj4xPC90aWZmOk9yaWVudGF0aW9uPgogICAgICA8L3JkZjpEZXNjcmlwdGlvbj4KICAgPC9yZGY6UkRGPgo8L3g6eG1wbWV0YT4KyokfiQAAAVpJREFUKBWVUr8vBFEQ/oYEm+0U16ATzZWUlAqiusJfoNBpRGhk5SotEpcIrUhEcQoKjZCI0o87Sq5SXUTCFdyOb5Z9NpfbczebyZsf33wzb94CHYjeeTkN0NVBSXOolryK3iDTLNuSXcveFovHE4VHqOLNfE43xFxRATG/JRFC7BOzY8CfScJTZHoHzWflJlSPyUKuXzYzYlHVEdrTVAOciUiJnWdp70HEZziESl6yHwFjTqKxYo8ki7TXqclJ11D2e3iBZcb/8KoTkq1dxrUuQRLbxUWcaDjzeL86R2VyhhMtMCe81gqPKkRXGSskiWwXcw0EjW4Bj/4LLx2grjk81IoYRj93+RoBOc02tT35eprSe+8wfi3XidWj7TE41LyR8AE2kr+GLbXPsf5v2Etecx/K74Cb2nWTsU839cT1Szc+mVpK6xUtmwA7x6gDKcA647f8p55T8vgGGG/6odeeJi0AAAAASUVORK5CYII="
ICON_CLOUDY = "iVBORw0KGgoAAAANSUhEUgAAAA4AAAAJCAYAAAACTR1pAAAABGdBTUEAA1teXP8meAAAAERlWElmTU0AKgAAAAgAAYdpAAQAAAABAAAAGgAAAAAAA6ABAAMAAAABAAEAAKACAAQAAAABAAAADqADAAQAAAABAAAACQAAAAAP0OXqAAAAl0lEQVQoFWNgQAL///93BeLHQIwMjgA5MkjKUJlASRMg/oGsA4l9E8jmRNUB5QEldiIpxMZ8CBRcB8TWIC2MIALIEQNSj4CYHcQnAP4C5f1BmlyA+CsQkwIuMwJVXwWaoEXAFnTp3yCN34GiHOgyBPjXmIAKthBQhE26ngUomgrEr4HYC4ixBzlQAghAgXIbiLsYGRm3AgDv3bIb7l502wAAAABJRU5ErkJggg=="
ICON_RAIN = "iVBORw0KGgoAAAANSUhEUgAAABIAAAARCAYAAADQWvz5AAAABGdBTUEAA1teXP8meAAAAERlWElmTU0AKgAAAAgAAYdpAAQAAAABAAAAGgAAAAAAA6ABAAMAAAABAAEAAKACAAQAAAABAAAAEqADAAQAAAABAAAAEQAAAADdCciFAAAB2klEQVQ4EZVTzStEURQ/9/mYDxs2ylexlEKxU5oNZTZW05jJH2CrWGBhkI9SVozUKNnILGwUC2l81IyFSAwLK2QnkiFmxjt+d8a7vTSPcep0z/2d3/nd++45j+gfxpcOLwdI+0dJbirHHbd8RuW5sr+qc9y+yOd2l6lwne7pWe751F7Lcec2Ewm5/1UInBXStPlM4YmzklgcUHVxndyTTcwR6WGoQOtbTQaGMXMDYjdcEnaEEGf4JD/ODYHuAMwQnBYNbyNGjVwz1zIAiAwhnvyBT9FVySewYXgBPGtp3SUa3/eNrRKCSDtAlTAI3+sMpa926bqlA2cPANNwMRwqnhCP4xMXFB9Cy/C/LMSXzhE446G75SjwKZVyhAozQqgO/aWg8u93br5wrKkbGAEIrYqUX9Ana9GAoHk0ZPuLDdE8Vh2cWIYnaBWjETTmCG/GGnwzj8skwem3OszctWaQqiyIsv3nmKl7i7wJDgS0ntjrqAkhb+yl3hdN+MyYVax+EX/nQK8g/VESu7aubXLVSJv44FTUEw4XuCKRbItlIocpoZSe3EvfbQe9h4mm0rLKWclNJ1ODG21lN4U1XWMVtta2HPXWkP8oMeuJPqi3alk6LvLFEivWFdnMFz5RR1Pt96YzAAAAAElFTkSuQmCC"
ICON_SNOW = "iVBORw0KGgoAAAANSUhEUgAAABEAAAATCAYAAAB2pebxAAAABGdBTUEAA1teXP8meAAAAERlWElmTU0AKgAAAAgAAYdpAAQAAAABAAAAGgAAAAAAA6ABAAMAAAABAAEAAKACAAQAAAABAAAAEaADAAQAAAABAAAAEwAAAAD0U8BhAAABP0lEQVQ4EbWUTUsCURSGZ/xcCOGqXesQUbeu0mULF0G7aFcg9AP8Cf4Af4Dg2iAMF5Lopo27ggikWke00UUUQTk9ZzgOd7QJnfDCw7nv+XjnMtfRsja1HMepwBVM4A1GcAr2Ss+ksQFBq00h8acRDWdB00a+HmhCUxxejeag7ReFe2hCzmdIogjrrk8GDl0jNgfwtK6D9k8tNnvwHdLAHYtwlCpIDL1keDv0tA6KyfCfJl15J0nohHwn58xteT9jRIETZSG+wsk+6Lmxbfvx117M8mZBzb3UovYK8w0NNejBruSIx9CHkuqy6qP5jMTFq30h92w0vLMfg2PkREvev3CX70aeIjFl6ITqCDELO6L906oo7MMdnEiKmIFbcL9YYhoGILex9FcQU58JsQUPqmfEC7hWHSVewhS8G9Wa9QP+XBlDAWZyRwAAAABJRU5ErkJggg=="
ICON_THUNDERSTORM = "iVBORw0KGgoAAAANSUhEUgAAAA0AAAAPCAYAAAA/I0V3AAAABGdBTUEAA1teXP8meAAAAERlWElmTU0AKgAAAAgAAYdpAAQAAAABAAAAGgAAAAAAA6ABAAMAAAABAAEAAKACAAQAAAABAAAADaADAAQAAAABAAAADwAAAADTCkvOAAAA4ElEQVQoFY2RPQrCQBCFdxOJroIeQLBUsLDzDDbaCSKWXsJDeAib2FiaysbKTiSg6TyBICJYBXR8AykkszEZ+Mjm/SRDopRliMgFnsWSEoIdsAUxeIMTGMlkosDkwgOk5wNhZi3CCNLpn/snziswAVrzE3Co43IHJb7PGZ8LfXADhYdLh8LpJOhglVbOOsLmUiDU/8Je440VZBZgAPicNS8YO7C0BuioqnQxUzp7PVuA15NjzFw5eq3IrUlTKXtJ6yE+a4y/tqHQNG1FoWG9BkXmSmG5LcwsAYUxRV43y/8CbJvvT+SpSbMAAAAASUVORK5CYII="
ICON_HAZE = "iVBORw0KGgoAAAANSUhEUgAAABQAAAASCAYAAABb0P4QAAAABGdBTUEAA1teXP8meAAAAERlWElmTU0AKgAAAAgAAYdpAAQAAAABAAAAGgAAAAAAA6ABAAMAAAABAAEAAKACAAQAAAABAAAAFKADAAQAAAABAAAAEgAAAAA9nQVdAAABrElEQVQ4EZ1TO0vDUBQ+J2mbpHQSxMFJfNASBTed/QNSXIRuDro46D9wcHZ18we4iC/wZxhqSsFFXXxgB5HWPmiP302p3CZ9xF5I7rnfq/fcmxLFGOI7T3LvzMaQkhFHRMQ2mR07jrYvUB6cQyk6+YiR6Z06jW8dFz/lim+f6liklpKzLn66guCtCKkBUkzloHvDs6vBQclhQIWS0Da7PwfiU4rI2SSRLHSvVK1f8BpVELRH1GmxWz8L+yOBPYH41gKxcYvzW+phmL9I2vixxp2G9ZUDA+WcTHLTHjG5fWq1EKnhnUMHLxEOQHAp4tlz4qWW1RyIctbGwDBFMqfx2lGlFGkm8KkzPepmGcE5JY0rSprXhDlYG+a8Mgwf0uUN5yTwGfDmk6tKn2CXmkS1Fd0spTbaMXUoVPOzAtB2IUSgsQFDBPhjJkstsSK04BuwqmVepEaEA/AXKCI3WHfPcJByNCagC8zsjZZNwAY7xO6m4E1O4FeWNnb22fMywtQ5XeLBv2Ki0YZLtfsxkXucSb8U9W1lxhmG8OpSythlM6EJ9lFPa+v/lscwlH8BPVaII2dOARgAAAAASUVORK5CYII="

CONDITION_ICON_TABLE = [
    (200, 299, ICON_THUNDERSTORM), # thunderstorn
    (300, 399, ICON_RAIN), # drizzle
    (500, 599, ICON_RAIN), # rain
    (600, 699, ICON_SNOW), # snow
    (700, 799, ICON_HAZE), # "atmosphere"
    (800, 800, ICON_CLEAR), # clear
    (801, 802, ICON_FEW_CLOUDS), # clouds 11%-50%
    (803, 804, ICON_CLOUDY) # clouds 51%-100%
]

def lookup_condition_icon(code):
    for start, end, label in CONDITION_ICON_TABLE:
        if (start <= code) and (code <= end):
            return label
    return ICON_CLEAR

def main():
    # Time
    timezone = "America/Phoenix"  # Placeholder timezone
    now = time.now().in_location(timezone)

    resp = http.get(API_URL, ttl_seconds = 300)
    if resp.status_code != 200:
        fail("API Fetch failed %d", resp.status_code)

    # Weather
    temperature = resp.json()["temp_f"]
    humidity = resp.json()["humidity"]
    condition_code = resp.json()["condition_code"]
    condition_icon = base64.decode(lookup_condition_icon(condition_code))

    # Layout
    return render.Root(
        delay = 500,
        child = render.Box(
            render.Column(
                expanded = True,
                main_align = "space_evenly",
                cross_align = "center",
                children = [
                    # Render Time
                    render.Animation(
                        children = [
                            render.Text(
                                content = now.format("3:04 PM"),
                                font = "6x13",
                            ),
                            render.Text(
                                content = now.format("3 04 PM"),
                                font = "6x13",
                            ),
                        ],
                    ),
                    render.Row(
                        cross_align = "center",
                        children = [
                            # Render Weather Icon
                            render.Image(src = condition_icon),
                            render.Column(
                                children = [
                                    # Render Temperature
                                    render.Text(
                                        content = "%d" % temperature,
                                        font = "5x8",
                                    ),
                                    # Render Precipitation
                                    render.Text(
                                        content = "%d%%" % humidity,
                                        font = "5x8",
                                        color = "#848fEE",
                                    ),
                                ],
                            ),
                        ],
                    ),
                ],
            ),
        ),
    )
