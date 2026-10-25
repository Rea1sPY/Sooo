"""بررسی ایستای GDScript (بدون Godot): تورفتگی، بریس‌ها، ارجاع بین اسکریپت‌ها، مسیرهای preload، توابع صدا زده‌شده.
این ابزار جایگزین اجرای واقعی در Godot نیست؛ فقط خطاهای ساده و رایج را پیدا می‌کند.   python3 tools/gd_lint.py"""
import os, re, sys, glob
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
S = os.path.join(ROOT, 'scripts')
files = {os.path.basename(f): f for f in glob.glob(S + '/*.gd')}
src = {n: open(f, encoding='utf-8').read() for n, f in files.items()}
bad = 0; total = 0
def chk(name, cond, extra=''):
    global bad, total; total += 1
    if not cond: bad += 1; print('  ✗ ' + name + ((' — ' + str(extra)) if extra != '' else ''))

def strip_strings(line):
    out = ''; q = None; i = 0
    while i < len(line):
        ch = line[i]
        if q:
            if ch == '\\': i += 2; continue
            if ch == q: q = None
        else:
            if ch in '"\'': q = ch
            elif ch == '#': break
            else: out += ch
        i += 1
    return out

for name, text in src.items():
    lines = text.split('\n')
    in_multi = False
    depth = {'(': 0, '[': 0, '{': 0}
    pair = {')': '(', ']': '[', '}': '{'}
    funcs = set(re.findall(r'^\s*(?:static\s+)?func\s+(\w+)', text, re.M))
    for i, raw in enumerate(lines, 1):
        if name != 'data.gd' or True:
            if raw.startswith(' ') and raw.strip():
                chk(f'{name}:{i} تورفتگی با فاصله (باید tab باشد)', False, raw[:30])
            if re.match(r'^\t* +\t', raw): chk(f'{name}:{i} ترکیب tab و فاصله', False)
        code = strip_strings(raw)
        # بریس‌ها
        for ch in code:
            if ch in depth: depth[ch] += 1
            elif ch in pair: depth[pair[ch]] -= 1
        # سرتیتر بلوک باید با : تمام شود (خارج از پرانتز باز)
        st = code.strip()
        if sum(depth.values()) == 0 and re.match(r'^(if|elif|else|for|while|func|static func|class)\b', st):
            if not st.endswith(':') and not re.search(r':\s*\S', st):
                chk(f'{name}:{i} سرتیتر بلوک بدون ":"', False, st[:50])
        if re.search(r'(^|\s):=(\s|$)', code) and 'var ' in code:
            pass
    chk(f'{name}: بریس‌ها متوازن', all(v == 0 for v in depth.values()), depth)
    # preload
    for m in re.findall(r'preload\("(res://[^"]+)"\)', text):
        chk(f'{name}: مسیر preload موجود است {m}', os.path.exists(os.path.join(ROOT, m.replace('res://', ''))))
    # شناسه‌های ممنوع
    chk(f'{name}: بدون class_name (کش کلاس سراسری لازم نشود)', 'class_name ' not in text)
    chk(f'{name}: بدون `:=` (استنتاج نوع)', not re.search(r'\bvar\s+\w+\s*:=', text))
    chk(f'{name}: بدون yield قدیمی', 'yield(' not in text)
    for m in re.finditer(r'\bonready var\b|@export|@onready', text): pass

# ----- ارجاع بین اسکریپت‌ها -----
def funcs_of(n): return set(re.findall(r'^\s*(?:static\s+)?func\s+(\w+)', src[n], re.M))
def vars_of(n): return set(re.findall(r'^(?:var|const|signal)\s+(\w+)', src[n], re.M)) | set(re.findall(r'^enum\s*\{([^}]*)\}', src[n], re.M) and re.findall(r'(\w+)', ' '.join(re.findall(r'^enum\s*\{([^}]*)\}', src[n], re.M))))
autoload = {'Global': 'global.gd', 'Sound': 'audio.gd'}
for name, text in src.items():
    for alias, target in autoload.items():
        if name == target: continue
        for m in re.finditer(r'\b' + alias + r'\.(\w+)(\()?', text):
            member, call = m.group(1), m.group(2)
            ok = member in funcs_of(target) or member in vars_of(target)
            chk(f'{name}: {alias}.{member} در {target} تعریف شده است', ok)
# مثل UI.label / Panels.settings / Popups.keypad ... (ثابت‌های preload)
const_map = {}
for name, text in src.items():
    for m in re.finditer(r'^const (\w+) = preload\("res://scripts/(\w+\.gd)"\)', text, re.M):
        const_map.setdefault(name, {})[m.group(1)] = m.group(2)
for name, mp in const_map.items():
    for alias, target in mp.items():
        for m in re.finditer(r'\b' + alias + r'\.(\w+)', src[name]):
            member = m.group(1)
            if member == 'new': continue
            chk(f'{name}: {alias}.{member} در {target} تعریف شده است', member in funcs_of(target) or member in vars_of(target), '')
# متدهای صدا زده‌شده روی game / player / enemy / hud / level / touch / fx
objs = {'player': 'player.gd', 'enemy': 'enemy.gd', 'hud': 'hud.gd', 'level': 'level.gd', 'touch': 'touch_controls.gd', 'fx': 'fx.gd', 'game': 'game.gd'}
for name, text in src.items():
    for var, target in objs.items():
        if name == target: continue
        for m in re.finditer(r'\b' + var + r'\.(\w+)\(', text):
            chk(f'{name}: {var}.{m.group(1)}() در {target} تعریف شده است', m.group(1) in funcs_of(target) or m.group(1) in {'add_child', 'queue_free', 'connect', 'emit'})
# اتصال سیگنال‌ها به توابع موجود
for name, text in src.items():
    for m in re.finditer(r'\.connect\((\w+)\)', text):
        f = m.group(1)
        if f in ('Global',): continue
        chk(f'{name}: تابع متصل‌شده {f} موجود است', f in funcs_of(name) or f in {'ui_click', 'open_support'} or f in funcs_of('global.gd') or re.search(r'\bvar\s+' + f + r'\b', text) or re.search(r'func[^\n]*\b' + f + r'\b', text))
# بازتعریف تابع تکراری
for name, text in src.items():
    fs = re.findall(r'^\s*(?:static\s+)?func\s+(\w+)', text, re.M)
    d = {f for f in fs if fs.count(f) > 1}
    chk(f'{name}: تابع تکراری ندارد', not d, d)
# project.godot
pg = open(os.path.join(ROOT, 'project.godot'), encoding='utf-8').read()
for m in re.findall(r'"\*?res://([^"]+)"', pg): chk(f'project.godot: فایل {m} موجود است', os.path.exists(os.path.join(ROOT, m)))
chk('project.godot: ETC2/ASTC برای اندروید فعال است', 'import_etc2_astc=true' in pg)
chk('project.godot: رندر gl_compatibility', 'gl_compatibility' in pg)
chk('project.godot: افقی (orientation=0)', 'handheld/orientation=0' in pg)
ep = open(os.path.join(ROOT, 'export_presets.cfg'), encoding='utf-8').read()
chk('export_presets: پیش‌تنظیم Android و arm64', 'platform="Android"' in ep and 'arm64-v8a=true' in ep)
chk('export_presets: بدون gradle (قالب آماده)', 'use_gradle_build=false' in ep)
chk('export_presets: مجوز اینترنت خاموش است (آفلاین)', 'permissions/internet=false' in ep)
chk('کد اسکریپت‌ها هیچ کلاس شبکه‌ای ندارد (آفلاین)', not any(re.search(r'HTTPRequest|WebSocket|HTTPClient|StreamPeerTCP|ENetMultiplayer', t) for t in src.values()))
print(f'\nنتیجه: {total - bad} از {total} بررسی موفق، مشکل: {bad}'); sys.exit(1 if bad else 0)
