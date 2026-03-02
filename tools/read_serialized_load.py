path = 'c:/_GIT_2026/Hadar2026/REF_hadar/src/hadar/hd_class_serialized.cpp'
encodings = ['cp949', 'euc-kr', 'latin-1', 'utf-8']
for enc in encodings:
    try:
        with open(path, 'r', encoding=enc) as f:
            content = f.read()
            if "Serialized::load" in content:
                print(f"--- Found in {enc} ---")
                start = content.find("Serialized::load")
                end = content.find("}", start + 300) + 10
                print(content[start:end])
                break
    except:
        continue
