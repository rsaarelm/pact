all: pact vm-example

pact: pact.asm
	fasm pact.asm

vm-example: vm-example.cpp
	g++ --std=c++11 vm-example.cpp -o vm-example

clean:
	rm -f pact vm-example image.bin
