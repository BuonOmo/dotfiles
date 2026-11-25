#!/usr/bin/env python

import datetime
import itertools
import os
import subprocess
import sys
import urllib.error
import urllib.request

URL = "https://eu.ftp.opendatasoft.com/sncf/plandata/Export_OpenData_SNCF_GTFS_NewTripId.zip"
# TODO: find id of the stop, don't assume it.
GRENOBLE_ID = "87747006"
LYON_PD_ID = "87723197"
STOP_IDS = {
    "Grenoble": GRENOBLE_ID,
    "Lyon Part Dieu": LYON_PD_ID,
}
CACHE_PATH = os.path.expanduser("~/.cache/horaire-train/gtfs.zip")


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
        from datetime import date, timedelta

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
    today = datetime.date.today().strftime("%Y%m%d")
    tomorrow = (datetime.date.today() + datetime.timedelta(days=1)).strftime("%Y%m%d")

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

    today_service_ids = set()
    tomorrow_service_ids = set()
    for cd in gtfs.calendar_dates:
        if cd["exception_type"] != "1":
            continue

        if cd["date"] == today:
            today_service_ids.add(cd["service_id"])
        if cd["date"] == tomorrow:
            tomorrow_service_ids.add(cd["service_id"])

    today_trip_ids = set()
    tomorrow_trip_ids = set()
    for t in gtfs.trips:
        if t["route_id"] != route["route_id"] or t["direction_id"] != search_direction:
            continue

        if t["service_id"] in today_service_ids:
            today_trip_ids.add(t["trip_id"])
        if t["service_id"] in tomorrow_service_ids:
            tomorrow_trip_ids.add(t["trip_id"])

    today_departures = set()
    tomorrow_departures = set()

    for st in gtfs.stop_times:
        if not STOP_IDS[search_from] in st["stop_id"]:
            continue

        if st["trip_id"] in today_trip_ids:
            today_departures.add(st["departure_time"])
        if st["trip_id"] in tomorrow_trip_ids:
            tomorrow_departures.add(st["departure_time"])

    today_time = datetime.datetime.now().strftime("%H:%M:%S")
    today_departures = [d for d in today_departures if d > today_time]

    today_len = len(today_departures)
    tomorrow_len = len(tomorrow_departures)
    today_departures = sorted(today_departures)[:20]
    tomorrow_departures = sorted(tomorrow_departures)[: (20 - len(today_departures))]
    if not today_departures and not tomorrow_departures:
        print(f"No departures from {search_from} to {search_to} today or tomorrow.")
        sys.exit(0)

    title = f"Next departures from {search_from} to {search_to}"
    print(f"{title}\n{'=' * len(title)}\n")
    today_lines: list[str] = []
    if today_departures:
        today_lines.append("Today")
        for departure in sorted(today_departures):
            today_lines.append(departure[:5])
        if len(today_departures) < today_len:
            today_lines.append("...")

    tomorrow_lines: list[str] = []
    if tomorrow_departures:
        tomorrow_lines.append("Tomorrow")
        for departure in sorted(tomorrow_departures):
            tomorrow_lines.append(departure[:5])
        if len(tomorrow_departures) < tomorrow_len:
            tomorrow_lines.append("...")

    for line in itertools.zip_longest(
        *filter(None, [today_lines, tomorrow_lines]), fillvalue=""
    ):
        for col in line:
            print(f"{col:^12}", end="\t")
        print()
