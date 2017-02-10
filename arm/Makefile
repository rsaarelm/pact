TERMINAL=urxvt

# TODO

pact.bin: pact.elf
	arm-none-eabi-objcopy -S -O binary $< $@
	arm-none-eabi-size $<

pact.elf: pact.o
	arm-none-eabi-ld -Ttext 0x08000000 -o $@ $<

%.o: %.S
	arm-none-eabi-as -mthumb -mcpu=cortex-m0 -o $@ $<

debug: pact.bin
	# Assume you're using a STM32 board.
	st-flash write pact.bin 0x08000000
	sleep 1
	# Spawn a debug server in a separate window
	$(TERMINAL) -e st-util &
	arm-none-eabi-gdb -ex "tar extended-remote :4242" -ex "set arm force-mode thumb"
	killall st-util

clean:
	rm -f *.bin *.elf *.o
