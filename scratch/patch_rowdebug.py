import io

p = 'src/house/house_furnisher.gd'
lines = io.open(p, encoding='utf-8').read().split('\n')

# 1. the flag
i = next(k for k, l in enumerate(lines) if l == 'static var _mandatory := false')
lines[i + 1:i + 1] = [
    '## Temporary trace: why would a row not go in. Set by a probe, never a suite.',
    'static var _ROW_DEBUG := false',
]

# 2. report the count attempt
i = next(k for k, l in enumerate(lines) if l.strip() == 'if try_row.size() == count:')
assert lines[i + 1].strip() == 'row = try_row' and lines[i + 2].strip() == 'break', lines[i:i+3]
lines[i + 3:i + 3] = [
    '\t\t\t\tif _ROW_DEBUG and si == 0:',
    '\t\t\t\t\tprint("[row]   wall %d count %d: %d of %d fitted, slack %.2f"',
    '\t\t\t\t\t\t% [wi, count, try_row.size(), count, slack])',
]

# 3. report a row that placed but found no aisle
i = next(k for k, l in enumerate(lines) if l.strip() == 'if aisle_rect.size.x <= 0.0:')
assert lines[i + 1].strip() == 'continue', lines[i + 1]
lines[i + 1:i + 1] = [
    '\t\t\t\tif _ROW_DEBUG:',
    '\t\t\t\t\tprint("[row]   wall %d: row of %d placed, no aisle fits"',
    '\t\t\t\t\t\t% [wi, row.size()])',
]

# 4. report the bailout
i = next(k for k, l in enumerate(lines) if l.strip() == 'if best_row.size() < min_n:')
lines[i + 1:i + 1] = [
    '\t\tif _ROW_DEBUG:',
    '\t\t\tprint("[row] %s room %d: nothing placed over %d lines, min_n %d"',
    '\t\t\t\t% [cat, room, lines_count_dbg, min_n])',
]

src = '\n'.join(lines)
src = src.replace('\t\t\t\t% [cat, room, lines_count_dbg, min_n])',
                  '\t\t\t\t% [cat, room, lines.size(), min_n])')
io.open(p, 'w', encoding='utf-8', newline='\n').write(src)
print('written')
