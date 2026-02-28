path = 'c:/_GIT_2026/Hadar2026/REF_hadar/src/hadar/hd_base_extern.cpp'
encodings = ['utf-8', 'cp949', 'euc-kr', 'latin-1']
for enc in encodings:
    try:
        with open(path, 'r', encoding=enc) as f:
            content = f.read()
            if "CFileReadStream::Read" in content:
                print(f"--- Found in {enc} ---")
                start = content.find("CFileReadStream::Read")
                end = content.find("}", start) + 10
                print(content[start:end])
                # Also print constructor
                start_ctor = content.find("CFileReadStream::CFileReadStream")
                if start_ctor != -1:
                    end_ctor = content.find("}", start_ctor) + 10
                    print(content[start_ctor:end_ctor])
                break
    except:
        continue
