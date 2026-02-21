#!/usr/bin/env python3
# JPG to BMP converter with GUI
# Requires: pip install pillow

import os
import sys
import tkinter as tk
from tkinter import ttk, filedialog, messagebox
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    import subprocess
    subprocess.run([sys.executable, '-m', 'pip', 'install', 'pillow'], check=True)
    from PIL import Image

# ==================== Цвета ====================
BG      = '#1e1e2e'
BG2     = '#181825'
BG3     = '#313244'
ACCENT  = '#89b4fa'
GREEN   = '#a6e3a1'
RED     = '#f38ba8'
YELLOW  = '#f9e2af'
TEXT    = '#cdd6f4'
SUBTEXT = '#6c7086'

class JPGtoBMP:
    def __init__(self, root):
        self.root = root
        self.root.title('JPG → BMP Converter')
        self.root.configure(bg=BG)
        self.root.resizable(False, False)
        self.files = []
        self._build_ui()

    def _build_ui(self):
        s = ttk.Style()
        s.theme_use('clam')
        s.configure('TFrame',      background=BG)
        s.configure('TLabel',      background=BG,  foreground=TEXT,    font=('Consolas', 10))
        s.configure('TButton',     background=BG3, foreground=TEXT,    font=('Consolas', 10), borderwidth=0, padding=6)
        s.map('TButton',           background=[('active', ACCENT)], foreground=[('active', BG)])
        s.configure('TEntry',      fieldbackground=BG3, foreground=TEXT, font=('Consolas', 10), borderwidth=0)
        s.configure('TSpinbox',    fieldbackground=BG3, foreground=TEXT, font=('Consolas', 10), borderwidth=0)
        s.configure('TCheckbutton',background=BG, foreground=TEXT, font=('Consolas', 10))
        s.map('TCheckbutton',      background=[('active', BG)])
        s.configure('TLabelframe', background=BG, foreground=ACCENT, font=('Consolas', 10, 'bold'))
        s.configure('TLabelframe.Label', background=BG, foreground=ACCENT)
        s.configure('Treeview',    background=BG3, foreground=TEXT, fieldbackground=BG3, font=('Consolas', 9))
        s.configure('Treeview.Heading', background=BG2, foreground=ACCENT, font=('Consolas', 9, 'bold'))
        s.map('Treeview',          background=[('selected', ACCENT)], foreground=[('selected', BG)])
        s.configure('Green.TButton', background=GREEN, foreground=BG, font=('Consolas', 11, 'bold'), padding=8)
        s.map('Green.TButton',     background=[('active', '#94e2d5')])
        s.configure('Red.TButton', background=RED, foreground=BG, font=('Consolas', 10))
        s.map('Red.TButton',       background=[('active', '#eba0ac')])

        # Заголовок
        hdr = tk.Frame(self.root, bg=BG2, pady=10)
        hdr.pack(fill='x')
        tk.Label(hdr, text='  JPG → BMP', bg=BG2, fg=ACCENT,
                 font=('Consolas', 18, 'bold')).pack(side='left')
        tk.Label(hdr, text='for AurumDOS  ', bg=BG2, fg=SUBTEXT,
                 font=('Consolas', 10)).pack(side='right', anchor='s', pady=6)

        main = ttk.Frame(self.root, padding=12)
        main.pack(fill='both')

        # ---- Файлы ----
        files_frame = ttk.LabelFrame(main, text=' Файлы ', padding=8)
        files_frame.pack(fill='both', pady=(0, 8))

        self.tree = ttk.Treeview(files_frame, columns=('file', 'size'), show='headings', height=6)
        self.tree.heading('file', text='Файл')
        self.tree.heading('size', text='Размер')
        self.tree.column('file', width=320)
        self.tree.column('size', width=100)
        self.tree.pack(fill='both')

        btns = ttk.Frame(files_frame)
        btns.pack(fill='x', pady=(6, 0))
        ttk.Button(btns, text='+ Добавить', command=self._add_files).pack(side='left', padx=2)
        ttk.Button(btns, text='✕ Удалить', style='Red.TButton',
                   command=self._remove_file).pack(side='left', padx=2)
        ttk.Button(btns, text='Очистить', command=self._clear_files).pack(side='right', padx=2)

        # ---- Настройки ----
        cfg_frame = ttk.LabelFrame(main, text=' Размер ', padding=8)
        cfg_frame.pack(fill='x', pady=(0, 8))

        # Пресеты
        presets_row = ttk.Frame(cfg_frame)
        presets_row.pack(fill='x', pady=(0, 8))
        ttk.Label(presets_row, text='Пресет:').pack(side='left', padx=(0, 8))
        presets = [
            ('32×32',   32,  32),
            ('64×64',   64,  64),
            ('100×100', 100, 100),
            ('160×100', 160, 100),
            ('320×200', 320, 200),
            ('Оригинал', 0, 0),
        ]
        for label, w, h in presets:
            ttk.Button(presets_row, text=label,
                       command=lambda w=w, h=h: self._set_preset(w, h)).pack(side='left', padx=2)

        # Ширина и высота
        size_row = ttk.Frame(cfg_frame)
        size_row.pack(fill='x')

        ttk.Label(size_row, text='Ширина:').pack(side='left', padx=(0, 4))
        self.width_var = tk.StringVar(value='320')
        ttk.Spinbox(size_row, from_=1, to=9999, textvariable=self.width_var,
                    width=6).pack(side='left', padx=(0, 16))

        ttk.Label(size_row, text='Высота:').pack(side='left', padx=(0, 4))
        self.height_var = tk.StringVar(value='200')
        ttk.Spinbox(size_row, from_=1, to=9999, textvariable=self.height_var,
                    width=6).pack(side='left', padx=(0, 16))

        self.keep_ratio = tk.BooleanVar(value=False)
        ttk.Checkbutton(size_row, text='Сохранять пропорции',
                        variable=self.keep_ratio).pack(side='left', padx=8)

        # ---- Папка вывода ----
        out_frame = ttk.LabelFrame(main, text=' Куда сохранять ', padding=8)
        out_frame.pack(fill='x', pady=(0, 8))

        out_row = ttk.Frame(out_frame)
        out_row.pack(fill='x')
        self.out_var = tk.StringVar(value=str(Path.home()))
        ttk.Entry(out_row, textvariable=self.out_var, width=42).pack(side='left', padx=(0, 4))
        ttk.Button(out_row, text='...', width=3,
                   command=self._browse_out).pack(side='left')

        self.same_dir = tk.BooleanVar(value=True)
        ttk.Checkbutton(out_frame, text='Сохранять рядом с оригиналом',
                        variable=self.same_dir,
                        command=self._toggle_same_dir).pack(anchor='w', pady=(4, 0))

        # ---- Кнопка ----
        ttk.Button(main, text='▶  Конвертировать', style='Green.TButton',
                   command=self._convert).pack(fill='x', pady=(0, 4))

        # ---- Лог ----
        self.log_var = tk.StringVar(value='Готов')
        tk.Label(self.root, textvariable=self.log_var,
                 bg=BG2, fg=SUBTEXT, font=('Consolas', 9),
                 anchor='w', padx=8, pady=4).pack(fill='x')

        self._toggle_same_dir()

    def _set_preset(self, w, h):
        if w == 0:
            self.width_var.set('0')
            self.height_var.set('0')
        else:
            self.width_var.set(str(w))
            self.height_var.set(str(h))

    def _toggle_same_dir(self):
        # disable/enable out entry
        pass

    def _add_files(self):
        paths = filedialog.askopenfilenames(
            title='Выбери JPG файлы',
            filetypes=[('JPEG', '*.jpg *.jpeg'), ('All', '*.*')]
        )
        for p in paths:
            if p not in self.files:
                self.files.append(p)
                size = os.path.getsize(p)
                self.tree.insert('', 'end', values=(os.path.basename(p), f'{size//1024} KB'))

    def _remove_file(self):
        sel = self.tree.selection()
        if not sel:
            return
        idx = self.tree.index(sel[0])
        self.tree.delete(sel[0])
        self.files.pop(idx)

    def _clear_files(self):
        self.tree.delete(*self.tree.get_children())
        self.files.clear()

    def _browse_out(self):
        path = filedialog.askdirectory()
        if path:
            self.out_var.set(path)

    def _convert(self):
        if not self.files:
            messagebox.showwarning('Нет файлов', 'Добавь хотя бы один JPG файл')
            return

        try:
            w = int(self.width_var.get())
            h = int(self.height_var.get())
        except ValueError:
            messagebox.showerror('Ошибка', 'Неверный размер')
            return

        done = 0
        errors = 0

        for path in self.files:
            try:
                img = Image.open(path).convert('RGB')

                if w > 0 and h > 0:
                    if self.keep_ratio.get():
                        img.thumbnail((w, h), Image.LANCZOS)
                    else:
                        img = img.resize((w, h), Image.LANCZOS)

                # Конвертируем в 256 цветов (8-bit) для AurumDOS
                img = img.quantize(colors=256)

                # Папка вывода
                if self.same_dir.get():
                    out_dir = os.path.dirname(path)
                else:
                    out_dir = self.out_var.get()

                base = os.path.splitext(os.path.basename(path))[0]
                out_path = os.path.join(out_dir, base + '.bmp')

                # Сохраняем как BMP
                img.save(out_path, 'BMP')
                done += 1
                self.log_var.set(f'Конвертирую: {os.path.basename(path)}...')
                self.root.update_idletasks()

            except Exception as e:
                errors += 1
                self.log_var.set(f'Ошибка: {e}')

        msg = f'Готово! {done} файлов конвертировано'
        if errors:
            msg += f', {errors} ошибок'
        self.log_var.set(msg)
        messagebox.showinfo('Готово', msg)

if __name__ == '__main__':
    root = tk.Tk()
    app = JPGtoBMP(root)
    root.mainloop()