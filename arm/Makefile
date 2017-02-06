pact.bin: pact.elf
	arm-none-eabi-objcopy -O binary $< $@

pact.elf: pact.asm fasmarm
	./fasmarm pact.asm $@

fasmarm: fasm/source/linux/fasmarm.asm
	fasm fasm/source/linux/fasmarm.asm
	mv fasm/source/linux/fasmarm .
	chmod a+x fasmarm

clean:
	rm -f *.elf *.bin

realclean: clean
	rm -f fasmarm
