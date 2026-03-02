import os

path = 'c:/_GIT_2026/Hadar2026/REF_hadar/src/hadar/hd_class_map.cpp'
try:
    with open(path, 'r', encoding='utf-8') as f:
        print(f.read())
except UnicodeDecodeError:
    try:
        with open(path, 'r', encoding='cp949') as f:
            print(f.read())
    except Exception as e:
        print(f"Error reading with cp949: {e}")
        try:
            with open(path, 'r', encoding='latin-1') as f:
                print(f.read())
        except Exception as e2:
             print(f"Error reading with latin-1: {e2}")
