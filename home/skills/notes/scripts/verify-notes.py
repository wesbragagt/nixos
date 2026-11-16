#!/usr/bin/env python3
"""Read-only conformance checks for explicitly supplied vault notes; needs PyYAML."""
import os
from pathlib import Path
import re
import sys
import yaml

class UniqueLoader(yaml.SafeLoader):
    pass

def mapping(loader, node):
    result = {}
    for key_node, value_node in node.value:
        key = loader.construct_object(key_node)
        if key in result:
            raise ValueError(f"duplicate YAML property: {key}")
        result[key] = loader.construct_object(value_node)
    return result

UniqueLoader.add_constructor(yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, mapping)
if not os.environ.get('W_NOTES') or len(sys.argv) < 2:
    sys.exit('Usage: W_NOTES=/vault python3 verify-notes.py note.md [note.md ...]')
root = Path(os.environ['W_NOTES']).resolve(strict=True)
failed = False
for arg in sys.argv[1:]:
    try:
        path = Path(arg)
        path = (path if path.is_absolute() else root / path).resolve(strict=True)
        rel = path.relative_to(root)
        assert rel.parts[0] in {'00-inbox', 'projects', 'areas', 'resources', 'archives'}, 'note must be in a PARA folder'
        assert path.name == 'CONTEXT.md' or re.fullmatch(r'[a-z0-9]+(?:-[a-z0-9]+)*\.md', path.name), 'expected kebab-case.md or CONTEXT.md'
        lines = path.read_text().splitlines()
        assert lines and lines[0] == '---', 'missing frontmatter'
        if '---' not in lines[1:]:
            raise ValueError('missing closing frontmatter delimiter')
        end = lines.index('---', 1)
        data = yaml.load('\n'.join(lines[1:end]), Loader=UniqueLoader)
        assert isinstance(data, dict), 'frontmatter must be a mapping'
        tags = data.get('tags')
        assert isinstance(tags, list) and tags, 'tags must be a nonempty list'
        assert all(isinstance(t, str) and re.fullmatch(r'[a-z0-9]+(?:-[a-z0-9]+)*', t) for t in tags), 'tags must be plain lowercase kebab-case strings'
        assert len(tags) == len(set(tags)), 'duplicate tags'
        assert re.search(r'^tags:\s*\n(?:[ \t]+- |\- )', '\n'.join(lines[1:end])), 'use one tag per block-list item'
        print(f'PASS {rel}')
    except (AssertionError, ValueError, OSError, TypeError, yaml.YAMLError) as error:
        failed = True
        print(f'FAIL {arg}: {error}', file=sys.stderr)
sys.exit(1 if failed else 0)
