
%.o: src/%.s
	ca65 --create-dep "$@.dep" --debug-info $< -o $@

main.nes: layout entry.o
	ld65 --mapfile "$@.map" --dbgfile "main.dbg" -C layout entry.o -o $@

practiserom.zip: patch.ips
	zip practiserom.zip patch.ips README.md

patch.ips: main.nes
	python3 scripts/ips.py create --output patch.ips "original.nes" main.nes

clean:
	rm -f main.nes *.dep *.o *.dbg *.map

integritycheck: main.nes
	radiff2 original.nes main.nes | head -n 100

include $(wildcard *.dep)
