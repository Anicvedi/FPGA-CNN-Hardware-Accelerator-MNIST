import tkinter as tk
from tkinter import ttk, messagebox
import serial
import serial.tools.list_ports
from PIL import Image, ImageDraw
import struct
import os  # <-- Added for directory management

class MNISTHardwareApp:
    def __init__(self, root):
        self.root = root
        self.root.title("CNN Hardware Accelerator - MNIST Interface")
        self.root.geometry("550x420")
        self.root.configure(bg="#2E3440")
        
        # --- Configuration ---
        self.CANVAS_SIZE = 280
        self.MNIST_SIZE = 28
        self.PEN_WIDTH = 22
        self.FRAC_BITS = 10
        self.SCALE = 2 ** self.FRAC_BITS
        
        self.serial_conn = None
        self.old_x, self.old_y = None, None

        self.image = Image.new("L", (self.CANVAS_SIZE, self.CANVAS_SIZE), color=0)
        self.draw = ImageDraw.Draw(self.image)

        self._build_ui()

    def _build_ui(self):
        style = ttk.Style()
        style.theme_use('clam')
        
        # Left Frame: Drawing Canvas
        left_frame = tk.Frame(self.root, bg="#2E3440", padx=15, pady=15)
        left_frame.pack(side=tk.LEFT, fill=tk.BOTH)
        
        canvas_label = tk.Label(left_frame, text="Draw Digit (0-9)", bg="#2E3440", fg="white", font=("Arial", 12, "bold"))
        canvas_label.pack(pady=(0, 5))

        self.canvas = tk.Canvas(left_frame, width=self.CANVAS_SIZE, height=self.CANVAS_SIZE, bg="black", cursor="cross", relief=tk.SUNKEN, bd=2)
        self.canvas.pack()
        
        self.canvas.bind("<B1-Motion>", self._paint)
        self.canvas.bind("<ButtonRelease-1>", self._reset_coords)

        # Right Frame: Controls
        right_frame = tk.Frame(self.root, bg="#2E3440", padx=15, pady=20)
        right_frame.pack(side=tk.RIGHT, fill=tk.BOTH, expand=True)

        # COM Port Dropdown
        tk.Label(right_frame, text="Select COM Port:", bg="#2E3440", fg="white", font=("Arial", 10)).pack(anchor="w")
        self.port_var = tk.StringVar()
        self.port_cb = ttk.Combobox(right_frame, textvariable=self.port_var, state="readonly")
        self.port_cb.pack(fill=tk.X, pady=(0, 10))
        self.port_cb.bind("<Button-1>", self._refresh_ports)
        self._refresh_ports(None)

        # Baud Rate Selectors
        tk.Label(right_frame, text="Baud Rate:", bg="#2E3440", fg="white", font=("Arial", 10)).pack(anchor="w")
        
        baud_subframe = tk.Frame(right_frame, bg="#2E3440")
        baud_subframe.pack(fill=tk.X, pady=(0, 15))

        self.baud_var = tk.StringVar(value="115200")
        self.baud_cb = ttk.Combobox(baud_subframe, textvariable=self.baud_var, values=["9600", "115200", "Custom"], state="readonly", width=8)
        self.baud_cb.pack(side=tk.LEFT, padx=(0, 5))
        self.baud_cb.bind("<<ComboboxSelected>>", self._on_baud_select)

        self.custom_baud_var = tk.StringVar()
        self.custom_baud_entry = tk.Entry(baud_subframe, textvariable=self.custom_baud_var, width=10, state=tk.DISABLED)
        self.custom_baud_entry.pack(side=tk.LEFT, fill=tk.X, expand=True)

        # Serial Buttons
        self.btn_start_serial = tk.Button(right_frame, text="START SERIAL", bg="#8FBCBB", fg="black", font=("Arial", 10, "bold"), command=self._start_serial)
        self.btn_start_serial.pack(fill=tk.X, pady=5)
        
        self.btn_stop_serial = tk.Button(right_frame, text="STOP SERIAL", bg="#BF616A", fg="white", font=("Arial", 10, "bold"), state=tk.DISABLED, command=self._stop_serial)
        self.btn_stop_serial.pack(fill=tk.X, pady=5)

        ttk.Separator(right_frame, orient=tk.HORIZONTAL).pack(fill=tk.X, pady=15)

        # Action Buttons
        self.btn_transmit = tk.Button(right_frame, text="TRANSMIT", bg="#A3BE8C", fg="black", font=("Arial", 12, "bold"), height=2, command=self._transmit_image)
        self.btn_transmit.pack(fill=tk.X, pady=5)

        self.btn_clear = tk.Button(right_frame, text="CLEAR CANVAS", bg="#4C566A", fg="white", font=("Arial", 10, "bold"), command=self._clear_canvas)
        self.btn_clear.pack(fill=tk.X, pady=5)

    def _paint(self, event):
        if self.old_x and self.old_y:
            self.canvas.create_line(self.old_x, self.old_y, event.x, event.y,
                                    width=self.PEN_WIDTH, fill="white", capstyle=tk.ROUND, smooth=tk.TRUE)
            self.draw.line([self.old_x, self.old_y, event.x, event.y],
                           fill=255, width=self.PEN_WIDTH, joint="curve")
        self.old_x = event.x
        self.old_y = event.y

    def _reset_coords(self, event):
        self.old_x, self.old_y = None, None

    def _clear_canvas(self):
        self.canvas.delete("all")
        self.draw.rectangle([0, 0, self.CANVAS_SIZE, self.CANVAS_SIZE], fill=0)

    def _refresh_ports(self, event):
        ports = serial.tools.list_ports.comports()
        available_ports = [port.device for port in ports]
        self.port_cb['values'] = available_ports
        if available_ports and not self.port_var.get():
            self.port_cb.current(0)

    def _on_baud_select(self, event):
        if self.baud_var.get() == "Custom":
            self.custom_baud_entry.config(state=tk.NORMAL)
        else:
            self.custom_baud_entry.config(state=tk.DISABLED)

    def _start_serial(self):
        port = self.port_var.get()
        if not port:
            messagebox.showwarning("Warning", "Please select a COM port.")
            return
        
        baud_selection = self.baud_var.get()
        if baud_selection == "Custom":
            try:
                target_baud = int(self.custom_baud_var.get())
            except ValueError:
                messagebox.showerror("Error", "Please enter a valid integer for the custom baud rate.")
                return
        else:
            target_baud = int(baud_selection)

        try:
            self.serial_conn = serial.Serial(port, baudrate=target_baud, timeout=1) 
            self.btn_start_serial.config(state=tk.DISABLED)
            self.btn_stop_serial.config(state=tk.NORMAL)
        except Exception as e:
            messagebox.showerror("Serial Error", f"Could not open {port}:\n{e}")

    def _stop_serial(self):
        if self.serial_conn and self.serial_conn.is_open:
            self.serial_conn.close()
        self.btn_start_serial.config(state=tk.NORMAL)
        self.btn_stop_serial.config(state=tk.DISABLED)

    def _transmit_image(self):
        # 1. Get raw pixel data
        resized_img = self.image.resize((self.MNIST_SIZE, self.MNIST_SIZE), Image.Resampling.LANCZOS)
        pixel_data_8bit = list(resized_img.getdata())
        
        # 2. Reformat to 2D array matching the quantization logic
        img_q_2d = []
        for r in range(self.MNIST_SIZE):
            row = []
            for c in range(self.MNIST_SIZE):
                pixel_val = pixel_data_8bit[r * self.MNIST_SIZE + c]
                float_val = pixel_val / 255.0  # Normalize to [0.0, 1.0]
                q_val = int(round(float_val * self.SCALE))
                q_val = max(-32768, min(32767, q_val)) # Clip to int16
                row.append(q_val)
            img_q_2d.append(row)

        # 3. Build UART stream exactly like build_uart_stream
        uart = bytearray()
        
        # Start magic
        uart.extend(bytes([0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF, 0x11, 0x22]))
        
        # Header (16-bit little-endian)
        H, W, C = self.MNIST_SIZE, self.MNIST_SIZE, 1
        uart.extend(struct.pack('<HHH', H, W, C))
        
        # Pixel data packing with hardware shift-register alignment
        words_per_row = (W + 7) // 8
        for row in range(H):
            for wd in range(words_per_row):
                for p in range(8):
                    col = wd * 8 + p
                    if col < W:
                        pix = img_q_2d[row][col] & 0xFFFF
                    else:
                        pix = 0
                    uart.append(pix & 0xFF)
                    uart.append((pix >> 8) & 0xFF)

        # End magic
        uart.extend(bytes([0x22, 0x11, 0xFF, 0xEE, 0xDD, 0xCC, 0xBB, 0xAA]))
        
        # 4. Save and Send (Now routing to the /debug directory)
        try:
            # Ensure the debug directory exists
            os.makedirs("debug", exist_ok=True)
            
            # Define the full path
            debug_filepath = os.path.join("debug", "debug_transmitted_image.hex")
            
            with open(debug_filepath, "w") as f:
                for b in uart:
                    f.write(f"{b:02X}\n")
            print(f"Wrote {len(uart)} bytes to {debug_filepath}")
        except Exception as e:
            print(f"File write error: {e}")

        if self.serial_conn and self.serial_conn.is_open:
            try:
                self.serial_conn.write(uart)
                print(f"Successfully transmitted {len(uart)} bytes over {self.serial_conn.port} at {self.serial_conn.baudrate} baud.")
            except Exception as e:
                messagebox.showerror("Serial Error", f"Transmission failed:\n{e}")
        else:
            messagebox.showinfo("Hardware Disconnected", f"Image saved to {debug_filepath}, but Serial is not connected.")

if __name__ == "__main__":
    root = tk.Tk()
    app = MNISTHardwareApp(root)
    root.mainloop()