#!/usr/bin/env python3
"""
Regenerate test fixtures with valid draw.io compression.

Draw.io compression format: URL encode -> raw deflate -> Base64
"""

import base64
import zlib
import html
import os
from urllib.parse import quote

def compress_diagram(xml: str) -> str:
    """Compress XML using draw.io format: URL encode -> raw deflate -> base64."""
    url_encoded = quote(xml, safe='')
    # Raw deflate (strip zlib header [2 bytes] and trailer [4 bytes])
    deflated = zlib.compress(url_encoded.encode('utf-8'), level=9)[2:-4]
    return base64.b64encode(deflated).decode('ascii')

def create_drawio_svg(diagram_xml: str, name: str, diagram_id: str,
                      width: int, height: int, svg_body: str) -> str:
    """Create a complete .drawio.svg file with properly compressed content."""
    compressed = compress_diagram(diagram_xml)

    mxfile = f'<mxfile host="Electron" agent="test-fixture" version="1.0"><diagram name="{name}" id="{diagram_id}">{compressed}</diagram></mxfile>'
    content_attr = html.escape(mxfile)

    return f'''<?xml version="1.0" encoding="UTF-8"?>
<!-- Test fixture - regenerated with valid compression -->
<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" version="1.1" width="{width}px" height="{height}px" viewBox="0 0 {width} {height}" content="{content_attr}">
  <defs/>
  <g>
{svg_body}
  </g>
</svg>
'''

# Define fixtures
fixtures = {
    'simple-rect.drawio.svg': {
        'name': 'Simple Rectangle',
        'id': 'simple-rect',
        'width': 102,
        'height': 52,
        'diagram_xml': '''<mxGraphModel dx="0" dy="0" grid="1" gridSize="10" guides="1" tooltips="1" connect="1" arrows="1" fold="1" page="1" pageScale="1" pageWidth="850" pageHeight="1100">
  <root>
    <mxCell id="0"/>
    <mxCell id="1" parent="0"/>
    <mxCell id="2" value="" style="rounded=0;whiteSpace=wrap;html=1;fillColor=#ffffff;strokeColor=#000000;" parent="1" vertex="1">
      <mxGeometry width="100" height="50" as="geometry"/>
    </mxCell>
  </root>
</mxGraphModel>''',
        'svg_body': '    <rect x="0" y="0" width="100" height="50" fill="#ffffff" stroke="#000000" pointer-events="all"/>'
    },

    'with-text.drawio.svg': {
        'name': 'With Text',
        'id': 'with-text',
        'width': 102,
        'height': 52,
        'diagram_xml': '''<mxGraphModel dx="0" dy="0" grid="1" gridSize="10" guides="1" tooltips="1" connect="1" arrows="1" fold="1" page="1" pageScale="1" pageWidth="850" pageHeight="1100">
  <root>
    <mxCell id="0"/>
    <mxCell id="1" parent="0"/>
    <mxCell id="2" value="Hello World" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#ffffff;strokeColor=#000000;" parent="1" vertex="1">
      <mxGeometry width="100" height="50" as="geometry"/>
    </mxCell>
  </root>
</mxGraphModel>''',
        'svg_body': '''    <rect x="0" y="0" width="100" height="50" rx="7.5" ry="7.5" fill="#ffffff" stroke="#000000" pointer-events="all"/>
    <g><text x="50" y="30" text-anchor="middle" font-family="Helvetica" font-size="12px">Hello World</text></g>'''
    },

    'two-boxes-arrow.drawio.svg': {
        'name': 'Two Boxes Arrow',
        'id': 'two-boxes',
        'width': 262,
        'height': 52,
        'diagram_xml': '''<mxGraphModel dx="0" dy="0" grid="1" gridSize="10" guides="1" tooltips="1" connect="1" arrows="1" fold="1" page="1" pageScale="1" pageWidth="850" pageHeight="1100">
  <root>
    <mxCell id="0"/>
    <mxCell id="1" parent="0"/>
    <mxCell id="2" value="Box A" style="rounded=0;whiteSpace=wrap;html=1;" parent="1" vertex="1">
      <mxGeometry width="80" height="50" as="geometry"/>
    </mxCell>
    <mxCell id="3" value="Box B" style="rounded=0;whiteSpace=wrap;html=1;" parent="1" vertex="1">
      <mxGeometry x="180" width="80" height="50" as="geometry"/>
    </mxCell>
    <mxCell id="4" style="edgeStyle=orthogonalEdgeStyle;rounded=0;orthogonalLoop=1;jettySize=auto;html=1;" parent="1" source="2" target="3" edge="1">
      <mxGeometry relative="1" as="geometry"/>
    </mxCell>
  </root>
</mxGraphModel>''',
        'svg_body': '''    <rect x="0" y="0" width="80" height="50" fill="#ffffff" stroke="#000000"/>
    <rect x="180" y="0" width="80" height="50" fill="#ffffff" stroke="#000000"/>
    <path d="M 80 25 L 180 25" fill="none" stroke="#000000" stroke-miterlimit="10" pointer-events="stroke"/>'''
    },

    'special-chars.drawio.svg': {
        'name': 'Special Characters',
        'id': 'special-chars',
        'width': 122,
        'height': 52,
        'diagram_xml': '''<mxGraphModel dx="0" dy="0" grid="1" gridSize="10" guides="1" tooltips="1" connect="1" arrows="1" fold="1" page="1" pageScale="1" pageWidth="850" pageHeight="1100">
  <root>
    <mxCell id="0"/>
    <mxCell id="1" parent="0"/>
    <mxCell id="2" value="&lt;test&gt; &amp; &quot;quotes&quot; ñ 日本語" style="rounded=0;whiteSpace=wrap;html=1;" parent="1" vertex="1">
      <mxGeometry width="120" height="50" as="geometry"/>
    </mxCell>
  </root>
</mxGraphModel>''',
        'svg_body': '''    <rect x="0" y="0" width="120" height="50" fill="#ffffff" stroke="#000000"/>
    <g><text x="60" y="30" text-anchor="middle" font-family="Helvetica" font-size="12px">&lt;test&gt; &amp; "quotes" ñ 日本語</text></g>'''
    },

    'empty-diagram.drawio.svg': {
        'name': 'Empty',
        'id': 'empty',
        'width': 10,
        'height': 10,
        'diagram_xml': '''<mxGraphModel dx="0" dy="0" grid="1" gridSize="10" guides="1" tooltips="1" connect="1" arrows="1" fold="1" page="1" pageScale="1" pageWidth="850" pageHeight="1100">
  <root>
    <mxCell id="0"/>
    <mxCell id="1" parent="0"/>
  </root>
</mxGraphModel>''',
        'svg_body': '    <!-- Empty diagram -->'
    },

    'nested/deep/nested-box.drawio.svg': {
        'name': 'Nested Box',
        'id': 'nested',
        'width': 102,
        'height': 52,
        'diagram_xml': '''<mxGraphModel dx="0" dy="0" grid="1" gridSize="10" guides="1" tooltips="1" connect="1" arrows="1" fold="1" page="1" pageScale="1" pageWidth="850" pageHeight="1100">
  <root>
    <mxCell id="0"/>
    <mxCell id="1" parent="0"/>
    <mxCell id="2" value="Nested" style="rounded=0;whiteSpace=wrap;html=1;" parent="1" vertex="1">
      <mxGeometry width="100" height="50" as="geometry"/>
    </mxCell>
  </root>
</mxGraphModel>''',
        'svg_body': '''    <rect x="0" y="0" width="100" height="50" fill="#ffffff" stroke="#000000"/>
    <g><text x="50" y="30" text-anchor="middle" font-family="Helvetica" font-size="12px">Nested</text></g>'''
    },
}

def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    fixtures_dir = os.path.join(script_dir, '..', 'tests', 'fixtures')

    for filename, config in fixtures.items():
        filepath = os.path.join(fixtures_dir, filename)
        os.makedirs(os.path.dirname(filepath), exist_ok=True)

        svg = create_drawio_svg(
            config['diagram_xml'],
            config['name'],
            config['id'],
            config['width'],
            config['height'],
            config['svg_body']
        )

        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(svg)

        print(f"Regenerated: {filename}")

    print("\nDone! All fixtures regenerated with valid compression.")

if __name__ == '__main__':
    main()
