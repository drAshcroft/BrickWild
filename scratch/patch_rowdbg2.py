import io

p = 'src/house/house_furnisher.gd'
lines = io.open(p, encoding='utf-8').read().split('\n')

i = next(k for k, l in enumerate(lines) if l == 'static var _mandatory := false')
lines[i + 1:i + 1] = ['static var _ROW_DEBUG := false']

i = next(k for k, l in enumerate(lines) if l.strip() == 'if try_row.size() == count:')
indent = lines[i][:len(lines[i]) - len(lines[i].lstrip('\t'))]
lines[i:i] = [
    indent + 'if _ROW_DEBUG:',
    indent + '\tprint("[row] wall %d count %d si %d: %d/%d fitted (slack %.2f, pitch %.2f)"'
           + ' % [wi, count, si, try_row.size(), count, slack, use_pitch])',
]

i = next(k for k, l in enumerate(lines) if l.strip() == 'if aisle_rect.size.x <= 0.0:')
indent = lines[i][:len(lines[i]) - len(lines[i].lstrip('\t'))]
lines[i:i] = [
    indent + 'if _ROW_DEBUG:',
    indent + '\tprint("[row] wall %d: row of %d, aisle %s" % [wi, row.size(), str(aisle_rect)])',
]

io.open(p, 'w', encoding='utf-8', newline='\n').write('\n'.join(lines))
print('written')
