path = 'c:/_GIT_2026/Hadar2026/REF_hadar/src/hadar/hd_class_map.h'
try:
    with open(path, 'r', encoding='cp949', errors='ignore') as f:
        lines = f.readlines()
except:
     with open(path, 'r', encoding='utf-8', errors='ignore') as f:
        lines = f.readlines()

for line in lines:
    if "save" in line or "data" in line or "SmSet" in line or "jumpable" in line:
        print(line.rstrip())
