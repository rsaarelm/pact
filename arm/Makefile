pact.bin: pact.s
	# XXX: This is wrong, figure it out.
	arm-none-eabi-as pact.s -o pact.bin

fasmarm: fasm/source/linux/fasmarm.asm
	fasm fasm/source/linux/fasmarm.asm
	mv fasm/source/linux/fasmarm .
	chmod a+x fasmarm
