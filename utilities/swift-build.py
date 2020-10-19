#!/usr/bin/env python
# Copyright 2019 Saleem Abdulrasool <compnerd@compnerd.org>

from msrest.authentication import BasicAuthentication
from azure.devops.connection import Connection

from tabulate import tabulate
import itertools
import argparse
import urllib
import sys
import re

import sys
if sys.version_info.major == 3:
  unicode = str
  urllib.urlretrieve = urllib.request.urlretrieve
else:
  itertools.filterfalse = itertools.ifilterfalse

base_url = 'https://dev.azure.com/compnerd'
project = 'swift-build'
creds = BasicAuthentication('', '')

connection = Connection(base_url = base_url, creds = creds)
builds = connection.clients.get_build_client()

definitions = ()

def get_latest_build(definition):
  return builds.get_builds(project, definitions = [definition],
                           result_filter = 'succeeded,partiallySucceeded',
                           top = True).value[0].id

def get_artifacts(build_id):
  return (
    (artifact.name, artifact.resource.download_url) for artifact in
        builds.get_artifacts(project, build_id)
  )

def print_progress(n, bs, s, artifact, quiet):
  if not quiet:
    sys.stdout.write("\r{0:s}.zip {1:d} bytes".format(artifact[0], (n * bs)))

def main():
  parser = argparse.ArgumentParser(project)
  parser.add_argument('--list-builds', action = 'store_true',
                      dest = 'list_builds',
                      help = 'print the known builds')
  parser.add_argument('--order-by', action = 'store', dest = 'order_by',
                      choices = ['id', 'name'], default = 'id')
  parser.add_argument('--build-id', action = 'append', dest = 'build_id',
                      help = 'the build identifier (may be repeated)',
                      default = [])
  parser.add_argument('--latest-id', action = 'store_true', dest = 'latest_id',
                      help = 'print the latest completed id')
  parser.add_argument('--latest-artifacts', action = 'store_true',
                      dest = 'latest_artifacts',
                      help = 'print the artifacts of the latest build')
  parser.add_argument('--download', action = 'store_true', dest = 'download',
                      help = 'download the artifacts of the latest build')
  parser.add_argument('--filter', action = 'store', dest = 'filter',
                      help = 'filter the artifacts matching')
  parser.add_argument('--quiet', action='store_true', dest='quiet',
                        help='Silence download information')

  args = parser.parse_args()

  def _get_query_order(args):
    if args.order_by == 'id':
      return None
    if args.order_by == 'name':
      return 'definitionNameAscending'
    assert False, "unexpected ORDER_BY"

  definitions = ( (definition.id, definition.name) for definition in
      builds.get_definitions(project, query_order = _get_query_order(args)).value
  )

  if args.list_builds:
    print(tabulate(definitions, headers = ['ID', 'Name']))
    return 0

  pipelines = dict((value, key) for (key, value) in definitions)
  build_ids = (
      int(build) if unicode(build).isnumeric() else pipelines[build] for
          build in args.build_id
  )

  if args.latest_id:
    print(get_latest_build(definition) for definition in build_ids)
  elif args.latest_artifacts:
    artifacts = (
        get_artifacts(get_latest_build(definition)) for definition in build_ids
    )
    if args.filter:
      artifacts = itertools.filterfalse(lambda artifact: not re.search(args.filter, artifact[0]),
                                        itertools.chain.from_iterable(artifacts))
    else:
      artifacts = itertools.chain.from_iterable(artifacts)
    artifacts = [artifact for artifact in artifacts]
    print(tabulate(artifacts, tablefmt = 'plain'))
    if args.download:
      for artifact in artifacts:
        urllib.urlretrieve(artifact[1], "{0:s}.zip".format(artifact[0]),
                           lambda n, bs, s:
                             print_progress(n, bs, s, artifact, args.quiet))
        print("")

if __name__ == '__main__':
  main()
