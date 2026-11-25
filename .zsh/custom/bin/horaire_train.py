#!/usr/bin/env python

import itertools
import os
import re
import shutil
import subprocess
import sys
import urllib.error
import urllib.request
from datetime import date, datetime, timedelta
from pprint import pprint

URL = "https://eu.ftp.opendatasoft.com/sncf/plandata/Export_OpenData_SNCF_GTFS_NewTripId.zip"
# TODO: find id of the stop, don't assume it.
GRENOBLE_ID = "87747006"
LYON_PD_ID = "87723197"
STOP_IDS = {
    "Grenoble": GRENOBLE_ID,
    "Lyon Part Dieu": LYON_PD_ID,
}
CACHE_PATH = os.path.expanduser("~/.cache/horaire-train/gtfs.zip")


class TTYStr(str):
    def __new__(cls, value, /, *, bold=False, italic=False, color=None):
        obj = super().__new__(cls, value)
        return obj

    def __init__(self, value, /, *, bold=False, italic=False, color=None):
        if isinstance(value, TTYStr):
            self.bold = bold or value.bold
            self.italic = italic or value.italic
            self.color = color or value.color
        else:
            self.bold = bold
            self.italic = italic
            self.color = color

    def __format__(self, format_spec: str, /) -> str:
        """
        >>> f"{TTYStr('12:34', bold=True):^10}"
        '  \\x1b[1m12:34\\x1b[0m   '
        >>> f"{TTYStr('12:34', color='gray'):^10}"
        '  \\x1b[90m12:34\\x1b[0m   '
        >>> f"{TTYStr('12:34', bold=True, color='gray'):>10}"
        '     \\x1b[90m\\x1b[1m12:34\\x1b[0m'
        """
        invisible_characters = len(str(self)) - len(super().__str__())

        def num(s: str) -> int | float:
            try:
                return int(s)
            except ValueError:
                return float(s)

        return format(
            str(self),
            re.sub(
                # 19.0 means 19 and remove everything in the string.
                r"\d+.?[1-9]\d*|\d+",
                lambda m: str(num(m.group(0)) + invisible_characters),
                format_spec,
            ),
        )

    def __str__(self):
        s = super().__str__()
        if self.bold:
            s = f"\x1b[1m{s}"
        if self.italic:
            s = f"\x1b[3m{s}"
        match self.color:
            case "gray" | "grey":
                s = f"\x1b[90m{s}"

        if s.startswith("\x1b"):
            s = f"{s}\x1b[0m"
        return s


def timed(func):
    import time

    def wrapper(*args, **kwargs):
        start = time.time()
        result = func(*args, **kwargs)
        end = time.time()
        print(f"{func.__name__} took {end - start:.2f} seconds")
        return result

    return wrapper


def parse_gtfs(gtfs_path, filename):
    with subprocess.Popen(
        ["unzip", "-p", gtfs_path, filename],
        stdout=subprocess.PIPE,
    ) as proc:
        if proc.stdout is None:
            raise RuntimeError("Failed to open GTFS file")

        headers = proc.stdout.readline().decode("utf-8").strip().split(",")
        for line in proc.stdout:
            yield dict(zip(headers, line.decode("utf-8").strip().split(",")))


class GTFS:
    @classmethod
    def init_gtfs(cls, url):
        if not os.path.exists(CACHE_PATH):
            os.makedirs(os.path.dirname(CACHE_PATH), exist_ok=True)
            urllib.request.urlretrieve(url, CACHE_PATH)

    @classmethod
    def fetch_gtfs(cls, url):
        cls.init_gtfs(url)

        end_date = date.strptime(
            next(parse_gtfs(CACHE_PATH, "feed_info.txt"))["feed_end_date"], "%Y%m%d"
        )
        time_left = end_date - date.today()

        if time_left.days < 60:
            try:
                urllib.request.urlretrieve(url, CACHE_PATH)
            except urllib.error.URLError:
                print(
                    f"Failed to update GTFS. It will be outdated in {time_left.days} days\n",
                    file=sys.stderr,
                )
        return CACHE_PATH

    def __init__(self, gtfs_path):
        self.gtfs_path = gtfs_path
        parse = timed(lambda filename: list(parse_gtfs(gtfs_path, filename)))
        self.trips = parse("trips.txt")
        self.stop_times = parse("stop_times.txt")
        self.routes = parse("routes.txt")
        self.calendar_dates = parse("calendar_dates.txt")


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1].lower().startswith("gre"):
        search_from = "Grenoble"
        search_to = "Lyon Part Dieu"
        # TODO: detect direction_id correctly, for now we assume direction_id=0 is from Lyon to Grenoble
        search_direction = "1"
    else:
        search_from = "Lyon Part Dieu"
        search_to = "Grenoble"
        search_direction = "0"
    search_window = 7
    search_days = {
        (date.today() + timedelta(days=i)).strftime("%Y%m%d")
        for i in range(search_window)
    }

    gtfs = GTFS(GTFS.fetch_gtfs(URL))
    routes = filter(
        lambda r: (
            # NOTE: This works because we know how the dataset is structured. We
            #  should use stops instead, but there are many stops at a same points,
            #  making it tedious for current use.
            search_from in r["route_long_name"] and search_to in r["route_long_name"]
        ),
        gtfs.routes,
    )
    route = next(routes, None)
    if route is None:
        raise RuntimeError("No routes found from Lyon to Grenoble")
    if next(routes, None):
        raise RuntimeError("Multiple routes found from Lyon to Grenoble")

    service_ids = set()
    dates_by_service_id: dict[str, set[str]] = {}

    for cd in gtfs.calendar_dates:
        if cd["exception_type"] != "1" or cd["date"] not in search_days:
            continue

        service_ids.add(cd["service_id"])
        dates_by_service_id.setdefault(cd["service_id"], set()).add(cd["date"])

    trip_ids = set()
    trip_ids_by_service_id: dict[str, set[str]] = {}
    for t in gtfs.trips:
        if (
            t["route_id"] != route["route_id"]
            or t["direction_id"] != search_direction
            or t["service_id"] not in service_ids
        ):
            continue

        trip_ids.add(t["trip_id"])
        trip_ids_by_service_id.setdefault(t["service_id"], set()).add(t["trip_id"])

    departures: dict[str, str] = {}
    arrivals: dict[str, str] = {}

    for st in gtfs.stop_times:
        if st["trip_id"] not in trip_ids:
            continue

        if STOP_IDS[search_from] in st["stop_id"]:
            departures[st["trip_id"]] = st["departure_time"]
        if STOP_IDS[search_to] in st["stop_id"]:
            arrivals[st["trip_id"]] = st["arrival_time"]

    da_by_dates: dict[str, list[tuple[str, str]]] = {}
    for day in search_days:
        for service_id, trip_ids in trip_ids_by_service_id.items():
            if day not in dates_by_service_id[service_id]:
                continue

            for trip_id in trip_ids:
                if trip_id not in departures or trip_id not in arrivals:
                    continue

                da_by_dates.setdefault(day, []).append(
                    (departures[trip_id], arrivals[trip_id])
                )

    if not departures:
        print(
            f"No departures from {search_from} to {search_to} in the next {search_window} days."
        )
        sys.exit(0)

    tcols, _ = shutil.get_terminal_size()
    title = TTYStr(
        f"Next departures from {search_from} to {search_to}", bold=True, italic=True
    )
    print(TTYStr(f"{title:^{tcols}}\n{'=' * len(title):^{tcols}}\n", bold=True))

    today = date.today().strftime("%Y%m%d")
    tomorrow = (date.today() + timedelta(days=1)).strftime("%Y%m%d")
    now = datetime.now().strftime("%H:%M:%S")

    lines_by_day = [
        [
            TTYStr(
                {
                    today: "Today",
                    tomorrow: "Tomorrow",
                }.get(
                    day,
                    date.strptime(day, "%Y%m%d").strftime("%A %d/%m"),
                ),
                bold=True,
            )
        ]
        + sorted(
            TTYStr(
                f"{dep:.5} -> {arr:.5}",
                color="gray" if day == today and dep < now else None,
            )
            for dep, arr in da_by_dates[day]
        )
        for day in sorted(search_days)
    ]

    # TODO: rather than printing in order of index, we could align the columns by time.
    for line in itertools.zip_longest(*filter(None, lines_by_day), fillvalue=""):
        for col in line:
            print(f"{col:^{tcols / 7}}", end="")
        print()
