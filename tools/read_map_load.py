path = 'c:/_GIT_2026/Hadar2026/REF_hadar/src/hadar/hd_class_map.cpp'
encodings = ['cp949', 'euc-kr', 'latin-1', 'utf-8']
for enc in encodings:
    try:
        with open(path, 'r', encoding=enc) as f:
            content = f.read()
            if "Map::load" in content or "Map::_load" in content:
                print(f"--- Found in {enc} ---")
                start = content.find("Map::_load")
                if start == -1: start = content.find("Map::load")
                
                # Print reasonable chunk
                end = content.find("}", start + 300) + 10
                print(content[start:end])
                break
    except:
        continue
