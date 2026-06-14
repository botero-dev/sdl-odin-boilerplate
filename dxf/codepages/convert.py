from __future__ import annotations

import re
from pathlib import Path
import sys


def parse_codepage_file(path: Path) -> list[tuple[int, int | None]]:
	entries: dict[int, int | None] = {}

	for raw_line in path.read_text(encoding="utf-8-sig").splitlines():
		line = raw_line.strip()
		if not line or line.startswith("#"):
			continue

		parts = raw_line.split("\t")
		if len(parts) < 2:
			continue

		codepoint_text = parts[0].strip()
		unicode_text = parts[1].strip()

		if not codepoint_text:
			continue

		codepoint = int(codepoint_text, 16)
		value: int | None
		if unicode_text:
			value = int(unicode_text, 16)
		else:
			value = None

		if codepoint in entries:
			raise ValueError(f"duplicate codepoint {codepoint_text} in {path.name}")

		entries[codepoint] = value

	if not entries:
		return []

	max_codepoint = max(entries)
	table_size = 65536 if max_codepoint > 0xFF else 256

	table: list[tuple[int, int | None]] = []
	for codepoint in range(table_size):
		table.append((codepoint, entries.get(codepoint)))

	return table


def generate_odin_table(path: Path) -> str:
	table = parse_codepage_file(path)
	if not table:
		raise ValueError(f"{path.name} does not contain any mapping rows")

	name = path.stem.lower()
	lines = [
        "package codepages",
        "",
        "%s := [?]u16{" % name,
    ]

	values = ["0x0000" if value is None else f"0x{value:04X}" for _, value in table]
	for index in range(0, len(values), 16):
		chunk = values[index:index + 16]
		lines.append("    " + ", ".join(chunk) + ",")

	lines.append("}")
	return "\n".join(lines)


def main():
	current_dir = Path.cwd()
	pattern = re.compile(r"^CP\d{3,4}\.txt$", re.IGNORECASE)

	input_files = sorted(
		path for path in current_dir.iterdir()
		if path.is_file() and pattern.match(path.name)
	)

	if not input_files:
		print("no CP###.txt or CP####.txt files found in the current directory", file=sys.stderr)
		return 1

	for input_file in input_files:
		output_file = input_file.with_name(input_file.stem.lower() + ".odin")
		output_file.write_text(generate_odin_table(input_file) + "\n", encoding="utf-8")

if __name__ == "__main__":
	main()
