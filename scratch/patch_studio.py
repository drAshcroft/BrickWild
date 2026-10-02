import io
p = 'src/ui/studio.gd'
s = io.open(p, encoding='utf-8').read()

# every family-table label lookup goes through the public option contract
subs = [
 ('HotelSpec.HOTEL_STYLES[(plan.spec as HotelSpec).style]["label"]',
  'BrickWild.option_label(&"hotel", &"style", (plan.spec as HotelSpec).style)'),
 ('ShopSpec.BUSINESSES[(plan.spec as ShopSpec).business]["label"]',
  'BrickWild.option_label(&"shop", &"purpose", (plan.spec as ShopSpec).business)'),
 ('HouseSpec.TRADES[plan.spec.trade]["label"]',
  'BrickWild.option_label(&"house", &"purpose", plan.spec.trade)'),
 ('TempleSpec.FORMS[s.form]["label"]',
  'BrickWild.option_label(&"temple", &"style", s.form)'),
 ('TempleSpec.CULTS[s.cult]["label"]',
  'BrickWild.option_label(&"temple", &"purpose", s.cult)'),
 ('HotelSpec.HOTEL_STYLES[s.style]["label"]',
  'BrickWild.option_label(&"hotel", &"style", s.style)'),
 ('ShopSpec.BUSINESSES[s.business]["label"]',
  'BrickWild.option_label(&"shop", &"purpose", s.business)'),
 ('HouseSpec.TRADES[s.trade]["label"]',
  'BrickWild.option_label(&"house", &"purpose", s.trade)'),
 ('CastleSpec.STYLES[s.style]["label"]',
  'BrickWild.option_label(&"castle", &"style", s.style)'),
 ('ChurchSpec.STYLES[s.style]["label"]',
  'BrickWild.option_label(&"church", &"style", s.style)'),
]
for old, new in subs:
    n = s.count(old)
    assert n >= 1, old
    s = s.replace(old, new)

# the shop line names the shell style too, and a shop's styles are the house's
old = 'HouseSpec.STYLES[s.style]["label"],\n\t\t\tBrickWild.option_label(&"shop", &"purpose", s.business)'
new = 'BrickWild.option_label(&"shop", &"style", s.style),\n\t\t\tBrickWild.option_label(&"shop", &"purpose", s.business)'
assert s.count(old) == 1
s = s.replace(old, new)
old = 'HouseSpec.STYLES[s.style]["label"],\n\t\t\tBrickWild.option_label(&"house", &"purpose", s.trade)'
new = 'BrickWild.option_label(&"house", &"style", s.style),\n\t\t\tBrickWild.option_label(&"house", &"purpose", s.trade)'
assert s.count(old) == 1
s = s.replace(old, new)
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('ok')
