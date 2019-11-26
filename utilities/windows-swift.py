#!/usr/bin/env python
# Copyright 2019 Saleem Abdulrasool <compnerd@compnerd.org>

from msrest.authentication import BasicAuthentication
from azure.devops.connection import Connection

from tabulate import tabulate
import argparse
import urllib
import sys
import re

import sys
if sys.version_info.major == 3:
  unicode = str

base_url = 'https://dev.azure.com/compnerd'
project = 'windows-swift'
creds = BasicAuthentication('', '')

connection = Connection(base_url = base_url, creds = creds)
builds = connection.clients.get_build_client()

definitions = (
  (definition.id, definition.name) for definition in
      builds.get_definitions(project).value
)

def get_latest_build(definition):
  return builds.get_builds(project, definitions = [definition],
                           result_filter = 'succeeded,partiallySucceeded',
                           top = True).value[0].id

def get_artifacts(build_id):
  return (
    (artifact.name, artifact.resource.download_url) for artifact in
        builds.get_artifacts(project, build_id)
  )

def main():
  parser = argparse.ArgumentParser(project)
  parser.add_argument('--list-builds', action = 'store_true',
                      dest = 'list_builds',
                      help = 'print the known builds')
  parser.add_argument('--build-id', action = 'append', dest = 'build_id',
                      help = 'the build identifier (may be repeated)')
  parser.add_argument('--latest-id', action = 'store_true', dest = 'latest_id',
                      help = 'print the latest completed id')
  parser.add_argument('--latest-artifacts', action = 'store_true',
                      dest = 'latest_artifacts',
                      help = 'print the artifacts of the latest build')
  parser.add_argument('--download', action = 'store_true', dest = 'download',
                      help = 'download the artifacts of the latest build')
  parser.add_argument('--filter', action = 'store', dest = 'filter',
                      help = 'filter the artifacts matching')

  args = parser.parse_args()
  if args.list_builds:
    print(tabulate(definitions, headers = ['ID', 'Name']))
    return 0

  pipelines = dict((value, key) for (key, value) in definitions)
  for build in args.build_id:
    definition = int(build) if unicode(build).isnumeric() else pipelines[build]
    if args.latest_id:
      print(get_latest_build(definition))
    elif args.latest_artifacts:
      artifacts = get_artifacts(get_latest_build(definition))
      if args.filter:
        artifacts = filter(lambda artifact: re.search(args.filter, artifact[0]), artifacts)
      print(tabulate(artifacts, tablefmt = 'plain'))
      if args.download:
        for artifact in artifacts:
            urllib.urlretrieve(artifact[1], "{0:s}.zip".format(artifact[0]),
                               lambda n, bs, s:
                                 sys.stdout.write("\r{0:s}.zip {1:d} bytes".format(artifact[0], (n * bs))))
            print("")

if __name__ == '__main__':
  main()
