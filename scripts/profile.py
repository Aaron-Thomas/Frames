#!/usr/bin/env python3
"""Profiles the scroll behind the README's results and prints them as a Markdown table.

Usage: scripts/profile.py <iPhone UDID> <simulator UDID>
       scripts/profile.py --read    (reads the last runs again without recording)

Runs the same scroll three times, each from a fresh install so the caches start empty:

1. On the simulator with Points of Interest, for the pipeline's counts. A phone keeps only the last
   couple of hundred signposts per app when Instruments records from the command line, so a full
   scroll's two thousand don't survive there. The simulator logs on the Mac and keeps them all.
2. On the iPhone with HTTP Traffic and Activity Monitor, for network and memory.
3. On the iPhone with the Animation Hitches template, on its own because hitch tracing is heavy.

The test emits "Scrolling down", "Scrolling up" and "Back at the top" signposts, which mark each phase.

Traces and logs stay in build/profile.
"""
import signal
import statistics
import subprocess
import sys
import time
import xml.etree.ElementTree as ElementTree
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUTPUT = ROOT / "build" / "profile"
SIMULATOR_TRACE = OUTPUT / "simulator.trace"
IPHONE_TRACE = OUTPUT / "iphone.trace"
HITCHES_TRACE = OUTPUT / "hitches.trace"
BUNDLE_ID = "com.aaronthomas.Frames"
APP_PROCESS = "Frames ("
SCROLL_TEST = "FramesUITests/ScrollProfileTests/testScrollingPastPhoto450AndBack"


def xcodebuild(action, udid, *options):
    subprocess.run([
        "xcodebuild", action,
        "-project", str(ROOT / "Frames.xcodeproj"),
        "-scheme", "FramesProfile",
        "-destination", f"id={udid}",
        "-derivedDataPath", str(OUTPUT / "DerivedData"),
        "-quiet", *options
    ], check=True)


def delete_app(udid, simulator):
    if simulator:
        command = ["xcrun", "simctl", "uninstall", udid, BUNDLE_ID]
    else:
        command = ["xcrun", "devicectl", "device", "uninstall", "app", "--device", udid, BUNDLE_ID]
    subprocess.run(command, capture_output=True)


def record_scroll(udid, simulator, trace, instruments, template=None):
    """Runs the scroll test from a fresh install while Instruments records every process."""
    delete_app(udid, simulator)
    subprocess.run(["rm", "-rf", str(trace)], check=True)
    command = ["xcrun", "xctrace", "record", "--device", udid, "--all-processes", "--no-prompt", "--output", str(trace)]
    if template:
        command += ["--template", template]
    for instrument in instruments:
        command += ["--instrument", instrument]
    recorder = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
    for line in recorder.stdout:
        if "Ctrl-C to stop" in line:
            break
    try:
        xcodebuild("test-without-building", udid, f"-only-testing:{SCROLL_TEST}")
    finally:
        recorder.send_signal(signal.SIGINT)
        recorder.communicate()


def export(trace, schema):
    """Writes one table of a trace to a file. A trace can still be finishing when recording stops,
    so a failed export is retried."""
    path = OUTPUT / f"{trace.stem}-{schema}.xml"
    xpath = f'/trace-toc/run[@number="1"]/data/table[@schema="{schema}"]'
    for _ in range(3):
        with path.open("w") as file:
            command = ["xcrun", "xctrace", "export", "--input", str(trace), "--xpath", xpath]
            result = subprocess.run(command, stdout=file, stderr=subprocess.DEVNULL)
        if result.returncode == 0 and path.stat().st_size > 0:
            return path
        time.sleep(10)
    sys.exit(f"Couldn't export the {schema} table from {trace}")


def rows(trace, schema):
    """Each row of a trace table as {column: (value, label)}. The export writes a repeated value once
    with an id and refers back to it with ref, so values are kept by id as the rows stream past."""
    values, columns, mnemonics = {}, [], []
    for _, element in ElementTree.iterparse(export(trace, schema)):
        if element.get("id"):
            values[element.get("id")] = (element.text, element.get("fmt") or "")
        if element.tag == "mnemonic":
            mnemonics.append(element.text)
        elif element.tag == "schema":
            # Only the first of several tables with the same schema lists its columns. The rest reuse them.
            columns, mnemonics = mnemonics, []
        elif element.tag == "row":
            yield {column: values.get(cell.get("ref")) or (cell.text, cell.get("fmt") or "")
                   for column, cell in zip(columns, element)}
            element.clear()


def label(cells, column):
    return cells.get(column, (None, ""))[1]


def number(cells, column):
    return int(cells[column][0])


def milliseconds(nanoseconds):
    return nanoseconds / 1_000_000


def pipeline_counts():
    """Requests, memory hits, joins, cancellations, loads and decodes, from the simulator run."""
    events, loads, decodes = {}, [], []
    for cells in rows(SIMULATOR_TRACE, "os-signpost"):
        if label(cells, "subsystem") == "Frames" and label(cells, "event-type") == "Event":
            events[label(cells, "name")] = events.get(label(cells, "name"), 0) + 1
    for cells in rows(SIMULATOR_TRACE, "region-of-interest"):
        if label(cells, "subsystem") == "Frames":
            if label(cells, "name") == "Image load":
                loads.append(number(cells, "duration"))
            elif label(cells, "name") == "Decode":
                decodes.append((number(cells, "duration"), label(cells, "start-thread").startswith("Main Thread")))
    return events, loads, decodes


def scroll_markers(trace):
    """When scrolling started, turned and ended. The test runner emits so few signposts that a phone keeps them."""
    times = {label(cells, "name"): number(cells, "time") for cells in rows(trace, "os-signpost")
             if label(cells, "subsystem") == "FramesUITests"}
    return times["Scrolling down"], times["Scrolling up"], times["Back at the top"]


def network_and_memory():
    """Downloads and memory from the iPhone run. A URL's first request is a download. Any later request
    for it is answered by the disk cache, which holds far more than the run downloads."""
    _, turnaround, finish = scroll_markers(IPHONE_TRACE)
    requests = sorted((number(cells, "start"), cells["url"][0] or label(cells, "url"), number(cells, "duration"))
                      for cells in rows(IPHONE_TRACE, "com-apple-cfnetwork-transaction-intervals-full-info")
                      if label(cells, "process").startswith(APP_PROCESS))
    seen, downloads, repeats = set(), [], []
    for start, url, duration in requests:
        (repeats if url in seen else downloads).append((start, duration))
        seen.add(url)
    samples = [(number(cells, "start"), number(cells, "memory-physical-footprint"))
               for cells in rows(IPHONE_TRACE, "activity-monitor-process-live")
               if label(cells, "process").startswith(APP_PROCESS)]
    at_turnaround = max((sample for sample in samples if sample[0] <= turnaround), default=(0, 0))[1]
    peak = max((footprint for _, footprint in samples), default=0)
    return {
        "downloads": len(downloads),
        "downloads scrolling up": sum(1 for start, _ in downloads if turnaround <= start <= finish),
        "download median": statistics.median(duration for _, duration in downloads) if downloads else 0,
        "repeats scrolling up": [duration for start, duration in repeats if turnaround <= start <= finish],
        "memory at turnaround": at_turnaround,
        "memory peak": peak,
    }


def hitches():
    """The app's hitches in the hitches run, per second of scrolling. Hitch tracing floods the buffer that keeps
    the test's markers too, so the same scroll is timed from the iPhone run. Scrolling time includes the moment
    XCUITest waits after each flick, so the ratio reads slightly low."""
    start, _, finish = scroll_markers(IPHONE_TRACE)
    durations = [number(cells, "duration") for cells in rows(HITCHES_TRACE, "hitches")
                 if label(cells, "process").startswith(APP_PROCESS)]
    seconds = (finish - start) / 1_000_000_000
    return {"ratio": milliseconds(sum(durations)) / seconds, "count": len(durations),
            "longest": milliseconds(max(durations, default=0)), "seconds": seconds}


def summarise():
    events, loads, decodes = pipeline_counts()
    hits, joins = events.get("Memory cache hit", 0), events.get("Joined in-flight load", 0)
    requests = hits + joins + len(loads)
    main_thread_decodes = [duration for duration, is_main_thread in decodes if is_main_thread]
    network = network_and_memory()
    repeats = network["repeats scrolling up"]
    hitch_summary = hitches()

    def share(count):
        return f"{count / requests:.0%} ({count:,})" if requests else "0"

    return "\n".join([
        "| Measure | Result |",
        "|---|---|",
        f"| Image requests to the pipeline | {requests:,} |",
        f"| Served from memory | {share(hits)} |",
        f"| Joined an in-flight load | {share(joins)} |",
        f"| Loads cancelled while scrolling | {events.get('Load cancelled', 0):,} |",
        f"| Network requests when scrolling back up | {network['downloads scrolling up']:,} "
        f"({len(repeats):,} images came back from the disk cache, median "
        f"{milliseconds(statistics.median(repeats) if repeats else 0):.0f} ms) |",
        f"| Memory at photo 450 and peak | {network['memory at turnaround'] / 1_048_576:.0f} MB, "
        f"peak {network['memory peak'] / 1_048_576:.0f} MB |",
        f"| Main-thread decode time | {milliseconds(sum(main_thread_decodes)):.0f} ms "
        f"({len(main_thread_decodes)} of {len(decodes):,} decodes on the main thread) |",
        f"| Hitch time ratio | {hitch_summary['ratio']:.1f} ms/s ({hitch_summary['count']} hitches in "
        f"{hitch_summary['seconds']:.0f} s of scrolling, the longest {hitch_summary['longest']:.0f} ms) |",
        "",
        f"Image loads: {len(loads):,}, averaging {milliseconds(statistics.mean(loads)) if loads else 0:.0f} ms. "
        f"Decodes averaged {milliseconds(statistics.mean(duration for duration, _ in decodes)) if decodes else 0:.1f} ms. "
        f"Downloads on the iPhone: {network['downloads']:,}, median {milliseconds(network['download median']):.0f} ms.",
    ])


def main():
    if sys.argv[1:] != ["--read"]:
        if len(sys.argv) != 3:
            sys.exit(__doc__)
        iphone, simulator = sys.argv[1], sys.argv[2]
        OUTPUT.mkdir(parents=True, exist_ok=True)
        print("Building the FramesProfile scheme in Release...")
        xcodebuild("build-for-testing", simulator)
        xcodebuild("build-for-testing", iphone, "-allowProvisioningUpdates")
        print("1 of 3: the pipeline's counts on the simulator...")
        record_scroll(simulator, True, SIMULATOR_TRACE, ["Points of Interest"])
        print("2 of 3: network and memory on the iPhone...")
        record_scroll(iphone, False, IPHONE_TRACE, ["Points of Interest", "HTTP Traffic", "Activity Monitor"])
        print("3 of 3: hitches on the iPhone...")
        record_scroll(iphone, False, HITCHES_TRACE, [], template="Animation Hitches")
    print("Reading the results...")
    results = summarise()
    (OUTPUT / "results.md").write_text(results + "\n")
    print(results)


if __name__ == "__main__":
    main()
