import sys
import os

def read_file(path):
    encodings = ['utf-8', 'cp949', 'euc-kr', 'latin-1', 'utf-16']
    for enc in encodings:
        try:
            with open(path, 'r', encoding=enc) as f:
                content = f.read()
                print(f"--- Read with {enc} ---")
                print(content[:5000]) # First 5000 chars
                return
        except Exception:
            pass
    print("Failed to read file with known encodings.")

if __name__ == "__main__":
    if len(sys.argv) > 1:
        read_file(sys.argv[1])
    else:
        print("Usage: python robust_read.py <file_path>")
