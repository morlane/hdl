# ms8607_pc_interface.py
#
# PC interface for AC701 / MicroBlaze / MS8607 debug UART
#
# Expected MicroBlaze flow:
#   1. FPGA boots to debug menu
#   2. Script waits for "debug>"
#   3. Script sends "run"
#   4. MicroBlaze initializes MS8607 and continuously prints:
#
#      Battery : GOOD
#      Heater  : OFF
#      25.94C | 996.63hPa | 41.94%RH | T[25.94, 25.94] | P[996.63, 996.63] | H[41.94, 43.07]
#
# Features:
#   - UART auto-start using debug prompt
#   - CSV logging with timestamped filename
#   - Live plots: temperature C, pressure hPa, humidity %RH
#   - Large live readouts
#   - Battery and heater status display
#   - Min/max display from the MicroBlaze output
#   - Pause/resume CSV capture button
#   - Saves PNG snapshot when the window closes
#
# Install:
#   pip install pyserial matplotlib
#
# Run:
#   python ms8607_pc_interface.py

import re
import csv
import time
from collections import deque
from datetime import datetime
from pathlib import Path

import serial
import matplotlib.pyplot as plt
from matplotlib.animation import FuncAnimation
from matplotlib.widgets import Button


# ---------------- USER SETTINGS ----------------
PORT = "COM5"
BAUD = 115200
SERIAL_TIMEOUT = 0.25

PROMPT_TEXT = "debug>"
RUN_COMMAND = "run\r\n"
SEND_RUN_ON_START = True

DISPLAY_WINDOW = 300
OUTPUT_DIR = Path(".")
# ------------------------------------------------


timestamp_tag = datetime.now().strftime("%Y%m%d_%H%M%S")
CSV_FILE = OUTPUT_DIR / f"ms8607_ac701_{timestamp_tag}.csv"
PNG_FILE = OUTPUT_DIR / f"ms8607_ac701_{timestamp_tag}.png"


data_pattern = re.compile(
    r"([-+]?\d+(?:\.\d+)?)\s*C\s*\|\s*"
    r"([-+]?\d+(?:\.\d+)?)\s*hPa\s*\|\s*"
    r"([-+]?\d+(?:\.\d+)?)\s*%RH\s*\|\s*"
    r"T\[\s*([-+]?\d+(?:\.\d+)?)\s*,\s*([-+]?\d+(?:\.\d+)?)\s*\]\s*\|\s*"
    r"P\[\s*([-+]?\d+(?:\.\d+)?)\s*,\s*([-+]?\d+(?:\.\d+)?)\s*\]\s*\|\s*"
    r"H\[\s*([-+]?\d+(?:\.\d+)?)\s*,\s*([-+]?\d+(?:\.\d+)?)\s*\]",
    re.IGNORECASE
)

battery_pattern = re.compile(r"Battery\s*:\s*(.+)", re.IGNORECASE)
heater_pattern = re.compile(r"Heater\s*:\s*(.+)", re.IGNORECASE)


def wait_for_prompt(ser: serial.Serial, prompt: str):
    print(f"Waiting for {prompt!r} prompt...")
    rx_buffer = ""

    while prompt not in rx_buffer:
        line = ser.readline().decode(errors="ignore")
        if line:
            print(line, end="")
            rx_buffer += line

        if len(rx_buffer) > 4096:
            rx_buffer = rx_buffer[-4096:]


def autoscale_axis(ax, x, y):
    if len(x) < 2 or len(y) < 2:
        return

    ax.set_xlim(min(x), max(x))

    ymin = min(y)
    ymax = max(y)

    pad = 0.1 if ymin == ymax else (ymax - ymin) * 0.10
    ax.set_ylim(ymin - pad, ymax + pad)


def main():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    print(f"Opening {PORT} at {BAUD} baud...")
    ser = serial.Serial(PORT, BAUD, timeout=SERIAL_TIMEOUT)

    if SEND_RUN_ON_START:
        wait_for_prompt(ser, PROMPT_TEXT)
        print(f"\nSending command: {RUN_COMMAND.strip()}")
        ser.write(RUN_COMMAND.encode("ascii"))

    sample_num = 0
    capture_enabled = True
    battery_status = "UNKNOWN"
    heater_status = "UNKNOWN"

    start_time = time.time()

    time_s = deque(maxlen=DISPLAY_WINDOW)
    temp_c = deque(maxlen=DISPLAY_WINDOW)
    pressure_hpa = deque(maxlen=DISPLAY_WINDOW)
    humidity_rh = deque(maxlen=DISPLAY_WINDOW)

    csv_file = open(CSV_FILE, "w", newline="")
    csv_writer = csv.writer(csv_file)

    csv_writer.writerow([
        "sample",
        "timestamp",
        "elapsed_s",
        "temp_c",
        "pressure_hpa",
        "humidity_rh",
        "temp_min_c",
        "temp_max_c",
        "pressure_min_hpa",
        "pressure_max_hpa",
        "humidity_min_rh",
        "humidity_max_rh",
        "battery_status",
        "heater_status",
    ])
    csv_file.flush()

    fig, axs = plt.subplots(3, 1, sharex=True)
    fig.canvas.manager.set_window_title("AC701 MS8607 PC Interface")
    fig.suptitle("AC701 MS8607 PC Interface", fontsize=14)

    plt.subplots_adjust(top=0.76, bottom=0.16, hspace=0.35)

    line_temp, = axs[0].plot([], [])
    line_press, = axs[1].plot([], [])
    line_hum, = axs[2].plot([], [])

    axs[0].set_ylabel("Temp [C]")
    axs[1].set_ylabel("Pressure [hPa]")
    axs[2].set_ylabel("Humidity [%RH]")
    axs[2].set_xlabel("Time [s]")

    for ax in axs:
        ax.grid(True)

    readout_text = fig.text(
        0.02, 0.94,
        "Waiting for MS8607 data...",
        fontsize=12,
        va="top",
        family="monospace"
    )

    minmax_text = fig.text(
        0.02, 0.82,
        "",
        fontsize=10,
        va="top",
        family="monospace"
    )

    status_text = fig.text(
        0.66, 0.94,
        "",
        fontsize=10,
        va="top",
        family="monospace"
    )

    button_ax = fig.add_axes([0.72, 0.04, 0.18, 0.06])
    capture_button = Button(button_ax, "Pause Capture")

    def on_button_clicked(_event):
        nonlocal capture_enabled
        capture_enabled = not capture_enabled
        capture_button.label.set_text("Resume Capture" if not capture_enabled else "Pause Capture")

    capture_button.on_clicked(on_button_clicked)

    def update(_frame):
        nonlocal sample_num, battery_status, heater_status

        while ser.in_waiting:
            raw = ser.readline().decode(errors="ignore").strip()

            if not raw:
                continue

            print(raw)

            bmatch = battery_pattern.search(raw)
            if bmatch:
                battery_status = bmatch.group(1).strip()
                continue

            hmatch = heater_pattern.search(raw)
            if hmatch:
                heater_status = hmatch.group(1).strip()
                continue

            dmatch = data_pattern.search(raw)
            if not dmatch:
                continue

            tc = float(dmatch.group(1))
            ph = float(dmatch.group(2))
            rh = float(dmatch.group(3))

            t_min = float(dmatch.group(4))
            t_max = float(dmatch.group(5))

            p_min = float(dmatch.group(6))
            p_max = float(dmatch.group(7))

            h_min = float(dmatch.group(8))
            h_max = float(dmatch.group(9))

            elapsed = time.time() - start_time
            timestamp = datetime.now().isoformat(timespec="seconds")

            readout_text.set_text(
                f"TEMP      {tc:8.2f} C\n"
                f"PRESSURE  {ph:8.2f} hPa\n"
                f"HUMIDITY  {rh:8.2f} %RH"
            )

            minmax_text.set_text(
                "MIN / MAX FROM MICROBlaze\n"
                f"TEMP      [{t_min:8.2f}, {t_max:8.2f}] C\n"
                f"PRESSURE  [{p_min:8.2f}, {p_max:8.2f}] hPa\n"
                f"HUMIDITY  [{h_min:8.2f}, {h_max:8.2f}] %RH"
            )

            if capture_enabled:
                sample_num += 1

                csv_writer.writerow([
                    sample_num,
                    timestamp,
                    f"{elapsed:.3f}",
                    f"{tc:.3f}",
                    f"{ph:.3f}",
                    f"{rh:.3f}",
                    f"{t_min:.3f}",
                    f"{t_max:.3f}",
                    f"{p_min:.3f}",
                    f"{p_max:.3f}",
                    f"{h_min:.3f}",
                    f"{h_max:.3f}",
                    battery_status,
                    heater_status,
                ])
                csv_file.flush()

                time_s.append(elapsed)
                temp_c.append(tc)
                pressure_hpa.append(ph)
                humidity_rh.append(rh)

        line_temp.set_data(time_s, temp_c)
        line_press.set_data(time_s, pressure_hpa)
        line_hum.set_data(time_s, humidity_rh)

        autoscale_axis(axs[0], time_s, temp_c)
        autoscale_axis(axs[1], time_s, pressure_hpa)
        autoscale_axis(axs[2], time_s, humidity_rh)

        status_text.set_text(
            f"Battery : {battery_status}\n"
            f"Heater  : {heater_status}\n"
            f"Capture : {'ON' if capture_enabled else 'PAUSED'}\n"
            f"Samples : {sample_num}\n"
            f"CSV     : {CSV_FILE.name}\n"
            f"PNG     : {PNG_FILE.name}"
        )

        return line_temp, line_press, line_hum

    try:
        ani = FuncAnimation(fig, update, interval=250, cache_frame_data=False)
        plt.show()
    finally:
        print("Saving graph snapshot...")
        try:
            fig.savefig(PNG_FILE, dpi=150)
            print(f"Saved PNG: {PNG_FILE}")
        except Exception as exc:
            print(f"Could not save PNG: {exc}")

        print("Closing CSV and serial port...")
        csv_file.close()
        ser.close()
        print(f"Saved CSV: {CSV_FILE}")


if __name__ == "__main__":
    main()
