path = 'c:/_GIT_2026/Hadar2026/REF_hadar/src/hadar/hd_class_map.h'
try:
    with open(path, 'r', encoding='cp949', errors='ignore') as f:
        content = f.read()
except:
    with open(path, 'r', encoding='utf-8', errors='ignore') as f:
        content = f.read()

start = content.find("enum HANDICAP")
if start != -1:
    end = content.find("}", start) + 10
    print(content[start:end])
else:
    print("Enum not found")
