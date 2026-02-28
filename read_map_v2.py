import sys

def read_file(path):
    encodings = ['utf-8', 'cp949', 'euc-kr', 'latin-1']
    for enc in encodings:
        try:
            with open(path, 'r', encoding=enc) as f:
                content = f.read()
                print(f"--- Successfully read with {enc} ---")
                print(content)
                return
        except UnicodeDecodeError:
            continue
        except Exception as e:
            print(f"Error reading with {enc}: {e}")
            continue
    print("Failed to read file with tested encodings.")

if __name__ == "__main__":
    read_file('c:/_GIT_2026/Hadar2026/REF_hadar/src/hadar/hd_class_map.cpp')
