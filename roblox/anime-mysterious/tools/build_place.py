"""Package the source as a Roblox XML place; no external dependencies required."""
from pathlib import Path
import xml.etree.ElementTree as ET
from zipfile import ZipFile, ZIP_DEFLATED

ROOT = Path(__file__).resolve().parents[1]
roblox = ET.Element('roblox', {'version': '4'})
ET.SubElement(roblox, 'External').text = 'null'
ET.SubElement(roblox, 'External').text = 'nil'
serial = 0

def item(parent, class_name, name):
    global serial
    serial += 1
    node = ET.SubElement(parent, 'Item', {'class': class_name, 'referent': f'RBX{serial}'})
    props = ET.SubElement(node, 'Properties')
    ET.SubElement(props, 'string', {'name': 'Name'}).text = name
    return node, props

def script(parent, class_name, name, source):
    node, props = item(parent, class_name, name)
    ET.SubElement(props, 'ProtectedString', {'name': 'Source'}).text = (ROOT / 'src' / source).read_text()
    return node

workspace, props = item(roblox, 'Workspace', 'Workspace')
ET.SubElement(props, 'bool', {'name': 'FilteringEnabled'}).text = 'true'
replicated, _ = item(roblox, 'ReplicatedStorage', 'ReplicatedStorage')
script(replicated, 'ModuleScript', 'Config', 'Config.lua')
server, _ = item(roblox, 'ServerScriptService', 'ServerScriptService')
script(server, 'Script', 'GameServer', 'Server.server.lua')
player, props = item(roblox, 'StarterPlayer', 'StarterPlayer')
ET.SubElement(props, 'float', {'name': 'CharacterWalkSpeed'}).text = '0'
ET.SubElement(props, 'float', {'name': 'CharacterJumpPower'}).text = '0'
client, _ = item(player, 'StarterPlayerScripts', 'StarterPlayerScripts')
script(client, 'LocalScript', 'GameClient', 'Client.client.lua')
item(roblox, 'Lighting', 'Lighting')
output = ROOT / 'AnimeMysterious.rbxlx'
ET.indent(roblox)
ET.ElementTree(roblox).write(output, encoding='utf-8', xml_declaration=True)
# Verify source round-trips exactly and scripts have the intended service ancestry.
parsed = ET.parse(output)
sources = parsed.findall('.//ProtectedString')
assert len(sources) == 3
for node, source in zip(sources, ['Config.lua', 'Server.server.lua', 'Client.client.lua']):
    assert node.text == (ROOT / 'src' / source).read_text()
assert parsed.find(".//Item[@class='StarterPlayerScripts']/Item[@class='LocalScript']") is not None
assert parsed.find(".//Item[@class='ServerScriptService']/Item[@class='Script']") is not None
print(f'Built and XML/source-checked: {output} ({output.stat().st_size:,} bytes)')

# Keep the downloadable ZIP synchronized with the shipped source and place.
archive = ROOT.parent / 'AnimeMysterious.zip'
files = [p for p in sorted(ROOT.rglob('*')) if p.is_file() and '__pycache__' not in p.parts]
with ZipFile(archive, 'w', ZIP_DEFLATED) as zipped:
    for source in files:
        zipped.write(source, Path(ROOT.name) / source.relative_to(ROOT))
with ZipFile(archive) as zipped:
    assert zipped.testzip() is None
    for source in files:
        key = (Path(ROOT.name) / source.relative_to(ROOT)).as_posix()
        assert zipped.read(key) == source.read_bytes(), key
print(f'Archive contents verified: {archive} ({len(files)} files)')
