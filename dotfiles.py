import csv
from dataclasses import dataclass
import os
from os.path import expanduser, abspath, isfile, islink, isdir, dirname
import argparse
import itertools
from rich import print
from rich.table import Table
from rich.console import Console
from rich import box

CONFIG = "./configurations.csv"

@dataclass
class config:
  name: str = ""
  source: str = ""
  destination: str = ""
  source2: str = ""
  destination2: str = ""

def full_path(path):
  return abspath(expanduser(path))

def config_init():
  config_list = []
  with open(CONFIG) as csvfile:
    reader = csv.reader(csvfile)
    i = 0
    for row in reader:
      config_list.append(config())
      config_list[i].name = row[0]
      config_list[i].source = row[1]
      config_list[i].destination = row[2]
      config_list[i].source2 = row[3]
      config_list[i].destination2 = row[4]
      i = i + 1
  return sorted(config_list, key=lambda x: x.name)

def write_config(config_list):
  with open(CONFIG, 'w') as csvfile:
    for x in config_list:
      csvfile.write(f"{x.name},{x.source},{x.destination},{x.source2},{x.destination2}\n")

def add_config(name, source, destination, source2, destination2):
  with open(CONFIG, 'a') as csvfile:
    csvfile.write(f"{name},{source},{destination},{source2},{destination2}\n")

def list_installed(config_list):
  installed = []
  for config in config_list:
    if islink(full_path(config.destination)):
      installed.append(config)
  return installed

def list_not_installed(config_list):
  not_installed = []
  for config in config_list:
    if not islink(full_path(config.destination)):
      not_installed.append(config)
  return not_installed

def install_config(name):
  for y in name:
    for x in not_installed:
      if y == x.name:
        directory = dirname(full_path(x.destination))
        sub_directory = dirname(dirname(full_path(x.destination)))
        if not isdir(sub_directory):
          os.mkdir(sub_directory)
        if not isdir(directory):
          os.mkdir(directory)
        if isfile(full_path(x.destination)):
          print(f"File found at {x.destination}, removing...")
          os.remove(full_path(x.destination))
        print(f"Symbolic linking {x.source} -> {x.destination}")
        os.symlink(full_path(x.source), full_path(x.destination))
        if not x.destination2 == "":
          directory = dirname(full_path(x.destination2))
          sub_directory = dirname(dirname(full_path(x.destination2)))
          if not isdir(sub_directory):
            os.mkdir(sub_directory)
          if not isdir(directory):
            os.mkdir(directory)
          if isfile(full_path(x.destination2)):
            print(f"File found at {x.destination}, removing...")
            os.remove(full_path(x.destination2))
          print(f"Symbolic linking {x.source2} -> {x.destination2}")
          os.symlink(full_path(x.source2), full_path(x.destination2))

def remove_duplicate(x):
  final_list = []
  for y in x:
    if x not in final_list:
      final_list.append(x)
  return final_list

def remove_config(name):
  for y in name:
    for x in installed:
      if y == x.name:
        print(f"Removing {x.destination}")
        os.remove(full_path(x.destination))
        if not x.destination2 == "":
          print(f"Removing {x.destination2}")
          os.remove(full_path(x.destination2))

def delete_config(name):
  for y in name:
    for x in full_config_list:
      if y == x.name:
        full_config_list.remove(x)
  write_config(full_config_list)

full_config_list = config_init()
write_config(full_config_list)
installed = list_installed(full_config_list)
not_installed = list_not_installed(full_config_list)

parser = argparse.ArgumentParser("dotfiles_installer")
manage = parser.add_argument_group()
manage.add_argument("-i", "--install", help="Install configs", nargs="+")
manage.add_argument("-r", "--remove", help="Remove configs", nargs="+")
parser.add_argument("-l", "--list", help="List configs", action="store_true")
modify = parser.add_argument_group()
modify.add_argument("-d", "--delete", help="Delete configs", nargs="+")
mutual = modify.add_mutually_exclusive_group()
mutual.add_argument("-a", "--add", help="Add new configs (3 vars)", nargs=3, metavar=("NAME", "SOURCE", "DESTINATION"))
mutual.add_argument("-ae", "--add-extra", help="Add new configs (5 vars)", nargs=5, metavar=("NAME", "SOURCE", "DESTINATION", "SOURCE2", "DESTINATION2"))
args = parser.parse_args()

if args.install:
  install_config(args.install)
elif args.remove:
  remove_config(args.remove)
elif args.list:
    list_installed = []
    list_not_installed = []
    for x in installed:
        list_installed.append(x.name)
    for x in not_installed:
        list_not_installed.append(x.name)
    console = Console()
    table = Table(show_header=True)
    table.row_styles = ["none", "dim"]
    table.box = box.SIMPLE
    table.add_column("[bold green]Installed")
    table.add_column("[bold red]Not Installed")
    for x, y in itertools.zip_longest(list_installed, list_not_installed):
      table.add_row(x, y)
    console.print(table)
elif args.add:
  name, source, destination = args.add
  source2 = ""
  destination2 = ""
  add_config(name, source, destination, source2, destination2)
elif args.add_extra:
  name, source, destination, source2, destination2 = args.add_extra
  add_config(name, source, destination, source2, destination2)
elif args.delete:
  delete_config(args.delete)
else:
  parser.print_help()
