"""Build glove80/homerow from glove80/bilateral-homerow.

Removes the bilateral layers and the Typing layer, and replaces the bilateral
home-row mods with one plain hold-tap (&HRM) that uses the kanata timings. Also
removes the behaviors that no key uses (AutoShift, Caps Word, mod-tab chord).
Writes the .json (Layout Editor) and the .keymap (ZMK). It does not build a .uf2.

    python3 scripts/archive/glove80-mk-homerow.py
"""
import glob, json, os, re, uuid

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
SRC = f'{ROOT}/glove80/bilateral-homerow'
DST = f'{ROOT}/glove80/homerow'
TITLE = 'TailorKey Zero v4.2c Homerow - Custom symbols v0.4'
BILATERAL = ['LeftIndex', 'LeftMiddy', 'LeftRingy', 'LeftPinky',
             'RightIndex', 'RightMiddy', 'RightRingy', 'RightPinky']
REMOVED = BILATERAL + ['Typing']
# No key uses these, not even in the bilateral layout.
UNUSED = ['AS_v1_TKZ', 'AS_HT_v2_TKZ', 'AS_Shifted_v1_TKZ', 'CAPSWord_v1_TKZ',
          'mod_tab_chord_v2_TKZ', 'mod_tab_v1_TKZ']
HRM = {'name': '&HRM', 'description': 'Home-row mod, same as the kanata tap-hold: tap for the key, hold for the modifier',
       'bindings': ['&kp', '&kp'], 'tappingTermMs': 200, 'flavor': 'tap-preferred', 'quickTapMs': 150}

os.makedirs(DST, exist_ok=True)

# ---- JSON ----
d = json.load(open(glob.glob(f'{SRC}/*.json')[0]))
old_names = d['layer_names']
keep = [i for i, n in enumerate(old_names) if n not in REMOVED]
remap = {old: new for new, old in enumerate(keep)}
typing = old_names.index('Typing')

LAYER_ARG = {'&mo', '&to', '&tog', '&sl', '&lt', '&thumb_v2_TKZ', '&space_v2_TKZ'}
def fix(b):
    ps = b.get('params', [])
    if b['value'] in LAYER_ARG and ps and isinstance(ps[0]['value'], int):
        # The Magic layer has a key that switches to Typing. It becomes &none.
        if b['value'] == '&to' and ps[0]['value'] == typing:
            b['value'], b['params'] = '&none', []
            return
        ps[0]['value'] = remap[ps[0]['value']]
    if str(b['value']).startswith('&HRM_'):
        b['value'] = '&HRM'
    for p in ps:
        fix(p)

d['layers'] = [d['layers'][i] for i in keep]
d['layer_names'] = [old_names[i] for i in keep]
for layer in d['layers']:
    for b in layer:
        fix(b)
for c in d['combos']:
    c['layers'] = [remap[x] for x in c['layers']]
for listener in d['inputListeners']:
    for node in listener['nodes']:
        node['layers'] = [remap[x] for x in node['layers']]
def drop(name):
    return name.startswith('&HRM_') or name[1:] in UNUSED
d['macros'] = [m for m in d['macros'] if not drop(m['name'])]
d['holdTaps'] = [h for h in d['holdTaps'] if not drop(h['name'])]
d['holdTaps'].insert([h['name'] for h in d['holdTaps']].index('&space_v2_TKZ'), HRM)
d['parent_uuid'] = d['uuid']
d['uuid'] = str(uuid.uuid4())
d['title'] = TITLE
d['notes'] = ('Homerow variant: the bilateral layers and the Typing layer are removed. The home-row mods use one '
              'plain hold-tap (&HRM), with the kanata timings: tap-time 150, hold-time 200. The unused AutoShift, '
              'Caps Word and mod-tab chord behaviors are removed.\n\n' + d['notes'])

# Nothing may still point at a removed layer or behavior.
blob = json.dumps(d)
assert '_v1B_TKZ' not in blob and 'HRM_left' not in blob and 'HRM_right' not in blob
assert not any(f'&{u}"' in blob for u in UNUSED)
json.dump(d, open(f'{DST}/{TITLE}.json', 'w'), indent=2, ensure_ascii=False)

# ---- keymap ----
k = open(glob.glob(f'{SRC}/*.keymap')[0]).read()

defines = ''.join(f'#define LAYER_{n} {i}\n' for i, n in enumerate(d['layer_names']))
k, n = re.subn(r'(#define LAYER_\w+ \d+\n)+', defines, k, count=1)
assert n == 1

# Remove the HRM and unused macros and hold-taps with their comment lines.
node = r'HRM_\w+|' + '|'.join(UNUSED)
k, n = re.subn(r'\n(\n        //[^\n]*)+\n        (%s): \2 \{.*?\n        \};' % node, '', k, flags=re.S)
assert n == 16 + 32 + len(UNUSED), n

hrm_node = '''
        // Home-row mod, same as the kanata tap-hold: tap for the key, hold for the modifier
        HRM: HRM {
            compatible = "zmk,behavior-hold-tap";
            #binding-cells = <2>;
            tapping-term-ms = <200>;
            bindings = <&kp>, <&kp>;
            flavor = "tap-preferred";
            quick-tap-ms = <150>;
        };
'''
k, n = re.subn(r'(\n        // space_layer_access)', hrm_node + r'\1', k, count=1)
assert n == 1

k, n = re.subn(r'\n\n        layer_(%s) \{.*?\n        \};' % '|'.join(REMOVED), '', k, flags=re.S)
assert n == len(REMOVED), n

# Keep the column width of the layer tables.
def pad(s):
    return lambda m: s(m).rjust(len(m.group(0)))
k, n = re.subn(r'(\s*)&HRM_\w+_v1B_TKZ (\w+ \w+)', pad(lambda m: '&HRM ' + m.group(2)), k)
assert n == 8, n
k, n = re.subn(r'(\s*)&to LAYER_Typing\b', pad(lambda m: '&none'), k)
assert n == 1, n

assert not re.search(r'\b(%s)\b' % '|'.join(UNUSED), k)
assert '_v1B_TKZ' not in k and not re.search(r'LAYER_(%s)\b' % '|'.join(REMOVED), k)
open(f'{DST}/{TITLE}.keymap', 'w').write(k)
print(d['layer_names'])
