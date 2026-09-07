import io

p = 'src/castle/castle_generator.gd'
lines = io.open(p, encoding='utf-8').read().split('\n')

# the size guard: splice a maximum in after the existing minimum
gi = next(i for i, l in enumerate(lines) if 'MIN_KEEP_AREA:' in l)
assert lines[gi + 1].strip() == 'return plan', lines[gi + 1]
lines[gi + 2:gi + 2] = [
    '\tif maxf(floor_rect.size.x, floor_rect.size.y) > MAX_KEEP_SIDE:',
    '\t\treturn plan',
]

ci = next(i for i, l in enumerate(lines) if l.startswith('const MIN_KEEP_AREA'))
lines[ci + 1:ci + 1] = [
    '## And the most. The biggest keep ever built is the White Tower at',
    '## 36 x 32 m; a fortress in this generator throws up a "keep" mass sixty',
    '## metres across with four thousand square metres to a floor, which is a',
    '## block the massing happens to draw as one volume rather than a tower',
    '## anybody lives up. It keeps its mass; what it does not get is an inside.',
    'const MAX_KEEP_SIDE := 36.0',
]

io.open(p, 'w', encoding='utf-8', newline='\n').write('\n'.join(lines))
print('written')
