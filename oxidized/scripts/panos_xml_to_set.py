#!/usr/bin/env python3
import sys
import xmltodict
import json

def flatten_dict(d, parent_key='config', sep='.'):
    """Flatten nested dict into dotted path format with bracket notation for @name keys"""
    items = []
    
    for k, v in d.items():
        # Skip XML attributes like @xmlns
        if k.startswith('@') and k != '@name':
            continue
            
        # Build the new key
        if k == '@name':
            continue  # Skip, we handle this in parent
        
        new_key = f"{parent_key}.{k}" if parent_key else k
        
        # Handle dictionaries
        if isinstance(v, dict):
            # If dict has @name, use bracket notation
            if '@name' in v:
                new_key = f"{new_key}['{v['@name']}']"
                # Remove @name and continue flattening
                v_copy = {key: val for key, val in v.items() if key != '@name'}
                items.extend(flatten_dict(v_copy, new_key, sep=sep))
            else:
                items.extend(flatten_dict(v, new_key, sep=sep))
        # Handle lists
        elif isinstance(v, list):
            for item in v:
                if isinstance(item, dict) and '@name' in item:
                    item_key = f"{new_key}['{item['@name']}']"
                    item_copy = {key: val for key, val in item.items() if key != '@name'}
                    items.extend(flatten_dict(item_copy, item_key, sep=sep))
                elif isinstance(item, dict):
                    items.extend(flatten_dict(item, new_key, sep=sep))
                else:
                    items.append((new_key, item))
        # Handle leaf values
        else:
            items.append((new_key, v))
    
    return items

def xml_to_python_dict(xml_file):
    """Convert PanOS XML config to Python dictionary format"""
    try:
        with open(xml_file, 'r') as f:
            xml_content = f.read()
        
        # Parse XML to dict
        doc = xmltodict.parse(xml_content)
        
        # Flatten the dictionary
        flat_items = flatten_dict(doc)
        
        # Format output
        output_lines = []
        for key, value in sorted(flat_items):
            # Format value
            if isinstance(value, str):
                escaped_value = value.replace('"', '\\"')
                formatted_value = f'"{escaped_value}"'
            elif value is None:
                formatted_value = 'null'
            elif isinstance(value, bool):
                formatted_value = str(value).lower()
            else:
                formatted_value = str(value)
            
            output_lines.append(f'"{key}": {formatted_value},')
        
        return '\n'.join(output_lines)
        
    except Exception as e:
        return f"# Error: {str(e)}\n# Type: {type(e).__name__}"

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: panos_xml_to_set.py <xml_file>", file=sys.stderr)
        sys.exit(1)
    
    print(xml_to_python_dict(sys.argv[1]))