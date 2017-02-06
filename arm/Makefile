pact.bin: pact.asm fasmarm
	./fasmarm pact.asm $@

fasmarm: fasm/source/linux/fasmarm.asm
	fasm fasm/source/linux/fasmarm.asm
	mv fasm/source/linux/fasmarm .
	chmod a+x fasmarm

clean:
	rm -f *.bin

realclean: clean
	rm -f fasmarm
