
import os

path = 'c:/_GIT_2026/Hadar2026/REF_hadar/src/hadar/hd_base_config.cpp'
with open(path, 'r', encoding='cp949', errors='ignore') as f:
    lines = f.readlines()
    for i, line in enumerate(lines):
        if 'REGION_MAP_WINDOW' in line or 'REGION_CONSOLE_WINDOW' in line or 'REGION_STATUS_WINDOW' in line:
            print(f"{i+1}: {line.strip()}")
            # Print a few lines after to catch the initializer
            for j in range(1, 5):
                if i+j < len(lines):
                    print(f"    {lines[i+j].strip()}")
