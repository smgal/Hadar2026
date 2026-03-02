import codecs

with codecs.open('c:/_GIT_2026/Hadar2026/REF_hadar/src/hadar/hd_class_window_map.h', 'r', 'latin-1') as f:
    text = f.read()

with codecs.open('c:/_GIT_2026/Hadar2026/map_h.txt', 'w', 'utf-8', errors='ignore') as f:
    f.write(text)
