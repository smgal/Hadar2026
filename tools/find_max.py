path = 'c:/_GIT_2026/Hadar2026/REF_hadar/src/hadar/hd_class_map.h'
try:
    with open(path, 'r', encoding='cp949', errors='ignore') as f:
        for line in f:
            if "HANDICAP_MAX" in line:
                print(line.rstrip())
except:
    pass
