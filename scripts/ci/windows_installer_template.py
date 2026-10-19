"""Render the English production installer for CI fixtures."""
import re


def render(template, values, create_desktop_icon=False):
    def english_loop(match):
        return re.sub(
            r"{% if locale == '([^']+)' %}(.*?){% endif %}",
            lambda condition: condition[2] if condition[1] == 'en' else '',
            match[1], flags=re.DOTALL,
        )

    template = re.sub(r'{% for locale in LOCALES %}(.*?){% endfor %}',
                      english_loop, template, flags=re.DOTALL)
    template = template.replace(
        '{% if CREATE_DESKTOP_ICON != true %}unchecked{% else %}checkedonce{% endif %}',
        'checkedonce' if create_desktop_icon else 'unchecked',
    )
    template = re.sub(r'{{(\w+)}}', lambda match: values[match[1]], template)
    if '{{' in template or '{%' in template:
        raise ValueError('Unrendered installer template syntax')
    return template
