
%.o: src/%.s
	ca65 --create-dep "$@.dep" --debug-info $< -o $@

main.nes: layout entry.o
	ld65 --mapfile "$@.map" --dbgfile "main.dbg" -C layout entry.o -o $@

clean:
	rm -f main.nes *.dep *.o *.dbg *.map

integritycheck: main.nes
	radiff2 original.nes main.nes | head -n 100

include $(wildcard *.dep)
