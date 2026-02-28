import sys

if len(sys.argv) < 2:
    print("Usage: python read_header.py <path>")
    sys.exit(1)

path = sys.argv[1]
encodings = ['utf-8', 'cp949', 'euc-kr', 'latin-1']
for enc in encodings:
    try:
        with open(path, 'r', encoding=enc) as f:
            print(f"--- Read with {enc} ---")
            print(f.read())
            sys.exit(0)
    except:
        continue
print("Failed to read file")
