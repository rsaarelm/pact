TERMINAL=urxvt

pact.bin: pact.asm fasmarm
	./fasmarm pact.asm $@

fasmarm: fasm/source/linux/fasmarm.asm
	fasm fasm/source/linux/fasmarm.asm
	mv fasm/source/linux/fasmarm .
	chmod a+x fasmarm

debug:
	# Assume you're using a STM32 board.
	#st-flash write pact.bin 0x08000000
	# Spawn a debug server in a separate window
	$(TERMINAL) -e st-util &
	arm-none-eabi-gdb -ex "tar extended-remote :4242"

clean:
	rm -f *.bin

realclean: clean
	rm -f fasmarm
