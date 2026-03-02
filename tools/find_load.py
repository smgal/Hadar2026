import re

path = 'c:/_GIT_2026/Hadar2026/REF_hadar/src/hadar/hd_class_map.cpp'
try:
    with open(path, 'r', encoding='cp949', errors='ignore') as f:
        lines = f.readlines()
except:
    with open(path, 'r', encoding='utf-8', errors='ignore') as f:
        lines = f.readlines()

printing = False
brace_count = 0
found = False

for line in lines:
    if "bool hadar::Map::_load" in line:
        printing = True
        found = True
    
    if printing:
        print(line.rstrip())
        brace_count += line.count('{')
        brace_count -= line.count('}')
        if brace_count == 0 and found and "}" in line:
            break
