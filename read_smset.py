path = 'c:/_GIT_2026/Hadar2026/REF_hadar/src/hadar/util/USmSet.h'
# path might be different, let me check dir list again if needed.
# list_dir said util is inside hadar.
try:
    with open(path, 'r', encoding='latin-1') as f:
        print(f.read())
except FileNotFoundError:
    print("File not found, checking local dir")
    # try recursively finding USmSet.h
    import glob
    files = glob.glob('c:/_GIT_2026/Hadar2026/**/USmSet.h', recursive=True)
    if files:
        with open(files[0], 'r', encoding='latin-1') as f:
            print(f.read())
