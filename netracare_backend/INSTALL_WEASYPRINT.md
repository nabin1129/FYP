WeasyPrint installation instructions
=================================

This document describes how to install the system dependencies and Python package required to render HTML→PDF with WeasyPrint. We recommend installing inside your project's Python virtual environment.

Important: WeasyPrint depends on native libraries (Cairo, Pango, GDK-Pixbuf, libffi). On Windows it's simplest to use Conda or WSL2; on Linux use your distro package manager.

1) Verify Python environment
----------------------------
- Activate your virtualenv used by the project (example for Windows PowerShell):

  ```powershell
  & .\.venv\Scripts\Activate.ps1
  python -m pip install --upgrade pip setuptools wheel
  ```

2) Ubuntu / Debian (recommended)
--------------------------------
Run as a user with sudo:

```bash
sudo apt update
sudo apt install -y \
  libcairo2 libcairo2-dev \
  libpango-1.0-0 libpango1.0-dev \
  libgdk-pixbuf2.0-0 libgdk-pixbuf2.0-dev \
  libffi-dev shared-mime-info \
  fonts-dejavu-core

# then in your venv:
pip install WeasyPrint==58.0
```

Notes:
- `shared-mime-info` improves font detection and PDF metadata handling.
- If your distro names differ, search for `cairo`, `pango`, `gdk-pixbuf` and `libffi` packages.

3) Fedora / RHEL / CentOS
-------------------------
Use `dnf` or `yum`:

```bash
sudo dnf install -y cairo pango gdk-pixbuf2 libffi shared-mime-info dejavu-sans-fonts
pip install WeasyPrint==58.0
```

4) Windows options
-------------------
Native Windows install can be complex because WeasyPrint needs GTK libraries. Two practical options:

a) Use Conda (recommended on Windows):

```powershell
# create/activate conda env (if using Anaconda/Miniconda)
conda create -n netraweasy python=3.12 -y
conda activate netraweasy
conda install -c conda-forge weasyprint

# or install into your existing conda env; conda will provide the native deps
```

b) Use WSL2 (recommended if you already use WSL):

Install Ubuntu in WSL and follow the Ubuntu/Debian steps above. Then run your server from WSL or configure your app to call the service there.

c) Native MSYS2 (advanced):

Install MSYS2, then install the mingw packages for cairo/pango/gdk-pixbuf and ensure the mingw bin directory is on PATH. This approach is advanced and beyond the scope of this quick guide.

5) Install Python requirements
-----------------------------
From your activated virtualenv (or conda env):

```bash
pip install -r requirements.txt
# if you added WeasyPrint to requirements.txt, ensure you installed system deps first
```

6) Verify WeasyPrint is working
-------------------------------
Run a small check that writes a PDF:

```bash
python - <<'PY'
from weasyprint import HTML
HTML(string='<h1>WeasyPrint test</h1><p>If you see this in a PDF, installation succeeded.</p>').write_pdf('weasy_test.pdf')
print('Wrote weasy_test.pdf')
PY

# Or run the project's helper script (example):
python scripts/test_generate_pdf.py
```

7) Troubleshooting
------------------
- If `pip install WeasyPrint` fails with build errors, ensure the native libs are installed and `pkg-config` can find them (on Linux).  
- On Windows prefer Conda or WSL2 to avoid MSYS2 complexity.  
- If fonts render incorrectly, install `fonts-dejavu-core` or other appropriate fonts and re-run the PDF test.  

8) Runtime and deployment notes
-------------------------------
- In production, ensure the same native libraries and fonts exist on the server/container that will generate PDFs.  
- Docker: use a base image with the native libraries (e.g., `python:3.12-slim` + `apt install libcairo2 libpango-1.0-0 libgdk-pixbuf2.0-0 libffi-dev shared-mime-info fonts-dejavu-core`).  

If you want, I can produce a Dockerfile snippet or Conda environment YAML to automate this setup for your deployment target.
