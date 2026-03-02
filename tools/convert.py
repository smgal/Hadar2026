import codecs

with codecs.open('c:/_GIT_2026/Hadar2026/REF_hadar/src/hadar/hd_class_script.cpp', 'r', 'latin-1') as f:
    text = f.read()

with codecs.open('c:/_GIT_2026/Hadar2026/script_cpp2.txt', 'w', 'utf-8') as f:
    f.write(text)
