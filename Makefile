pact.bin: pact.elf
	arm-none-eabi-objcopy -S -O binary $< $@
	arm-none-eabi-size $<
	md5sum $@

pact.elf: pact.o
	arm-none-eabi-ld -Ttext 0x08000000 -o $@ $<

pact.o: pact.S bootstrap.S Makefile
	arm-none-eabi-as -g -mthumb -mcpu=cortex-m0 -o $@ $<

dump: pact.elf
	arm-none-eabi-objdump --demangle --disassemble $<

deploy: pact.bin
	# Assume you're using a STM32 board.
	st-flash write pact.bin 0x08000000

debug: deploy
	# Spawn a debug server in a separate window
	st-util & PID=$$!; arm-none-eabi-gdb -x gdbinit pact.elf; kill $$PID

bootstrap.S: bootstrap.pact transpiler.p6
	./transpiler.p6 < $< > $@ || ( rm -f $@; false )

test-transpiler: transpiler.p6
	prove -fe ./$< --test

clean:
	rm -f *.bin *.elf *.o bootstrap.S
