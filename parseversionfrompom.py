#!/usr/bin/env python

from xml.etree import ElementTree as et
import re

pom = et.parse('pom.xml')
# I could just say pom.findtext('{http://maven.apache.org/POM/4.0.0}version')
# instead, but that would break if we upgraded POM versions.
version_tag = re.compile('{http://maven.apache.org/POM/.*}version')
for element in pom.getroot():
    if version_tag.match(element.tag):
        print element.text
        break

