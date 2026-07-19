# DevForge

Modular developer workstation bootstrap for Ubuntu-based Linux distributions.

## Current status

DevForge is under active development.

The initial foundation includes:

- Linux distribution detection
- Configuration loading
- Logging helpers
- Modular installer architecture
- Idempotent APT package installation
- Error handling

## Usage

```bash
git clone https://github.com/fvarli/devforge.git
cd devforge
cp config.env.example config.env
sudo ./install.sh

---

# 12. MIT lisansı

```bash
cat > LICENSE <<'EOF'
MIT License

Copyright (c) 2026 Ferzender Varli

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
