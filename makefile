
lsha1.so: lsha1.c
	clang -g -Wall -undefined dynamic_lookup -o $@ $^